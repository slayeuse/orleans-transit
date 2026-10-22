import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Color;

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/config.dart';

/// Données GTFS statiques du réseau TAO (arrêts, lignes) + index des horaires théoriques.

class GStop {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int type;
  const GStop(this.id, this.name, this.lat, this.lon, this.type);
}

class GRoute {
  final String id;
  final String short;
  final String long;
  final int colorValue;
  final int textColorValue;
  final int type; // 0 = tram, 3 = bus
  const GRoute(this.id, this.short, this.long, this.colorValue,
      this.textColorValue, this.type);

  Color get color => Color(colorValue);
  Color get textColor => Color(textColorValue);
  bool get isTram => type == 0;
}

class StaticData {
  final Map<String, GStop> stops;
  final Map<String, GRoute> routes;
  const StaticData(this.stops, this.routes);
}

/// Découpe une ligne CSV en gérant les guillemets.
List<String> parseCsvLine(String line) {
  if (!line.contains('"')) return line.split(',');
  final out = <String>[];
  final cur = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        cur.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == ',') {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString());
  return out;
}

int _parseColor(String? hex, int fallback) {
  if (hex == null) return fallback;
  final h = hex.trim().replaceAll('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return 0xFF000000 | v;
}

List<Map<String, String>> _readCsv(String path) {
  final f = File(path);
  if (!f.existsSync()) return const [];
  final lines = const LineSplitter()
      .convert(utf8.decode(f.readAsBytesSync(), allowMalformed: true));
  if (lines.isEmpty) return const [];
  final header = parseCsvLine(lines.first.replaceFirst('﻿', ''))
      .map((e) => e.trim())
      .toList();
  final out = <Map<String, String>>[];
  for (var i = 1; i < lines.length; i++) {
    final l = lines[i];
    if (l.trim().isEmpty) continue;
    final c = parseCsvLine(l);
    final m = <String, String>{};
    for (var j = 0; j < header.length && j < c.length; j++) {
      m[header[j]] = c[j].trim();
    }
    out.add(m);
  }
  return out;
}

StaticData loadStatic(String dir) {
  final stops = <String, GStop>{};
  for (final r in _readCsv(p.join(dir, 'stops.txt'))) {
    final id = r['stop_id'];
    if (id == null || id.isEmpty) continue;
    stops[id] = GStop(
      id,
      r['stop_name'] ?? id,
      double.tryParse(r['stop_lat'] ?? '') ?? 0,
      double.tryParse(r['stop_lon'] ?? '') ?? 0,
      int.tryParse(r['location_type'] ?? '') ?? 0,
    );
  }
  final routes = <String, GRoute>{};
  for (final r in _readCsv(p.join(dir, 'routes.txt'))) {
    final id = r['route_id'];
    if (id == null || id.isEmpty) continue;
    final short = (r['route_short_name'] ?? '').isNotEmpty
        ? r['route_short_name']!
        : id.split(':').last;
    routes[id] = GRoute(
      id,
      short,
      r['route_long_name'] ?? '',
      _parseColor(r['route_color'], 0xFF8E8E93),
      _parseColor(r['route_text_color'], 0xFFFFFFFF),
      int.tryParse(r['route_type'] ?? '') ?? 3,
    );
  }
  return StaticData(stops, routes);
}

Future<StaticData> loadStaticInIsolate(String dir) =>
    Isolate.run(() => loadStatic(dir));

/// Téléchargement en flux avec progression (0..1).
Future<void> downloadFile(
    String url, String path, void Function(double) onProgress) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = Config.userAgent;
    final resp = await client.send(req).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Téléchargement GTFS : HTTP ${resp.statusCode}');
    }
    final total = resp.contentLength ?? 0;
    final sink = File(path).openWrite();
    var got = 0;
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }
}

const _wanted = {'stops.txt', 'routes.txt', 'stop_times.txt'};

Future<void> extractGtfs(String zipPath, String dir) async {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = p.basename(file.name);
      if (!_wanted.contains(name)) continue;
      final out = OutputFileStream(p.join(dir, name));
      file.writeContent(out);
      await Future<void>.sync(() => out.close());
    }
  } finally {
    await Future<void>.sync(() => input.close());
  }
}

Future<void> extractGtfsInIsolate(String zipPath, String dir) =>
    Isolate.run(() => extractGtfs(zipPath, dir));

int _secs(String hms) {
  final parts = hms.trim().split(':');
  if (parts.length < 2) return -1;
  final h = int.tryParse(parts[0]) ?? -1;
  final m = int.tryParse(parts[1]) ?? -1;
  final s = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
  if (h < 0 || m < 0) return -1;
  return h * 3600 + m * 60 + s;
}

/// Lit stop_times.txt en flux et ne garde que les courses présentes dans le temps réel.
/// Clés : "trip|s:stopId" et "trip|q:stopSequence" -> secondes depuis minuit.
Future<Map<String, int>> buildStopTimesIndex(
    String path, Set<String> tripIds) async {
  final out = <String, int>{};
  final f = File(path);
  if (!f.existsSync()) return out;
  var iTrip = -1, iArr = -1, iDep = -1, iStop = -1, iSeq = -1, maxI = 0;
  var header = true;
  final lines = f
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final raw in lines) {
    if (raw.isEmpty) continue;
    if (header) {
      final h = parseCsvLine(raw.replaceFirst('﻿', ''))
          .map((e) => e.trim())
          .toList();
      iTrip = h.indexOf('trip_id');
      iArr = h.indexOf('arrival_time');
      iDep = h.indexOf('departure_time');
      iStop = h.indexOf('stop_id');
      iSeq = h.indexOf('stop_sequence');
      if (iTrip < 0 || iStop < 0 || (iArr < 0 && iDep < 0)) return out;
      for (final i in [iTrip, iArr, iDep, iStop, iSeq]) {
        if (i > maxI) maxI = i;
      }
      header = false;
      continue;
    }
    final c = parseCsvLine(raw);
    if (c.length <= maxI) continue;
    final trip = c[iTrip].trim();
    if (!tripIds.contains(trip)) continue;
    var t = iDep >= 0 ? _secs(c[iDep]) : -1;
    if (t < 0 && iArr >= 0) t = _secs(c[iArr]);
    if (t < 0) continue;
    out.putIfAbsent('$trip|s:${c[iStop].trim()}', () => t);
    if (iSeq >= 0) out['$trip|q:${c[iSeq].trim()}'] = t;
  }
  return out;
}

Future<Map<String, int>> buildStopTimesIndexInIsolate(
        String path, Set<String> tripIds) =>
    Isolate.run(() => buildStopTimesIndex(path, tripIds));
