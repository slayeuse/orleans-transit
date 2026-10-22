import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/util.dart';

class SncfException implements Exception {
  final String message;
  SncfException(this.message);
  @override
  String toString() => message;
}

/// Client minimal de l'API SNCF (moteur Navitia), authentification Basic.
class SncfClient {
  Future<http.Response> _send(Uri uri, Map<String, String> headers) async {
    try {
      return await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw SncfException('Délai dépassé (serveur SNCF)');
    } catch (_) {
      throw SncfException('Pas de connexion internet');
    }
  }

  Future<Map<String, dynamic>> get(
      String path, Map<String, String> params) async {
    final key = Config.sncfKey;
    if (key.isEmpty) {
      throw SncfException(
          'Clé API SNCF manquante — ajoutez-la dans RÉGLAGES.');
    }
    final uri =
        Uri.parse('${Config.sncfBase}$path').replace(queryParameters: params);
    final auth = base64Encode(utf8.encode('$key:'));
    final r = await _send(uri, {
      'Authorization': 'Basic $auth',
      'User-Agent': Config.userAgent,
    });

    Map<String, dynamic> json = {};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
      if (d is Map<String, dynamic>) json = d;
    } catch (_) {}

    if (r.statusCode == 401 || r.statusCode == 403) {
      throw SncfException('Clé API SNCF refusée (${r.statusCode})');
    }
    if (r.statusCode == 429) {
      throw SncfException('Quota de l\'API SNCF atteint, réessayez plus tard');
    }
    if (r.statusCode != 200) {
      final err = mp(json['error']);
      final id = str(err['id']);
      if (id == 'no_solution' || id == 'date_out_of_bounds') return {};
      throw SncfException(str(err['message']) ?? 'Erreur SNCF ${r.statusCode}');
    }
    return json;
  }
}

// ───────────────────────────── Modèles ─────────────────────────────

class Station {
  final String id;
  final String name;
  final double? lat;
  final double? lon;
  const Station(this.id, this.name, this.lat, this.lon);
}

enum TrainState { onTime, delayed, cancelled, disrupted, theoretical }

class TrainStop {
  final String name;
  final DateTime? time;
  final DateTime? baseTime;
  final String? platform;
  const TrainStop(this.name, this.time, this.baseTime, this.platform);
}

class TerTrain {
  final String number;
  final String mode;
  final String direction;
  final DateTime baseDep;
  final DateTime dep;
  final DateTime baseArr;
  final DateTime arr;
  final TrainState state;
  final int delayMin;
  final String? platformDep;
  final String? platformArr;
  final List<String> messages;
  final List<TrainStop> stops;

  const TerTrain({
    required this.number,
    required this.mode,
    required this.direction,
    required this.baseDep,
    required this.dep,
    required this.baseArr,
    required this.arr,
    required this.state,
    required this.delayMin,
    required this.platformDep,
    required this.platformArr,
    required this.messages,
    required this.stops,
  });
}

class TerDisruption {
  final String id;
  final String status;
  final String effect;
  final String title;
  final String text;
  const TerDisruption(
      {required this.id,
      required this.status,
      required this.effect,
      required this.title,
      required this.text});
}

class TerBoard {
  final List<TerTrain> trains;
  final List<TerDisruption> disruptions;
  const TerBoard(this.trains, this.disruptions);
}

/// Trajet brut extrait d'une réponse /journeys.
class _J {
  final String number;
  final String mode;
  final String direction;
  final DateTime dep;
  final DateTime arr;
  final DateTime? baseDep;
  final DateTime? baseArr;
  final String status;
  final Set<String> disIds;
  final List<TrainStop> stops;
  _J(this.number, this.mode, this.direction, this.dep, this.arr, this.baseDep,
      this.baseArr, this.status, this.disIds, this.stops);
}

// ───────────────────────────── Dépôt TER ─────────────────────────────

class TerRepository extends ChangeNotifier {
  final _client = SncfClient();

  Station? artenay;
  Station? orleans;
  TerBoard? toOrleans;
  TerBoard? toArtenay;
  bool loading = false;
  String? error;
  DateTime? updatedAt;

  int _users = 0;
  Timer? _timer;

  /// Un écran qui affiche les TER s'abonne : rafraîchissement toutes les 60 s.
  void attach() {
    _users++;
    if (_users == 1) {
      Future.microtask(() => refresh());
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          refresh();
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

  Future<void> resetStations() async {
    await Config.prefs.remove('st_artenay');
    await Config.prefs.remove('st_orleans');
    artenay = null;
    orleans = null;
  }

  List<TerDisruption> get disruptions {
    final seen = <String>{};
    final out = <TerDisruption>[];
    for (final b in [toOrleans, toArtenay]) {
      if (b == null) continue;
      for (final d in b.disruptions) {
        if (d.status != 'active') continue;
        if (seen.add(d.id)) out.add(d);
      }
    }
    return out;
  }

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    final last = updatedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last).inSeconds < 20) {
      return;
    }
    loading = true;
    notifyListeners();
    try {
      artenay ??= await _resolve('st_artenay', 'Artenay', null);
      orleans ??= await _resolve('st_orleans', 'Orléans',
          const Station('stop_area:SNCF:87543009', 'Orléans', 47.9078, 1.9047));
      final a = artenay;
      final o = orleans;
      if (a == null || o == null) {
        throw SncfException('Gares introuvables dans l\'API SNCF');
      }
      final res = await Future.wait([
        _direction(a.id, o.id),
        _direction(o.id, a.id),
      ]);
      toOrleans = res[0];
      toArtenay = res[1];
      error = null;
      updatedAt = DateTime.now();
    } catch (e) {
      error = e is SncfException ? e.message : 'Erreur : $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<Station?> _resolve(
      String prefKey, String query, Station? fallback) async {
    final cached = Config.prefs.getString(prefKey);
    if (cached != null) {
      final p = cached.split('|');
      if (p.length >= 3 && p[0].isNotEmpty) {
        return Station(p[0], query, double.tryParse(p[1]), double.tryParse(p[2]));
      }
    }
    Station? best;
    try {
      final j = await _client.get('/places', {
        'q': query,
        'type[]': 'stop_area',
        'count': '10',
      });
      final target = norm(query);
      for (final pl in lst(j['places'])) {
        final m = mp(pl);
        if (str(m['embedded_type']) != 'stop_area') continue;
        final sa = mp(m['stop_area']);
        final id = str(sa['id']) ?? str(m['id']);
        if (id == null) continue;
        final name = cleanStation(str(sa['name']) ?? str(m['name']) ?? '');
        final c = mp(sa['coord']);
        final st = Station(id, name, double.tryParse('${c['lat']}'),
            double.tryParse('${c['lon']}'));
        if (norm(name) == target) {
          best = st;
          break;
        }
        best ??= st;
      }
    } on SncfException {
      if (fallback == null) rethrow;
    }
    best ??= fallback;
    final b = best;
    if (b != null) {
      await Config.prefs
          .setString(prefKey, '${b.id}|${b.lat ?? ''}|${b.lon ?? ''}');
    }
    return b;
  }

  Map<String, String> _params(String from, String to, String freshness) {
    final start = DateTime.now().subtract(const Duration(minutes: 3));
    return {
      'from': from,
      'to': to,
      'datetime': navitiaDate(start),
      'datetime_represents': 'departure',
      'count': '8',
      'max_nb_transfers': '0',
      'direct_path': 'none',
      'data_freshness': freshness,
    };
  }

  /// Fusionne l'horaire théorique et le temps réel pour détecter retards et suppressions.
  Future<TerBoard> _direction(String from, String to) async {
    final res = await Future.wait([
      _client.get('/journeys', _params(from, to, 'base_schedule')),
      _client.get('/journeys', _params(from, to, 'realtime')),
    ]);
    final dis = <String, TerDisruption>{};
    for (final r in res) {
      for (final d in lst(r['disruptions'])) {
        final x = _parseDisruption(d);
        if (x != null) dis[x.id] = x;
      }
    }
    final base = _extract(res[0]);
    final rt = _extract(res[1]);
    final rtBy = <String, _J>{for (final r in rt) r.number: r};
    final used = <String>{};
    final trains = <TerTrain>[];

    List<String> messagesFor(Set<String> ids) {
      final out = <String>[];
      for (final id in ids) {
        final d = dis[id];
        if (d != null && d.text.isNotEmpty && !out.contains(d.text)) {
          out.add(d.text);
        }
      }
      return out;
    }

    for (final b in base) {
      final r = rtBy[b.number];
      if (r != null) used.add(r.number);
      final ids = <String>{...b.disIds, ...?r?.disIds};
      final msgs = messagesFor(ids);
      final noService = b.status == 'NO_SERVICE' ||
          (r?.status == 'NO_SERVICE') ||
          ids.any((id) => dis[id]?.effect == 'NO_SERVICE');

      if (noService || r == null) {
        final state = noService
            ? TrainState.cancelled
            : (ids.isNotEmpty ? TrainState.disrupted : TrainState.theoretical);
        trains.add(TerTrain(
          number: b.number,
          mode: b.mode,
          direction: b.direction,
          baseDep: b.dep,
          dep: b.dep,
          baseArr: b.arr,
          arr: b.arr,
          state: state,
          delayMin: 0,
          platformDep: b.stops.isEmpty ? null : b.stops.first.platform,
          platformArr: b.stops.isEmpty ? null : b.stops.last.platform,
          messages: msgs,
          stops: b.stops,
        ));
        continue;
      }
      trains.add(_fromRealtime(r, b.dep, b.arr, msgs));
    }
    // Trains présents uniquement en temps réel (ajoutés ou décalés hors fenêtre).
    for (final r in rt) {
      if (used.contains(r.number)) continue;
      trains.add(_fromRealtime(r, r.baseDep ?? r.dep, r.baseArr ?? r.arr,
          messagesFor(r.disIds)));
    }
    trains.sort((a, b) => a.baseDep.compareTo(b.baseDep));
    final now = DateTime.now().subtract(const Duration(minutes: 1));
    final visible = trains.where((t) => t.dep.isAfter(now)).toList();
    return TerBoard(visible, dis.values.toList());
  }

  TerTrain _fromRealtime(
      _J r, DateTime fallbackBaseDep, DateTime fallbackBaseArr, List<String> msgs) {
    final baseDep = r.baseDep ?? fallbackBaseDep;
    final baseArr = r.baseArr ?? fallbackBaseArr;
    final delay = r.dep.difference(baseDep).inMinutes;
    final arrDelay = r.arr.difference(baseArr).inMinutes;
    final worst = delay > arrDelay ? delay : arrDelay;
    TrainState state;
    if (worst >= 1) {
      state = TrainState.delayed;
    } else if (msgs.isNotEmpty) {
      state = TrainState.disrupted;
    } else {
      state = TrainState.onTime;
    }
    return TerTrain(
      number: r.number,
      mode: r.mode,
      direction: r.direction,
      baseDep: baseDep,
      dep: r.dep,
      baseArr: baseArr,
      arr: r.arr,
      state: state,
      delayMin: worst < 0 ? 0 : worst,
      platformDep: r.stops.isEmpty ? null : r.stops.first.platform,
      platformArr: r.stops.isEmpty ? null : r.stops.last.platform,
      messages: msgs,
      stops: r.stops,
    );
  }

  List<_J> _extract(Map<String, dynamic> json) {
    final out = <_J>[];
    for (final j in lst(json['journeys'])) {
      final jm = mp(j);
      Map<dynamic, dynamic>? pt;
      for (final s in lst(jm['sections'])) {
        final sm = mp(s);
        if (str(sm['type']) == 'public_transport') {
          pt = sm;
          break;
        }
      }
      final section = pt;
      if (section == null) continue;
      final di = mp(section['display_informations']);
      final dep = parseNavitia(section['departure_date_time']);
      final arr = parseNavitia(section['arrival_date_time']);
      if (dep == null || arr == null) continue;

      final ids = <String>{};
      for (final links in [lst(di['links']), lst(section['links']), lst(jm['links'])]) {
        for (final l in links) {
          final lm = mp(l);
          final id = str(lm['id']);
          if (str(lm['type']) == 'disruption' && id != null) ids.add(id);
        }
      }

      final stops = <TrainStop>[];
      for (final sdt in lst(section['stop_date_times'])) {
        final m = mp(sdt);
        final sp = mp(m['stop_point']);
        final time = parseNavitia(m['departure_date_time']) ??
            parseNavitia(m['arrival_date_time']);
        final baseTime = parseNavitia(m['base_departure_date_time']) ??
            parseNavitia(m['base_arrival_date_time']);
        stops.add(TrainStop(
          cleanStation(str(sp['name']) ?? ''),
          time,
          baseTime,
          str(sp['platform_code']),
        ));
      }

      out.add(_J(
        str(di['headsign']) ??
            str(di['trip_short_name']) ??
            str(di['name']) ??
            '?',
        str(di['commercial_mode']) ?? 'TER',
        cleanStation(str(di['direction']) ?? ''),
        dep,
        arr,
        parseNavitia(section['base_departure_date_time']),
        parseNavitia(section['base_arrival_date_time']),
        str(jm['status']) ?? '',
        ids,
        stops,
      ));
    }
    return out;
  }

  TerDisruption? _parseDisruption(dynamic d) {
    final m = mp(d);
    final id = str(m['id']);
    if (id == null) return null;
    final sev = mp(m['severity']);
    var text = '';
    for (final msg in lst(m['messages'])) {
      final t = str(mp(msg)['text']);
      if (t != null && t.trim().isNotEmpty) {
        text = stripHtml(t);
        break;
      }
    }
    final title = str(sev['name']) ?? '';
    if (text.isEmpty) text = title.isEmpty ? 'Perturbation' : title;
    return TerDisruption(
      id: id,
      status: str(m['status']) ?? '',
      effect: str(sev['effect']) ?? '',
      title: title,
      text: text,
    );
  }
}
