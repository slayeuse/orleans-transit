import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/sncf.dart';
import '../data/tao.dart';
import '../widgets/common.dart';
import 'tao_screen.dart';

/// Accueil : horloge, bascule TER / TAO, favoris.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    App.ter.attach();
    App.tao.attach();
  }

  @override
  void dispose() {
    App.ter.detach();
    App.tao.detach();
    super.dispose();
  }

  TerTrain? _next(TerBoard? b) {
    if (b == null) return null;
    final now = DateTime.now();
    for (final t in b.trains) {
      if (t.dep.isAfter(now)) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([App.ter, App.tao, App.favs]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _left()),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: _favorites()),
            ],
          ),
        );
      },
    );
  }

  Widget _left() {
    final ter = App.ter;
    final tao = App.tao;
    final a = _next(ter.toOrleans);
    final o = _next(ter.toArtenay);
    String terLine(String dir, TerTrain? t) {
      if (t == null) return '$dir  —';
      final s = switch (t.state) {
        TrainState.cancelled => 'SUPPRIMÉ',
        TrainState.delayed => '+${t.delayMin} MIN',
        TrainState.onTime => 'À L\'HEURE',
        TrainState.disrupted => 'PERTURBÉ',
        TrainState.theoretical => 'THÉORIQUE',
      };
      return '$dir  ${hhmm(t.dep)} · $s';
    }

    final terBad = ter.disruptions.isNotEmpty ||
        [a, o].any((t) =>
            t != null &&
            (t.state == TrainState.cancelled || t.state == TrainState.delayed));
    final taoReady = tao.phase == TaoPhase.ready;
    final disturbed = taoReady ? tao.disturbedLines : 0;

    return LayoutBuilder(builder: (context, c) {
      final clock = (c.maxHeight * 0.24).clamp(44.0, 104.0).toDouble();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: LiveClock(
                style: ts(clock, w: FontWeight.w900, ls: -clock * 0.05, h: 1)),
          ),
          const SizedBox(height: 4),
          Text(dateLabel(DateTime.now()),
              style: ts(14, w: FontWeight.w800, c: C.yellow, ls: 2)),
          const SizedBox(height: 12),
          Expanded(
            child: _ModeTile(
              bullet: const LineBullet('TER', color: C.ter, size: 54),
              title: 'TER',
              subtitle: 'ARTENAY ⇄ ORLÉANS',
              lines: [
                terLine('→ ORLÉANS', a),
                terLine('→ ARTENAY', o),
              ],
              alert: ter.error ?? (terBad ? 'Perturbations en cours' : null),
              onTap: () => App.nav.value = 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _ModeTile(
              bullet: const LineBullet('TAO', color: C.red, size: 54),
              title: 'BUS & TRAM',
              subtitle: 'RÉSEAU TAO · MÉTROPOLE',
              lines: [
                if (!taoReady)
                  'Préparation des données…'
                else if (disturbed == 0)
                  'Trafic normal'
                else
                  '$disturbed ligne${disturbed > 1 ? 's' : ''} perturbée${disturbed > 1 ? 's' : ''}',
                if (tao.rtFetchedAt != null)
                  'MAJ ${hhmm(tao.rtFetchedAt!)}',
              ],
              alert: disturbed > 0 ? 'Voir l\'info trafic' : null,
              onTap: () => App.nav.value = 2,
            ),
          ),
        ],
      );
    });
  }

  Widget _favorites() {
    final tao = App.tao;
    final favs = App.favs.stops.toList()..sort();
    final ready = tao.phase == TaoPhase.ready;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(children: [
              const Icon(Icons.star_rounded, color: C.yellow, size: 26),
              const SizedBox(width: 8),
              Text('FAVORIS', style: ts(20, w: FontWeight.w900, ls: 0.5)),
              const Spacer(),
              if (ready && tao.rtFetchedAt != null)
                Text('MAJ ${hhmm(tao.rtFetchedAt!)}',
                    style: ts(12, c: C.grey, w: FontWeight.w700)),
            ]),
          ),
          Container(height: 4, color: C.yellow),
          Expanded(
            child: !ready
                ? const Center(child: CircularProgressIndicator(color: C.yellow))
                : favs.isEmpty
                    ? EmptyState(
                        Icons.star_outline_rounded,
                        'Aucun favori pour le moment.\nOuvrez un arrêt dans l\'onglet TAO et touchez ★.',
                        action: YellowButton('CHOISIR UN ARRÊT',
                            onTap: () => App.nav.value = 2),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          for (final key in favs) _FavBlock(groupKey: key),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _FavBlock extends StatelessWidget {
  final String groupKey;
  const _FavBlock({required this.groupKey});

  @override
  Widget build(BuildContext context) {
    final r = App.tao;
    final g = r.groups[groupKey];
    if (g == null) return const SizedBox.shrink();
    final rows = r.boardFor(groupKey, perRow: 2).take(3).toList();
    final ids = g.ids.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => App.openStop(groupKey),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 14, 2),
            child: Row(children: [
              Expanded(
                child: Text(g.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(15, w: FontWeight.w900, ls: 0.3)),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.grey),
            ]),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text('Aucun passage annoncé',
                style: ts(12.5, c: C.grey, w: FontWeight.w600)),
          )
        else
          for (final row in rows)
            BoardRowTile(row: row, cells: 2, highlight: ids, compact: true),
        const Divider(height: 14, color: C.stroke, indent: 20, endIndent: 20),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final Widget bullet;
  final String title;
  final String subtitle;
  final List<String> lines;
  final String? alert;
  final VoidCallback onTap;
  const _ModeTile({
    required this.bullet,
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.alert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            bullet,
            const SizedBox(width: 16),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: ts(24, w: FontWeight.w900, ls: -0.5, h: 1.05)),
                    Text(subtitle,
                        style: ts(11, w: FontWeight.w800, c: C.grey, ls: 1.2)),
                    const SizedBox(height: 6),
                    for (final l in lines)
                      Text(l, style: ts(13, w: FontWeight.w700)),
                    if (alert != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(alert!,
                            style: ts(12, w: FontWeight.w800, c: C.orange)),
                      ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: C.yellow, size: 28),
          ]),
        ),
      ),
    );
  }
}
