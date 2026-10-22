import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/gtfs_static.dart';
import '../data/tao.dart';
import '../widgets/common.dart';
import 'tao_screen.dart';

/// Carte du réseau : fond sombre CARTO, tracés des lignes, filtre par ligne,
/// affichage des arrêts selon le zoom, mini-tableau au toucher d'un arrêt.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static final _orleans = LatLng(47.9029, 1.9093);
  static final _artenay = LatLng(48.0815, 1.8860);

  final _mc = MapController();
  double _zoom = 12.2;
  String? _route; // ligne filtrée
  bool _showBus = true;
  bool _showTram = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    App.tao.attach();
  }

  @override
  void dispose() {
    App.tao.detach();
    _mc.dispose();
    super.dispose();
  }

  void _zoomBy(double d) {
    if (!_ready) return;
    final c = _mc.camera;
    _mc.move(c.center, (c.zoom + d).clamp(8.0, 18.0).toDouble());
  }

  void _goTo(LatLng p, double z) {
    if (_ready) _mc.move(p, z);
  }

  void _selectRoute(String? id) {
    setState(() => _route = id);
    if (id == null || !_ready) return;
    final pts = <LatLng>[];
    for (final shape in App.tao.network?.shapes[id] ?? const <List<double>>[]) {
      for (var i = 0; i + 1 < shape.length; i += 2) {
        pts.add(LatLng(shape[i], shape[i + 1]));
      }
    }
    if (pts.isEmpty) {
      for (final g in App.tao.groupsOfRoute(id)) {
        final sg = App.tao.groups[g];
        if (sg != null && sg.lat != 0) pts.add(LatLng(sg.lat, sg.lon));
      }
    }
    if (pts.length < 2) return;
    _mc.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(260, 40, 90, 40),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ListenableBuilder(
          listenable: Listenable.merge([App.tao, App.favs]),
          builder: (context, _) {
            final r = App.tao;
            final ready = r.phase == TaoPhase.ready;
            return Stack(children: [
              Positioned.fill(child: ColoredBox(color: C.black, child: _map(r, ready))),
              Positioned(left: 12, top: 12, bottom: 12, child: _sidePanel(r, ready)),
              Positioned(right: 12, top: 12, child: _controls()),
              Positioned(
                right: 12,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withAlpha(170),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('© OpenStreetMap contributors · © CARTO',
                      style: ts(10, c: C.grey)),
                ),
              ),
              if (Config.cartoKey.isEmpty)
                Positioned(
                  left: 260,
                  bottom: 10,
                  child: Text('Clé CARTO manquante (Réglages)',
                      style: ts(11, c: C.orange, w: FontWeight.w800)),
                ),
            ]);
          },
        ),
      ),
    );
  }

  // ───────────── carte ─────────────

  Widget _map(TaoRepository r, bool ready) {
    final polylines = <Polyline>[];
    final net = r.network;
    if (ready && net != null) {
      // Bus d'abord, tram par-dessus, ligne sélectionnée tout en haut.
      final ids = net.shapes.keys.toList()
        ..sort((a, b) {
          int rank(String id) {
            if (id == _route) return 2;
            return r.routeOf(id).isTram ? 1 : 0;
          }

          return rank(a).compareTo(rank(b));
        });
      for (final id in ids) {
        final rt = r.routeOf(id);
        if (_route == null) {
          if (rt.isTram && !_showTram) continue;
          if (!rt.isTram && !_showBus) continue;
        }
        final selected = _route == id;
        final dimmed = _route != null && !selected;
        for (final shape in net.shapes[id]!) {
          final pts = <LatLng>[
            for (var i = 0; i + 1 < shape.length; i += 2)
              LatLng(shape[i], shape[i + 1]),
          ];
          if (pts.length < 2) continue;
          polylines.add(Polyline(
            points: pts,
            color: dimmed ? rt.color.withAlpha(45) : rt.color,
            strokeWidth: selected ? 7.0 : (rt.isTram ? 5.0 : 3.0),
            borderColor: dimmed ? Colors.transparent : Colors.black,
            borderStrokeWidth: dimmed ? 0.0 : 1.5,
          ));
        }
      }
    }

    final markers = <Marker>[];
    if (ready) {
      final only = _route == null ? null : r.groupsOfRoute(_route!);
      final routeColor = _route == null ? null : r.routeOf(_route!).color;
      for (final g in r.sortedGroups) {
        if (g.lat == 0 || g.lon == 0) continue;
        final fav = App.favs.has(g.key);
        final tram = r.tramGroups.contains(g.key);
        if (only != null) {
          if (!only.contains(g.key)) continue;
        } else {
          if (!fav) {
            if (tram && !_showTram) continue;
            if (!tram && !_showBus) continue;
            // Zoom faible : seulement tram ; zoom moyen : + bus ; zoom fort : tout.
            if (!tram && _zoom < 13.3) continue;
          }
        }
        final size = fav ? 22.0 : (tram || only != null ? 16.0 : 12.0);
        markers.add(Marker(
          point: LatLng(g.lat, g.lon),
          width: size + 8,
          height: size + 8,
          child: GestureDetector(
            onTap: () => _openStopSheet(g),
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: fav ? C.yellow : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: routeColor ?? Colors.black,
                      width: size > 14 ? 4.0 : 3.0),
                ),
              ),
            ),
          ),
        ));
      }
    }

    final ter = App.ter;
    final art = ter.artenay;
    final orl = ter.orleans;
    final stations = <LatLng>[
      (art != null && art.lat != null && art.lon != null)
          ? LatLng(art.lat!, art.lon!)
          : _artenay,
      (orl != null && orl.lat != null && orl.lon != null)
          ? LatLng(orl.lat!, orl.lon!)
          : LatLng(47.9078, 1.9047),
    ];
    for (final p in stations) {
      markers.add(Marker(
        point: p,
        width: 38,
        height: 38,
        child: GestureDetector(
          onTap: () => App.nav.value = 1,
          child: const LineBullet('TER', color: C.ter, size: 38),
        ),
      ));
    }

    return FlutterMap(
      mapController: _mc,
      options: MapOptions(
        initialCenter: _orleans,
        initialZoom: _zoom,
        minZoom: 8,
        maxZoom: 18,
        onMapReady: () => _ready = true,
        onPositionChanged: (camera, hasGesture) {
          final z = camera.zoom;
          // Ne reconstruit que lorsqu'on franchit un palier d'affichage.
          if ((z >= 13.3) != (_zoom >= 13.3)) {
            setState(() => _zoom = z);
          } else {
            _zoom = z;
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: Config.cartoTiles(),
          userAgentPackageName: Config.userAgent,
          maxZoom: 19,
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ───────────── panneau latéral ─────────────

  Widget _sidePanel(TaoRepository r, bool ready) {
    final routes = ready ? r.routesInService : const <GRoute>[];
    final trams = routes.where((x) => x.isTram).toList();
    final buses = routes.where((x) => !x.isTram).toList();
    final sel = _route == null ? null : r.routeOf(_route!);
    return SizedBox(
      width: 236,
      child: Panel(
        radius: 24,
        color: C.card.withAlpha(235),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PLAN DU RÉSEAU', style: ts(16, w: FontWeight.w900, ls: 0.4)),
            const SizedBox(height: 8),
            if (sel != null) ...[
              Row(children: [
                LineBullet(sel.short,
                    color: sel.color, textColor: sel.textColor, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sel.long.isEmpty ? 'Ligne ${sel.short}' : sel.long,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts(12, w: FontWeight.w700, h: 1.2),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Pill(
                        label: 'HORAIRES',
                        selected: true,
                        onTap: () {
                          r.selectRoute(sel.id);
                          App.nav.value = 2;
                        })),
                const SizedBox(width: 6),
                Expanded(
                    child: Pill(
                        label: 'TOUT',
                        selected: false,
                        onTap: () => _selectRoute(null))),
              ]),
            ] else
              Row(children: [
                Expanded(
                    child: Pill(
                        label: 'TRAM',
                        selected: _showTram,
                        onTap: () => setState(() => _showTram = !_showTram))),
                const SizedBox(width: 6),
                Expanded(
                    child: Pill(
                        label: 'BUS',
                        selected: _showBus,
                        onTap: () => setState(() => _showBus = !_showBus))),
              ]),
            const SizedBox(height: 10),
            Expanded(
              child: !ready
                  ? const Center(
                      child: CircularProgressIndicator(color: C.yellow))
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (trams.isNotEmpty) ...[
                          const SectionLabel('Tramway'),
                          const SizedBox(height: 6),
                          _bulletGrid(trams),
                          const SizedBox(height: 12),
                        ],
                        if (buses.isNotEmpty) ...[
                          const SectionLabel('Bus'),
                          const SizedBox(height: 6),
                          _bulletGrid(buses),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          _route == null
                              ? 'Touchez une ligne pour l\'isoler, un arrêt pour ses horaires. Zoomez pour voir tous les arrêts de bus.'
                              : 'Touchez un arrêt de la ligne pour ses prochains passages.',
                          style: ts(11, c: C.grey, h: 1.35),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletGrid(List<GRoute> list) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final rt in list)
          GestureDetector(
            onTap: () => _selectRoute(_route == rt.id ? null : rt.id),
            child: Opacity(
              opacity: (_route == null || _route == rt.id) ? 1.0 : 0.35,
              child: LineBullet(rt.short,
                  color: rt.color, textColor: rt.textColor, size: 34),
            ),
          ),
      ],
    );
  }

  // ───────────── boutons ─────────────

  Widget _controls() {
    Widget btn(IconData i, VoidCallback onTap, {String? label}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: C.card,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 46,
                height: 46,
                child: label == null
                    ? Icon(i, color: Colors.white)
                    : Center(
                        child: Text(label,
                            style: ts(11, w: FontWeight.w900, c: Colors.white))),
              ),
            ),
          ),
        );
    return Column(children: [
      btn(Icons.add_rounded, () => _zoomBy(1)),
      btn(Icons.remove_rounded, () => _zoomBy(-1)),
      const SizedBox(height: 6),
      btn(Icons.location_city_rounded, () => _goTo(_orleans, 12.6), label: 'ORL'),
      btn(Icons.train_rounded, () => _goTo(_artenay, 14.5), label: 'ART'),
    ]);
  }

  // ───────────── fiche arrêt ─────────────

  void _openStopSheet(StopGroup g) {
    showAppSheet(
      context,
      (ctx) => ListenableBuilder(
        listenable: Listenable.merge([App.tao, App.favs]),
        builder: (ctx, _) {
          final r = App.tao;
          final rows = r.boardFor(g.key, perRow: 2);
          final routes = r.routesAt(g.key);
          final fav = App.favs.has(g.key);
          final ids = g.ids.toSet();
          return SheetFrame(
            header: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(22, w: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      for (final rt in routes)
                        LineBullet(rt.short,
                            color: rt.color, textColor: rt.textColor, size: 24),
                    ]),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => App.favs.toggle(g.key),
                icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? C.yellow : C.grey,
                    size: 30),
              ),
              const SizedBox(width: 4),
              YellowButton('OUVRIR', onTap: () {
                Navigator.of(ctx).pop();
                App.openStop(g.key);
              }),
            ]),
            child: rows.isEmpty
                ? (r.isScheduleLoading(g.key)
                    ? const Center(
                        child: CircularProgressIndicator(color: C.yellow))
                    : const EmptyState(Icons.schedule_rounded,
                        'Aucun passage dans les 4 prochaines heures'))
                : ListView(
                    children: [
                      for (final row in rows.take(8))
                        BoardRowTile(
                            row: row, cells: 2, highlight: ids, compact: true),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
