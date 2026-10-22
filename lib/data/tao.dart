import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../core/util.dart';
import 'gtfs_rt.dart';
import 'gtfs_static.dart';

enum TaoPhase { starting, downloading, extracting, loading, ready, error }

class StopGroup {
  final String key;
  final String name;
  final List<String> ids;
  final double lat;
  final double lon;
  const StopGroup(this.key, this.name, this.ids, this.lat, this.lon);
}

class StopHit {
  final RtTrip trip;
  final RtStu stu;
  const StopHit(this.trip, this.stu);
}

class TaoDeparture {
  final RtTrip trip;
  final RtStu stu;
  final GRoute route;
  final String dest;
  final DateTime time;
  final int? delayMin;
  final bool cancelled;

  /// Horaire prévu uniquement (course non suivie en temps réel).
  final bool theoretical;
  const TaoDeparture(this.trip, this.stu, this.route, this.dest, this.time,
      this.delayMin, this.cancelled,
      {this.theoretical = false});
}

/// « Clos du Hameau - Quai C » -> « Clos du Hameau »
final _quaySuffix = RegExp(r'\s*[-–—/]\s*(quai|qu\.|q\.)\s*[A-Za-z0-9]{1,3}\s*$',
    caseSensitive: false);
final _quayOnly =
    RegExp(r'\s+(quai)\s+[A-Za-z0-9]{1,2}\s*$', caseSensitive: false);

String cleanStopName(String name) {
  var s = name.replaceFirst(_quaySuffix, '');
  s = s.replaceFirst(_quayOnly, '').trim();
  return s.isEmpty ? name.trim() : s;
}

class BoardRow {
  final GRoute route;
  final String dest;
  final List<TaoDeparture> next;
  BoardRow(this.route, this.dest, this.next);
}

enum LineHealth { ok, delays, deviation, cancellations }

class LineStatus {
  final GRoute route;
  final int trips;
  final int cancelled;
  final int deviated;
  final double? avgDelay;
  final LineHealth health;
  const LineStatus(this.route, this.trips, this.cancelled, this.deviated,
      this.avgDelay, this.health);

  String get title => switch (health) {
        LineHealth.cancellations => cancelled == 1
            ? '1 passage supprimé'
            : '$cancelled passages supprimés',
        LineHealth.deviation => 'Arrêts non desservis',
        LineHealth.delays => 'Retard moyen ${(avgDelay ?? 0).round()} min',
        LineHealth.ok => 'Trafic normal',
      };

  String get detail {
    final parts = <String>[];
    if (deviated > 0) {
      parts.add('$deviated course${deviated > 1 ? 's' : ''} en déviation partielle');
    }
    final a = avgDelay;
    if (a != null && health != LineHealth.delays) {
      parts.add('retard moyen ${a.round()} min');
    }
    parts.add('$trips course${trips > 1 ? 's' : ''} restantes');
    return parts.join(' · ');
  }
}

class LineStopRow {
  final String stopId;
  final String name;
  final String? groupKey;
  final int? next;
  final int? delay;
  final bool skipped;
  const LineStopRow(this.stopId, this.name, this.groupKey, this.next,
      this.delay, this.skipped);
}

class _Acc {
  int trips = 0;
  int cancelled = 0;
  int deviated = 0;
  int sum = 0;
  int n = 0;
}

/// Tri des lignes : tram d'abord, puis lettres, puis numéros croissants.
int compareRoutes(GRoute a, GRoute b) {
  final ta = a.isTram ? 0 : 1;
  final tb = b.isTram ? 0 : 1;
  if (ta != tb) return ta - tb;
  final na = int.tryParse(a.short);
  final nb = int.tryParse(b.short);
  if (na != null && nb != null) return na - nb;
  if (na != null) return 1;
  if (nb != null) return -1;
  return a.short.compareTo(b.short);
}

class TaoRepository extends ChangeNotifier {
  TaoPhase phase = TaoPhase.starting;
  double progress = 0;
  String? error;
  StaticData? data;
  String? _dir;

  final Map<String, StopGroup> groups = {};
  final Map<String, String> stopToGroup = {};
  List<StopGroup> sortedGroups = const [];

  RtFeed? feed;
  DateTime? rtFetchedAt;
  String? rtError;
  bool _rtBusy = false;
  String? rtErrorDetail;
  final Map<String, List<StopHit>> _byStop = {};
  final Map<String, Set<String>> _groupRoutes = {};
  final Map<String, RtTrip> _rtTrips = {};

  /// Tracés et dessertes (chargés en arrière-plan après les arrêts).
  NetworkData? network;
  final Map<String, Set<String>> _groupRoutesStatic = {};
  final Set<String> tramGroups = {};

  // Horaires théoriques par arrêt (calculés à la demande, en arrière-plan).
  final Map<String, (DateTime, List<SchedRow>)> _schedCache = {};
  final Set<String> _schedLoading = {};
  Future<void> _schedChain = Future<void>.value();

  Map<String, int>? _sched;
  Set<String> _indexedTrips = {};
  String? _indexDay;
  DateTime? _indexAt;
  bool indexing = false;

  String? selectedGroupKey;
  String? selectedRouteId;

  int _users = 0;
  Timer? _timer;
  double _lastProgressNotified = 0;

  // ───────────── cycle de vie ─────────────

  void attach() {
    _users++;
    if (_users == 1) {
      Future.microtask(() => refreshRt());
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          refreshRt();
        }
      });
    }
  }

  void detach() {
    _users--;
    if (_users <= 0) {
      _users = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  DateTime? get gtfsDate {
    final ts = Config.prefs.getInt('gtfs_ts');
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> init({bool forceDownload = false}) async {
    error = null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = p.join(docs.path, 'gtfs_tao');
      await Directory(dir).create(recursive: true);
      _dir = dir;
      final last = Config.prefs.getInt('gtfs_ts');
      final haveFiles = File(p.join(dir, 'stops.txt')).existsSync() &&
          File(p.join(dir, 'routes.txt')).existsSync() &&
          File(p.join(dir, 'trips.txt')).existsSync() &&
          File(p.join(dir, 'shapes.txt')).existsSync();
      final old = last == null ||
          DateTime.now().millisecondsSinceEpoch - last >
              7 * 24 * 3600 * 1000;
      if (forceDownload || !haveFiles || old) {
        try {
          await _download(dir);
        } catch (e) {
          if (!haveFiles) rethrow;
        }
      }
      phase = TaoPhase.loading;
      notifyListeners();
      data = await loadStaticInIsolate(dir);
      _buildGroups();
      _schedCache.clear();
      _sched = null;
      _indexDay = null;
      phase = TaoPhase.ready;
      notifyListeners();
      unawaited(_loadNetwork(dir));
      await refreshRt(force: true);
    } catch (e) {
      phase = TaoPhase.error;
      error = 'Impossible de préparer les données TAO.\n$e';
      notifyListeners();
    }
  }

  Future<void> _download(String dir) async {
    phase = TaoPhase.downloading;
    progress = 0;
    _lastProgressNotified = 0;
    notifyListeners();
    final zip = p.join(dir, 'gtfs.zip');
    await downloadFile(Config.taoGtfsUrl, zip, _onProgress);
    phase = TaoPhase.extracting;
    notifyListeners();
    await extractGtfsInIsolate(zip, dir);
    try {
      await File(zip).delete();
    } catch (_) {}
    await Config.prefs.setInt('gtfs_ts', DateTime.now().millisecondsSinceEpoch);
  }

  void _onProgress(double v) {
    progress = v;
    if (v - _lastProgressNotified > 0.02 || v >= 1) {
      _lastProgressNotified = v;
      notifyListeners();
    }
  }

  void _buildGroups() {
    final d = data;
    if (d == null) return;
    final byKey = <String, List<GStop>>{};
    for (final s in d.stops.values) {
      if (s.type > 1) continue; // entrées, nœuds… ignorés
      final k = norm(cleanStopName(s.name));
      if (k.isEmpty) continue;
      byKey.putIfAbsent(k, () => <GStop>[]).add(s);
    }
    groups.clear();
    stopToGroup.clear();
    byKey.forEach((k, list) {
      // Même nom mais arrêts éloignés (> 600 m) : groupes distincts (ex. « Mairie »).
      final clusters = <List<GStop>>[];
      for (final s in list) {
        List<GStop>? home;
        for (final c in clusters) {
          final ref = c.first;
          if (ref.lat == 0 || s.lat == 0) {
            home = c;
            break;
          }
          final dy = (s.lat - ref.lat) * 111000;
          final dx = (s.lon - ref.lon) * 74400;
          if (dx * dx + dy * dy < 600 * 600) {
            home = c;
            break;
          }
        }
        if (home == null) {
          clusters.add(<GStop>[s]);
        } else {
          home.add(s);
        }
      }
      for (var ci = 0; ci < clusters.length; ci++) {
        final c = clusters[ci];
        final key = ci == 0 ? k : '$k ${ci + 1}';
        final base = cleanStopName(c.first.name);
        final label = ci == 0 ? base : '$base (${ci + 1})';
        var lat = 0.0, lon = 0.0, n = 0;
        for (final s in c) {
          if (s.lat != 0 && s.lon != 0) {
            lat += s.lat;
            lon += s.lon;
            n++;
          }
          stopToGroup[s.id] = key;
        }
        groups[key] = StopGroup(key, label, [for (final s in c) s.id],
            n == 0 ? 0 : lat / n, n == 0 ? 0 : lon / n);
      }
    });
    final sorted = groups.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    sortedGroups = sorted;
  }

  Future<void> _loadNetwork(String dir) async {
    try {
      final n = await loadNetworkInIsolate(dir);
      network = n;
      _groupRoutesStatic.clear();
      tramGroups.clear();
      n.routeStops.forEach((rid, stops) {
        final tram = routeOf(rid).isTram;
        for (final sid in stops) {
          final g = stopToGroup[sid];
          if (g == null) continue;
          _groupRoutesStatic.putIfAbsent(g, () => <String>{}).add(rid);
          if (tram) tramGroups.add(g);
        }
      });
      notifyListeners();
    } catch (_) {}
  }

  /// Groupes d'arrêts desservis par une ligne.
  Set<String> groupsOfRoute(String routeId) {
    final out = <String>{};
    for (final sid in network?.routeStops[routeId] ?? const <String>{}) {
      final g = stopToGroup[sid];
      if (g != null) out.add(g);
    }
    if (out.isEmpty) {
      _groupRoutes.forEach((g, routes) {
        if (routes.contains(routeId)) out.add(g);
      });
    }
    return out;
  }

  // ───────────── temps réel ─────────────

  Future<void> refreshRt({bool force = false}) async {
    if (phase != TaoPhase.ready || _rtBusy) return;
    final last = rtFetchedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last).inSeconds < 15) {
      return;
    }
    _rtBusy = true;
    try {
      final r = await http.get(Uri.parse(Config.taoRtUrl), headers: {
        'User-Agent': Config.userAgent,
        'Accept': 'application/x-protobuf, application/octet-stream, */*',
      }).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      if (r.bodyBytes.isEmpty) throw Exception('réponse vide');
      final f = await decodeFeedInIsolate(r.bodyBytes);
      if (f.trips.isEmpty) throw Exception('flux sans course');
      _applyFeed(f);
      rtError = null;
      rtErrorDetail = null;
      rtFetchedAt = DateTime.now();
    } on TimeoutException {
      rtError = 'Temps réel TAO indisponible';
      rtErrorDetail = 'délai dépassé';
    } catch (e) {
      rtError = 'Temps réel TAO indisponible';
      final m = e.toString().replaceFirst('Exception: ', '');
      rtErrorDetail = m.length > 80 ? m.substring(0, 80) : m;
    }
    _rtBusy = false;
    notifyListeners();
    unawaited(_maybeIndex());
  }

  void _applyFeed(RtFeed f) {
    feed = f;
    _byStop.clear();
    _groupRoutes.clear();
    _rtTrips.clear();
    for (final t in f.trips) {
      _rtTrips[t.tripId] = t;
      for (final s in t.stus) {
        _byStop.putIfAbsent(s.stopId, () => <StopHit>[]).add(StopHit(t, s));
        final g = stopToGroup[s.stopId];
        if (g != null) {
          _groupRoutes.putIfAbsent(g, () => <String>{}).add(t.routeId);
        }
      }
    }
  }

  String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _maybeIndex() async {
    final f = feed;
    final dir = _dir;
    if (f == null || dir == null || indexing) return;
    final today = _day(DateTime.now());
    var missing = 0;
    for (final t in f.trips) {
      if (!_indexedTrips.contains(t.tripId)) missing++;
    }
    final at = _indexAt;
    final stale = _indexDay != today ||
        (missing > 30 &&
            (at == null || DateTime.now().difference(at).inMinutes > 20));
    if (_sched != null && !stale) return;
    final path = p.join(dir, 'stop_times.txt');
    final ids = {for (final t in f.trips) t.tripId};
    indexing = true;
    notifyListeners();
    try {
      final idx = await buildStopTimesIndexInIsolate(path, ids);
      _sched = idx;
      _indexedTrips = ids;
      _indexDay = today;
      _indexAt = DateTime.now();
    } catch (_) {
      _sched = <String, int>{};
      _indexDay = today;
      _indexAt = DateTime.now();
    }
    indexing = false;
    notifyListeners();
  }

  /// Retard en minutes (positif = en retard) ou null si inconnu.
  int? delayOf(RtTrip t, RtStu s) {
    final explicit = s.depDelay ?? s.arrDelay;
    if (explicit != null) return (explicit / 60).round();
    final idx = _sched;
    if (idx == null || idx.isEmpty) return null;
    final sec = idx['${t.tripId}|s:${s.stopId}'] ?? idx['${t.tripId}|q:${s.seq}'];
    if (sec == null) return null;
    final rt = s.time;
    if (rt == 0) return null;
    final now = DateTime.now();
    int? best;
    for (final off in const [0, -1, 1]) {
      final mid =
          DateTime(now.year, now.month, now.day + off).millisecondsSinceEpoch ~/
              1000;
      final diff = rt - (mid + sec);
      if (best == null || diff.abs() < best.abs()) best = diff;
    }
    final b = best;
    if (b == null) return null;
    final m = (b / 60).round();
    if (m < -20 || m > 120) return null;
    return m;
  }

  String? delayText(RtTrip t, RtStu s) {
    final d = delayOf(t, s);
    if (d == null) return null;
    if (d >= 1) return '+$d MIN';
    if (d <= -1) return '$d MIN';
    return 'À L\'HEURE';
  }

  // ───────────── requêtes pour l'interface ─────────────

  GRoute routeOf(String id) {
    final r = data?.routes[id];
    if (r != null) return r;
    final short = id.split(':').last;
    return GRoute(id, short, '', 0xFF8E8E93, 0xFFFFFFFF, 3);
  }

  String stopName(String id) {
    final n = data?.stops[id]?.name;
    return n == null ? id.split(':').last : cleanStopName(n);
  }

  int get rtTripCount => feed?.trips.length ?? 0;

  bool isScheduleLoading(String key) => _schedLoading.contains(key);

  /// Horaires théoriques d'un groupe d'arrêts (null tant qu'ils se calculent).
  List<SchedRow>? _schedule(String key) {
    final c = _schedCache[key];
    final now = DateTime.now();
    final fresh = c != null &&
        c.$1.day == now.day &&
        now.difference(c.$1).inMinutes < 20;
    if (!fresh) _loadSchedule(key);
    return c?.$2;
  }

  void _loadSchedule(String key) {
    final dir = _dir;
    final g = groups[key];
    if (dir == null || g == null || _schedLoading.contains(key)) return;
    _schedLoading.add(key);
    final ids = g.ids.toSet();
    _schedChain = _schedChain.then((_) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sod = now.difference(today).inSeconds;
      List<SchedRow> rows;
      try {
        rows = await scheduleForStopsInIsolate(
            dir, ids, today, sod - 120, sod + 4 * 3600);
      } catch (_) {
        rows = const [];
      }
      _schedCache[key] = (now, rows);
      _schedLoading.remove(key);
      notifyListeners();
    });
  }

  List<GRoute> routesAt(String groupKey) {
    final ids = <String>{
      ...?_groupRoutes[groupKey],
      ...?_groupRoutesStatic[groupKey],
    };
    if (ids.isEmpty) return const [];
    final list = [for (final id in ids) routeOf(id)]..sort(compareRoutes);
    return list;
  }

  List<GRoute> get routesInService {
    final f = feed;
    final ids = <String>{};
    if (f != null) {
      for (final t in f.trips) {
        ids.add(t.routeId);
      }
    }
    if (ids.isEmpty && data != null) ids.addAll(data!.routes.keys);
    return [for (final id in ids) routeOf(id)]..sort(compareRoutes);
  }

  void select(String? groupKey) {
    selectedGroupKey = groupKey;
    selectedRouteId = null;
    notifyListeners();
  }

  void selectRoute(String? routeId) {
    selectedRouteId = routeId;
    notifyListeners();
  }

  List<TaoDeparture> departuresFor(String key, {int limit = 80}) {
    final g = groups[key];
    if (g == null) return const [];
    final ids = g.ids.toSet();
    final now = nowSec() - 30;
    final list = <TaoDeparture>[];
    final seen = <String>{};

    bool isTerminus(RtTrip t, RtStu s) =>
        t.stus.length > 1 && identical(s, t.stus.last);

    // 1) Horaires prévus, remplacés par le temps réel quand la course est suivie.
    final sched = _schedule(key);
    if (sched != null) {
      final now0 = DateTime.now();
      final midnight =
          DateTime(now0.year, now0.month, now0.day).millisecondsSinceEpoch ~/
              1000;
      for (final row in sched) {
        final rt = _rtTrips[row.tripId];
        if (rt != null) {
          RtStu? hit;
          for (final s in rt.stus) {
            if (ids.contains(s.stopId)) {
              hit = s;
              break;
            }
          }
          if (hit == null) {
            for (final s in rt.stus) {
              if (s.seq == row.seq) {
                hit = s;
                break;
              }
            }
          }
          final h = hit;
          if (h != null) {
            seen.add(row.tripId);
            if (h.time >= now && !isTerminus(rt, h)) {
              list.add(_dep(StopHit(rt, h)));
            }
            continue;
          }
        }
        if (row.stopId == row.lastStopId) continue; // terminus
        final t = midnight + row.secs;
        if (t < now) continue;
        seen.add(row.tripId);
        final stu = RtStu(row.seq, row.stopId, null, t, null, null, 0);
        final end = RtStu(row.seq + 10000, row.lastStopId, null, null, null, null, 0);
        final trip = RtTrip(row.tripId, row.routeId, row.dir, 0, [stu, end]);
        list.add(TaoDeparture(trip, stu, routeOf(row.routeId),
            stopName(row.lastStopId), fromEpoch(t), null, false,
            theoretical: true));
      }
    }

    // 2) Passages temps réel non couverts par les horaires prévus.
    for (final id in ids) {
      for (final h in _byStop[id] ?? const <StopHit>[]) {
        if (seen.contains(h.trip.tripId)) continue;
        if (h.stu.time < now) continue;
        if (isTerminus(h.trip, h.stu)) continue;
        list.add(_dep(h));
      }
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  TaoDeparture _dep(StopHit h) {
    final dest = h.trip.stus.isEmpty ? '' : stopName(h.trip.stus.last.stopId);
    return TaoDeparture(
      h.trip,
      h.stu,
      routeOf(h.trip.routeId),
      dest,
      fromEpoch(h.stu.time),
      delayOf(h.trip, h.stu),
      h.trip.cancelled || h.stu.skipped,
    );
  }

  List<BoardRow> boardFor(String key, {int perRow = 3}) {
    final rows = <String, BoardRow>{};
    for (final d in departuresFor(key)) {
      final k = '${d.route.id}|${d.dest}';
      final row =
          rows.putIfAbsent(k, () => BoardRow(d.route, d.dest, <TaoDeparture>[]));
      if (row.next.length < perRow) row.next.add(d);
    }
    final list = rows.values.toList()
      ..sort((a, b) {
        final c = compareRoutes(a.route, b.route);
        return c != 0 ? c : a.dest.compareTo(b.dest);
      });
    return list;
  }

  /// Directions disponibles pour une ligne : (direction_id, terminus).
  List<(int, String)> directionsOf(String routeId) {
    final f = feed;
    if (f == null) return const [];
    final best = <int, RtTrip>{};
    for (final t in f.trips) {
      if (t.routeId != routeId || t.stus.isEmpty) continue;
      final cur = best[t.dir];
      if (cur == null || t.stus.length > cur.stus.length) best[t.dir] = t;
    }
    final dirs = best.keys.toList()..sort();
    return [
      for (final d in dirs) (d, stopName(best[d]!.stus.last.stopId)),
    ];
  }

  List<LineStopRow> lineStops(String routeId, int dir) {
    final f = feed;
    if (f == null) return const [];
    final trips =
        f.trips.where((t) => t.routeId == routeId && t.dir == dir).toList();
    if (trips.isEmpty) return const [];
    var pattern = trips.first;
    for (final t in trips) {
      if (t.stus.length > pattern.stus.length) pattern = t;
    }
    final now = nowSec();
    final next = <String, int>{};
    final dly = <String, int?>{};
    final skippedSoon = <String>{};
    for (final t in trips) {
      for (final s in t.stus) {
        if (s.time < now) continue;
        if (t.cancelled || s.skipped) {
          if (s.time < now + 3600) skippedSoon.add(s.stopId);
          continue;
        }
        final cur = next[s.stopId];
        if (cur == null || s.time < cur) {
          next[s.stopId] = s.time;
          dly[s.stopId] = delayOf(t, s);
        }
      }
    }
    return [
      for (final s in pattern.stus)
        LineStopRow(
          s.stopId,
          stopName(s.stopId),
          stopToGroup[s.stopId],
          next[s.stopId],
          dly[s.stopId],
          next[s.stopId] == null && skippedSoon.contains(s.stopId),
        ),
    ];
  }

  List<LineStatus> lineStatuses() {
    final f = feed;
    if (f == null) return const [];
    final now = nowSec();
    final by = <String, _Acc>{};
    for (final t in f.trips) {
      if (t.stus.isEmpty) continue;
      if (t.stus.last.time < now) continue;
      final a = by.putIfAbsent(t.routeId, () => _Acc());
      a.trips++;
      if (t.cancelled) {
        if (t.stus.first.time < now + 3 * 3600) a.cancelled++;
        continue;
      }
      if (t.partlySkipped) a.deviated++;
      for (final s in t.stus) {
        if (s.time < now - 300 || s.time > now + 1800) continue;
        final d = delayOf(t, s);
        if (d != null) {
          a.sum += d;
          a.n++;
        }
      }
    }
    final out = <LineStatus>[];
    by.forEach((routeId, a) {
      final avg = a.n == 0 ? null : a.sum / a.n;
      LineHealth h;
      if (a.cancelled > 0) {
        h = LineHealth.cancellations;
      } else if (a.deviated > 0) {
        h = LineHealth.deviation;
      } else if (avg != null && avg >= 4) {
        h = LineHealth.delays;
      } else {
        h = LineHealth.ok;
      }
      out.add(LineStatus(routeOf(routeId), a.trips, a.cancelled, a.deviated, avg, h));
    });
    out.sort((x, y) {
      final c = y.health.index.compareTo(x.health.index);
      return c != 0 ? c : compareRoutes(x.route, y.route);
    });
    return out;
  }

  LineStatus? statusOf(String routeId) {
    for (final s in lineStatuses()) {
      if (s.route.id == routeId) return s;
    }
    return null;
  }

  int get disturbedLines =>
      lineStatuses().where((s) => s.health != LineHealth.ok).length;

  List<RtAlert> get alerts => feed?.alerts ?? const [];

  String get statusLine {
    final at = rtFetchedAt;
    final parts = <String>[];
    if (rtError != null) {
      parts.add(rtErrorDetail == null ? rtError! : '$rtError ($rtErrorDetail)');
    }
    if (at != null) parts.add('MAJ ${hhmm(at)} · temps réel TAO');
    if (indexing) parts.add('calcul des retards…');
    return parts.join(' · ');
  }
}
