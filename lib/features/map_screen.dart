import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/tao.dart';
import '../widgets/common.dart';

/// Carte OpenStreetMap (fond sombre CARTO) des arrêts TAO et des gares TER.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ListenableBuilder(
          listenable: Listenable.merge([App.tao, App.favs]),
          builder: (context, _) {
            final markers = <Marker>[];
            final r = App.tao;
            if (r.phase == TaoPhase.ready) {
              for (final g in r.sortedGroups) {
                if (g.lat == 0 || g.lon == 0) continue;
                final fav = App.favs.has(g.key);
                markers.add(Marker(
                  point: LatLng(g.lat, g.lon),
                  width: fav ? 22 : 15,
                  height: fav ? 22 : 15,
                  child: GestureDetector(
                    onTap: () => App.openStop(g.key),
                    child: Container(
                      decoration: BoxDecoration(
                        color: fav ? C.yellow : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                    ),
                  ),
                ));
              }
            }
            final ter = App.ter;
            final art = ter.artenay;
            final orl = ter.orleans;
            final stations = <(String, LatLng)>[
              ('Artenay',
                  (art != null && art.lat != null && art.lon != null)
                      ? LatLng(art.lat!, art.lon!)
                      : LatLng(48.0815, 1.8860)),
              ('Orléans',
                  (orl != null && orl.lat != null && orl.lon != null)
                      ? LatLng(orl.lat!, orl.lon!)
                      : LatLng(47.9078, 1.9047)),
            ];
            for (final s in stations) {
              markers.add(Marker(
                point: s.$2,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => App.nav.value = 1,
                  child: const LineBullet('TER', color: C.ter, size: 40),
                ),
              ));
            }
            return Stack(children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(47.95, 1.90),
                  initialZoom: 11.3,
                  minZoom: 8,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: Config.userAgent,
                    maxZoom: 19,
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                left: 14,
                top: 14,
                child: Panel(
                  radius: 22,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CARTE DU RÉSEAU',
                          style: ts(16, w: FontWeight.w900, ls: 0.4)),
                      const SizedBox(height: 8),
                      _legend(Colors.white, 'Arrêt TAO (toucher pour les horaires)'),
                      const SizedBox(height: 4),
                      _legend(C.yellow, 'Arrêt favori'),
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const LineBullet('TER', color: C.ter, size: 18),
                        const SizedBox(width: 8),
                        Text('Gare TER', style: ts(11.5, c: C.grey, w: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('© OpenStreetMap contributors · © CARTO',
                      style: ts(10, c: C.grey)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 3),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: ts(11.5, c: C.grey, w: FontWeight.w600)),
        ],
      );
}
