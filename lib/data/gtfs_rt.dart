import 'dart:convert';
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
        pos += varint();
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

RtFeed decodeFeed(Uint8List bytes) {
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
