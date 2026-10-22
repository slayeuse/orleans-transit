import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';
import 'dart:typed_data';

/// Décodeur Protobuf minimal pour GTFS-Realtime (sans dépendance externe).
/// Seuls les champs utiles à l'application sont lus, les autres sont ignorés.

class _Pb {
  final Uint8List b;
  int pos;
  final int end;
  _Pb(this.b, this.pos, this.end);

  bool get more => pos < end;

  int varint() {
    var result = 0;
    var shift = 0;
    while (pos < end) {
      final byte = b[pos++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) break;
    }
    return result;
  }

  _Pb sub() {
    final len = varint();
    final start = pos;
    pos += len;
    return _Pb(b, start, start + len);
  }

  String string() {
    final len = varint();
    final start = pos;
    pos += len;
    return utf8.decode(Uint8List.sublistView(b, start, start + len),
        allowMalformed: true);
  }

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        varint();
        break;
      case 1:
        pos += 8;
        break;
      case 2:
        // Attention : lire la longueur AVANT d'avancer (pos += varint() lirait
        // l'ancienne position, avant que varint() ne la déplace).
        final len = varint();
        pos += len;
        break;
      case 5:
        pos += 4;
        break;
      default:
        pos = end; // type inconnu : on abandonne ce message
    }
  }
}

class RtStu {
  final int seq;
  final String stopId;
  final int? arrTime;
  final int? depTime;
  final int? arrDelay;
  final int? depDelay;

  /// 0 = SCHEDULED, 1 = SKIPPED, 2 = NO_DATA
  final int rel;

  const RtStu(this.seq, this.stopId, this.arrTime, this.depTime, this.arrDelay,
      this.depDelay, this.rel);

  int get time => depTime ?? arrTime ?? 0;
  bool get skipped => rel == 1;
}

class RtTrip {
  final String tripId;
  final String routeId;
  final int dir;

  /// 0 = SCHEDULED, 1 = ADDED, 2 = UNSCHEDULED, 3 = CANCELED
  final int rel;
  final List<RtStu> stus;

  const RtTrip(this.tripId, this.routeId, this.dir, this.rel, this.stus);

  bool get cancelled =>
      rel == 3 || (stus.isNotEmpty && stus.every((s) => s.skipped));
  bool get partlySkipped => !cancelled && stus.any((s) => s.skipped);
}

class RtAlert {
  final String header;
  final String description;
  final List<String> routeIds;
  final List<String> stopIds;
  final int effect;
  const RtAlert(
      this.header, this.description, this.routeIds, this.stopIds, this.effect);
}

class RtFeed {
  final int timestamp;
  final List<RtTrip> trips;
  final List<RtAlert> alerts;
  const RtFeed(this.timestamp, this.trips, this.alerts);
}

Future<RtFeed> decodeFeedInIsolate(Uint8List bytes) =>
    Isolate.run(() => decodeFeed(bytes));

/// Point d'entrée tolérant : protobuf, protobuf compressé (gzip) ou JSON.
RtFeed decodeFeed(Uint8List input) {
  var bytes = input;
  // gzip non signalé par le serveur
  if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    bytes = Uint8List.fromList(gzip.decode(bytes));
  }
  // Saute d'éventuels espaces / BOM pour détecter du JSON
  var i = 0;
  while (i < bytes.length && i < 8 &&
      (bytes[i] == 0x20 || bytes[i] == 0x0a || bytes[i] == 0x0d ||
          bytes[i] == 0x09 || bytes[i] == 0xef || bytes[i] == 0xbb ||
          bytes[i] == 0xbf)) {
    i++;
  }
  if (i < bytes.length && (bytes[i] == 0x7b || bytes[i] == 0x5b)) {
    return decodeJsonFeed(utf8.decode(bytes, allowMalformed: true));
  }
  return _decodeProto(bytes);
}

RtFeed _decodeProto(Uint8List bytes) {
  final r = _Pb(bytes, 0, bytes.length);
  var ts = 0;
  final trips = <RtTrip>[];
  final alerts = <RtAlert>[];
  while (r.more) {
    final key = r.varint();
    final field = key >> 3;
    final wt = key & 7;
    if (field == 1 && wt == 2) {
      ts = _header(r.sub());
    } else if (field == 2 && wt == 2) {
      _entity(r.sub(), trips, alerts);
    } else {
      r.skip(wt);
    }
  }
  return RtFeed(ts, trips, alerts);
}

int _header(_Pb r) {
  var ts = 0;
  while (r.more) {
    final key = r.varint();
    if ((key >> 3) == 3 && (key & 7) == 0) {
      ts = r.varint();
    } else {
      r.skip(key & 7);
    }
  }
  return ts;
}

void _entity(_Pb r, List<RtTrip> trips, List<RtAlert> alerts) {
  var deleted = false;
  RtTrip? trip;
  RtAlert? alert;
  while (r.more) {
    final key = r.varint();
    final field = key >> 3;
    final wt = key & 7;
    if (field == 2 && wt == 0) {
      deleted = r.varint() != 0;
    } else if (field == 3 && wt == 2) {
      trip = _tripUpdate(r.sub());
    } else if (field == 5 && wt == 2) {
      alert = _alert(r.sub());
    } else {
      r.skip(wt);
    }
  }
  if (deleted) return;
  final t = trip;
  if (t != null && t.tripId.isNotEmpty) trips.add(t);
  final a = alert;
  if (a != null) alerts.add(a);
}

RtTrip _tripUpdate(_Pb r) {
  var tripId = '';
  var routeId = '';
  var dir = 0;
  var rel = 0;
  final stus = <RtStu>[];
  while (r.more) {
    final key = r.varint();
    final field = key >> 3;
    final wt = key & 7;
    if (field == 1 && wt == 2) {
      final d = r.sub();
      while (d.more) {
        final k = d.varint();
        final f = k >> 3;
        final w = k & 7;
        if (f == 1 && w == 2) {
          tripId = d.string();
        } else if (f == 4 && w == 0) {
          rel = d.varint();
        } else if (f == 5 && w == 2) {
          routeId = d.string();
        } else if (f == 6 && w == 0) {
          dir = d.varint();
        } else {
          d.skip(w);
        }
      }
    } else if (field == 2 && wt == 2) {
      stus.add(_stu(r.sub()));
    } else {
      r.skip(wt);
    }
  }
  stus.sort((a, b) => a.seq.compareTo(b.seq));
  return RtTrip(tripId, routeId, dir, rel, stus);
}

RtStu _stu(_Pb r) {
  var seq = 0;
  var stopId = '';
  int? arrT, depT, arrD, depD;
  var rel = 0;
  while (r.more) {
    final key = r.varint();
    final field = key >> 3;
    final wt = key & 7;
    if (field == 1 && wt == 0) {
      seq = r.varint();
    } else if ((field == 2 || field == 3) && wt == 2) {
      final e = r.sub();
      int? delay;
      int? time;
      while (e.more) {
        final k = e.varint();
        final f = k >> 3;
        final w = k & 7;
        if (f == 1 && w == 0) {
          delay = e.varint().toSigned(32);
        } else if (f == 2 && w == 0) {
          time = e.varint();
        } else {
          e.skip(w);
        }
      }
      if (field == 2) {
        arrT = time;
        arrD = delay;
      } else {
        depT = time;
        depD = delay;
      }
    } else if (field == 4 && wt == 2) {
      stopId = r.string();
    } else if (field == 5 && wt == 0) {
      rel = r.varint();
    } else {
      r.skip(wt);
    }
  }
  return RtStu(seq, stopId, arrT, depT, arrD, depD, rel);
}

String _translated(_Pb r) {
  var text = '';
  while (r.more) {
    final key = r.varint();
    if ((key >> 3) == 1 && (key & 7) == 2) {
      final t = r.sub();
      var candidate = '';
      var lang = '';
      while (t.more) {
        final k = t.varint();
        if ((k >> 3) == 1 && (k & 7) == 2) {
          candidate = t.string();
        } else if ((k >> 3) == 2 && (k & 7) == 2) {
          lang = t.string();
        } else {
          t.skip(k & 7);
        }
      }
      if (text.isEmpty || lang.toLowerCase().startsWith('fr')) text = candidate;
    } else {
      r.skip(key & 7);
    }
  }
  return text;
}

RtAlert _alert(_Pb r) {
  var header = '';
  var desc = '';
  var effect = 0;
  final routes = <String>[];
  final stops = <String>[];
  while (r.more) {
    final key = r.varint();
    final field = key >> 3;
    final wt = key & 7;
    if (field == 5 && wt == 2) {
      final s = r.sub();
      while (s.more) {
        final k = s.varint();
        final f = k >> 3;
        final w = k & 7;
        if (f == 2 && w == 2) {
          routes.add(s.string());
        } else if (f == 5 && w == 2) {
          stops.add(s.string());
        } else {
          s.skip(w);
        }
      }
    } else if (field == 7 && wt == 0) {
      effect = r.varint();
    } else if (field == 10 && wt == 2) {
      header = _translated(r.sub());
    } else if (field == 11 && wt == 2) {
      desc = _translated(r.sub());
    } else {
      r.skip(wt);
    }
  }
  return RtAlert(header, desc, routes, stops, effect);
}


// ───────────── Variante JSON (GTFS-RT encodé en JSON, camelCase ou snake_case) ─────────────

dynamic _k(Map m, String camel, String snake) => m[camel] ?? m[snake];

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

int _rel(dynamic v, Map<String, int> names) {
  if (v is int) return v;
  if (v is String) return names[v.toUpperCase()] ?? int.tryParse(v) ?? 0;
  return 0;
}

const _tripRel = {'SCHEDULED': 0, 'ADDED': 1, 'UNSCHEDULED': 2, 'CANCELED': 3, 'CANCELLED': 3};
const _stuRel = {'SCHEDULED': 0, 'SKIPPED': 1, 'NO_DATA': 2};

RtFeed decodeJsonFeed(String text) {
  final root = jsonDecode(text);
  final m = root is Map ? root : <String, dynamic>{};
  final header = m['header'] is Map ? m['header'] as Map : const {};
  final ts = _int(header['timestamp']) ?? 0;
  final trips = <RtTrip>[];
  final ents = m['entity'] ?? m['entities'];
  if (ents is List) {
    for (final e in ents) {
      if (e is! Map) continue;
      if ((_k(e, 'isDeleted', 'is_deleted')) == true) continue;
      final tu = _k(e, 'tripUpdate', 'trip_update');
      if (tu is! Map) continue;
      final td = tu['trip'] is Map ? tu['trip'] as Map : const {};
      final tripId = (_k(td, 'tripId', 'trip_id') ?? '').toString();
      if (tripId.isEmpty) continue;
      final stus = <RtStu>[];
      final list = _k(tu, 'stopTimeUpdate', 'stop_time_update');
      if (list is List) {
        for (final s in list) {
          if (s is! Map) continue;
          final arr = s['arrival'] is Map ? s['arrival'] as Map : const {};
          final dep = s['departure'] is Map ? s['departure'] as Map : const {};
          stus.add(RtStu(
            _int(_k(s, 'stopSequence', 'stop_sequence')) ?? 0,
            (_k(s, 'stopId', 'stop_id') ?? '').toString(),
            _int(arr['time']),
            _int(dep['time']),
            _int(arr['delay']),
            _int(dep['delay']),
            _rel(_k(s, 'scheduleRelationship', 'schedule_relationship'), _stuRel),
          ));
        }
      }
      stus.sort((a, b) => a.seq.compareTo(b.seq));
      trips.add(RtTrip(
        tripId,
        (_k(td, 'routeId', 'route_id') ?? '').toString(),
        _int(_k(td, 'directionId', 'direction_id')) ?? 0,
        _rel(_k(td, 'scheduleRelationship', 'schedule_relationship'), _tripRel),
        stus,
      ));
    }
  }
  return RtFeed(ts, trips, const []);
}
