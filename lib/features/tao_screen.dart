import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/gtfs_static.dart';
import '../data/tao.dart';
import '../widgets/common.dart';
import '../widgets/timeline.dart';

Color healthColor(LineHealth h) => switch (h) {
      LineHealth.ok => C.green,
      LineHealth.delays => C.orange,
      LineHealth.deviation => C.orange,
      LineHealth.cancellations => C.red,
    };

/// Couleur d'un horaire TAO : rouge = supprimé/retard, vert = à l'heure.
Color depColor(TaoDeparture d) {
  if (d.cancelled) return C.red;
  final dl = d.delayMin;
  if (dl == null) return Colors.white;
  if (dl >= 2) return C.red;
  return C.green;
}

class TaoScreen extends StatefulWidget {
  const TaoScreen({super.key});
  @override
  State<TaoScreen> createState() => _TaoScreenState();
}

class _TaoScreenState extends State<TaoScreen> {
  int tab = 0;
  final _q = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    App.tao.attach();
  }

  @override
  void dispose() {
    App.tao.detach();
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([App.tao, App.favs]),
      builder: (context, _) {
        final r = App.tao;
        if (r.phase != TaoPhase.ready) return TaoLoading(repo: r);
        final Widget right;
        final routeId = r.selectedRouteId;
        final groupKey = r.selectedGroupKey;
        if (routeId != null) {
          right = LinePanel(key: ValueKey(routeId), routeId: routeId);
        } else if (groupKey != null) {
          right = StopBoard(groupKey: groupKey);
        } else {
          right = const Panel(
            child: EmptyState(Icons.touch_app_rounded,
                'Choisissez un arrêt ou une ligne\ndans la liste de gauche.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 296,
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: SegmentedPills(
                        labels: const ['ARRÊTS', 'LIGNES', 'TRAFIC'],
                        index: tab,
                        onChanged: (i) => setState(() => tab = i),
                      ),
                    ),
                    Expanded(
                      child: switch (tab) {
                        0 => _stopsList(r),
                        1 => _linesList(r),
                        _ => _trafficList(r),
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }

  Widget _stopsList(TaoRepository r) {
    final q = norm(query);
    final all = r.sortedGroups;
    final favs = all.where((g) => App.favs.has(g.key)).toList();
    final list = q.isEmpty ? all : all.where((g) => g.key.contains(q)).toList();
    final entries = <Object>[];
    if (q.isEmpty && favs.isNotEmpty) {
      entries.add('FAVORIS');
      entries.addAll(favs);
      entries.add('TOUS LES ARRÊTS');
    }
    entries.addAll(list);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _q,
          onChanged: (v) => setState(() => query = v),
          style: ts(15, w: FontWeight.w600),
          decoration: inputDeco('Rechercher un arrêt', Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: entries.isEmpty
            ? const EmptyState(Icons.search_off_rounded, 'Aucun arrêt trouvé')
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  if (e is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: SectionLabel(e,
                          color: e == 'FAVORIS' ? C.yellow : C.grey),
                    );
                  }
                  final g = e as StopGroup;
                  return _StopTile(
                    group: g,
                    selected: r.selectedGroupKey == g.key &&
                        r.selectedRouteId == null,
                    fav: App.favs.has(g.key),
                    routes: r.routesAt(g.key),
                    onTap: () => r.select(g.key),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _linesList(TaoRepository r) {
    final routes = r.routesInService;
    final statuses = {for (final s in r.lineStatuses()) s.route.id: s};
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: routes.length,
      itemBuilder: (context, i) {
        final rt = routes[i];
        final st = statuses[rt.id];
        final sel = r.selectedRouteId == rt.id;
        return InkWell(
          onTap: () => r.selectRoute(rt.id),
          child: Container(
            color: sel ? C.raised : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              LineBullet(rt.short,
                  color: rt.color, textColor: rt.textColor, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rt.long.isEmpty ? 'Ligne ${rt.short}' : rt.long,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ts(12.5, w: FontWeight.w700, h: 1.2),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: st == null ? C.dim : healthColor(st.health),
                  shape: BoxShape.circle,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _trafficList(TaoRepository r) {
    final statuses = r.lineStatuses();
    final alerts = r.alerts;
    final disturbed = statuses.where((s) => s.health != LineHealth.ok).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        Panel(
          color: disturbed == 0 ? C.green.withAlpha(30) : C.orange.withAlpha(30),
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Text(
            disturbed == 0
                ? 'Trafic normal sur l\'ensemble du réseau'
                : '$disturbed ligne${disturbed > 1 ? 's' : ''} perturbée${disturbed > 1 ? 's' : ''}',
            style: ts(14,
                w: FontWeight.w800, c: disturbed == 0 ? C.green : C.orange),
          ),
        ),
        for (final a in alerts) ...[
          const SizedBox(height: 8),
          Panel(
            color: C.raised,
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final id in a.routeIds.take(6))
                      LineBullet(r.routeOf(id).short,
                          color: r.routeOf(id).color,
                          textColor: r.routeOf(id).textColor,
                          size: 24),
                  ]),
                  const SizedBox(height: 6),
                  Text(a.header.isEmpty ? 'Information trafic' : a.header,
                      style: ts(13.5, w: FontWeight.w800)),
                  if (a.description.isNotEmpty)
                    Text(a.description, style: ts(12.5, c: C.grey, h: 1.3)),
                ]),
          ),
        ],
        const SizedBox(height: 6),
        for (final s in statuses)
          InkWell(
            onTap: () {
              setState(() => tab = 1);
              r.selectRoute(s.route.id);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                LineBullet(s.route.short,
                    color: s.route.color,
                    textColor: s.route.textColor,
                    size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: ts(13.5,
                              w: FontWeight.w800, c: healthColor(s.health))),
                      Text(s.detail,
                          maxLines: 2,
                          style: ts(11.5, c: C.grey, w: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'État calculé à partir du flux temps réel TAO (suppressions, arrêts non desservis, retards).',
          style: ts(11, c: C.dim, h: 1.3),
        ),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  final StopGroup group;
  final bool selected;
  final bool fav;
  final List<GRoute> routes;
  final VoidCallback onTap;
  const _StopTile(
      {required this.group,
      required this.selected,
      required this.fav,
      required this.routes,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? C.raised : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 20,
            child: fav
                ? const Icon(Icons.star_rounded, color: C.yellow, size: 18)
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: C.dim, shape: BoxShape.circle),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(14.5, w: FontWeight.w700)),
          ),
          for (final rt in routes.take(4))
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: LineBullet(rt.short,
                  color: rt.color, textColor: rt.textColor, size: 22),
            ),
          if (routes.length > 4)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('+${routes.length - 4}',
                  style: ts(11, c: C.grey, w: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}

/// Tableau des prochains passages pour un arrêt.
class StopBoard extends StatelessWidget {
  final String groupKey;
  const StopBoard({super.key, required this.groupKey});

  @override
  Widget build(BuildContext context) {
    final r = App.tao;
    final g = r.groups[groupKey];
    if (g == null) {
      return const Panel(
          child: EmptyState(Icons.location_off_rounded, 'Arrêt introuvable'));
    }
    final rows = r.boardFor(groupKey);
    final fav = App.favs.has(groupKey);
    final ids = g.ids.toSet();
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(25, w: FontWeight.w900, ls: -0.5)),
                    const SizedBox(height: 2),
                    Text(r.statusLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(12,
                            c: r.rtError != null ? C.red : C.grey,
                            w: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                onPressed: () => App.favs.toggle(groupKey),
                icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? C.yellow : C.grey, size: 32),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () => r.refreshRt(force: true),
                icon: const Icon(Icons.refresh_rounded, color: C.grey),
              ),
            ]),
          ),
          const Divider(height: 1, color: C.stroke),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(Icons.schedule_rounded,
                    'Aucun passage annoncé pour le moment')
                : LayoutBuilder(
                    builder: (context, c) {
                      final cells = c.maxWidth > 560 ? 3 : 2;
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: C.stroke, indent: 20, endIndent: 20),
                        itemBuilder: (context, i) => BoardRowTile(
                            row: rows[i], cells: cells, highlight: ids),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BoardRowTile extends StatelessWidget {
  final BoardRow row;
  final int cells;
  final Set<String> highlight;
  final bool compact;
  const BoardRowTile(
      {super.key,
      required this.row,
      required this.cells,
      required this.highlight,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final next = row.next.take(cells).toList();
    return InkWell(
      onTap: () => showTripSheet(context, row.next.first, highlight),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 18, vertical: compact ? 8 : 11),
        child: Row(children: [
          LineBullet(row.route.short,
              color: row.route.color,
              textColor: row.route.textColor,
              size: compact ? 34 : 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ${row.dest.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(compact ? 13.5 : 16, w: FontWeight.w800)),
                if (!compact && row.route.long.isNotEmpty)
                  Text(row.route.long,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11.5, c: C.grey, w: FontWeight.w600)),
              ],
            ),
          ),
          for (var i = 0; i < next.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _TimeCell(next[i], first: i == 0, compact: compact),
            ),
        ]),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  final TaoDeparture d;
  final bool first;
  final bool compact;
  const _TimeCell(this.d, {required this.first, required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = depColor(d);
    final dl = d.delayMin;
    final sub = d.cancelled
        ? hhmm(d.time)
        : (dl != null && dl >= 1 ? '${hhmm(d.time)} +$dl' : hhmm(d.time));
    final w = compact ? 58.0 : (first ? 78.0 : 56.0);
    return SizedBox(
      width: w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              d.cancelled ? 'SUPPR.' : countdown(d.time),
              style: ts(first && !compact ? 21 : 15,
                  w: FontWeight.w900, c: color, ls: -0.3),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(sub,
                style: ts(10.5,
                    c: C.grey,
                    w: FontWeight.w600,
                    deco: d.cancelled ? TextDecoration.lineThrough : null)),
          ),
        ],
      ),
    );
  }
}

void showTripSheet(BuildContext context, TaoDeparture d, Set<String> highlight) {
  final r = App.tao;
  final stus = d.trip.stus;
  var focus = 0;
  final stops = <TimelineStop>[];
  for (var i = 0; i < stus.length; i++) {
    final s = stus[i];
    final hl = highlight.contains(s.stopId);
    if (hl && focus == 0) focus = i;
    final dl = r.delayOf(d.trip, s);
    stops.add(TimelineStop(
      name: r.stopName(s.stopId),
      time: hhmm(fromEpoch(s.time)),
      timeColor: dl == null ? null : (dl >= 2 ? C.red : C.green),
      note: s.skipped || d.trip.cancelled
          ? 'NON DESSERVI'
          : r.delayText(d.trip, s),
      noteColor: s.skipped || d.trip.cancelled
          ? C.red
          : (dl != null && dl >= 2 ? C.red : C.green),
      highlight: hl,
      skipped: s.skipped || d.trip.cancelled,
    ));
  }
  showAppSheet(
    context,
    (ctx) => SheetFrame(
      header: Row(children: [
        LineBullet(d.route.short,
            color: d.route.color, textColor: d.route.textColor, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('→ ${d.dest.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(21, w: FontWeight.w900)),
              Text(
                  d.route.long.isEmpty ? 'Ligne ${d.route.short}' : d.route.long,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(12.5, c: C.grey, w: FontWeight.w700)),
            ],
          ),
        ),
        if (d.trip.cancelled)
          const StatusChip('SUPPRIMÉ', color: C.red, filled: true)
        else if (d.trip.partlySkipped)
          const StatusChip('DÉVIATION', color: C.orange),
      ]),
      child: Timeline(stops: stops, color: d.route.color, scrollTo: focus),
    ),
  );
}

/// Détail d'une ligne : arrêts reliés + prochain passage à chaque arrêt.
class LinePanel extends StatefulWidget {
  final String routeId;
  const LinePanel({super.key, required this.routeId});
  @override
  State<LinePanel> createState() => _LinePanelState();
}

class _LinePanelState extends State<LinePanel> {
  int? dir;

  @override
  Widget build(BuildContext context) {
    final r = App.tao;
    final route = r.routeOf(widget.routeId);
    final dirs = r.directionsOf(widget.routeId);
    var d = dir ?? (dirs.isNotEmpty ? dirs.first.$1 : 0);
    if (dirs.isNotEmpty && !dirs.any((e) => e.$1 == d)) d = dirs.first.$1;
    final rows = r.lineStops(widget.routeId, d);
    final st = r.statusOf(widget.routeId);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(children: [
              LineBullet(route.short,
                  color: route.color, textColor: route.textColor, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (route.long.isEmpty ? 'Ligne ${route.short}' : route.long)
                          .toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ts(18, w: FontWeight.w900, h: 1.1),
                    ),
                    if (st != null)
                      Text(st.title,
                          style: ts(12.5,
                              w: FontWeight.w800, c: healthColor(st.health))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => r.selectRoute(null),
                icon: const Icon(Icons.close_rounded, color: C.grey),
              ),
            ]),
          ),
          if (dirs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                for (var i = 0; i < dirs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Pill(
                      label: '→ ${dirs[i].$2.toUpperCase()}',
                      selected: dirs[i].$1 == d,
                      onTap: () => setState(() => dir = dirs[i].$1),
                    ),
                  ),
                ],
              ]),
            ),
          Container(height: 4, color: route.color),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(Icons.schedule_rounded,
                    'Aucune course annoncée sur cette ligne')
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Timeline(
                      color: route.color,
                      stops: [
                        for (final s in rows)
                          TimelineStop(
                            name: s.name,
                            time: s.next == null
                                ? (s.skipped ? 'NON DESSERVI' : '—')
                                : countdown(fromEpoch(s.next!)),
                            timeColor: s.next == null
                                ? (s.skipped ? C.red : C.grey)
                                : (s.delay != null && s.delay! >= 2
                                    ? C.red
                                    : Colors.white),
                            note: s.next == null
                                ? null
                                : 'PROCHAIN PASSAGE ${hhmm(fromEpoch(s.next!))}'
                                    '${s.delay != null && s.delay! >= 1 ? ' · +${s.delay} MIN' : ''}',
                            skipped: s.skipped,
                            onTap: s.groupKey == null
                                ? null
                                : () => r.select(s.groupKey),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class TaoLoading extends StatelessWidget {
  final TaoRepository repo;
  const TaoLoading({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final r = repo;
    final String title;
    final String sub;
    switch (r.phase) {
      case TaoPhase.downloading:
        title = 'TÉLÉCHARGEMENT DES HORAIRES TAO';
        sub = '${(r.progress * 100).round()} % · environ 16 Mo, une fois par semaine';
        break;
      case TaoPhase.extracting:
        title = 'DÉCOMPRESSION';
        sub = 'Préparation des fichiers…';
        break;
      case TaoPhase.loading:
        title = 'CHARGEMENT DU RÉSEAU';
        sub = 'Arrêts et lignes…';
        break;
      case TaoPhase.error:
        title = 'DONNÉES TAO INDISPONIBLES';
        sub = r.error ?? '';
        break;
      default:
        title = 'DÉMARRAGE';
        sub = '';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
      child: Panel(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const LineBullet('TAO', color: C.red, size: 72),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: ts(18, w: FontWeight.w900, ls: 0.5)),
              const SizedBox(height: 14),
              if (r.phase != TaoPhase.error)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: r.phase == TaoPhase.downloading ? r.progress : null,
                    minHeight: 8,
                    color: C.yellow,
                    backgroundColor: C.raised,
                  ),
                ),
              const SizedBox(height: 12),
              Text(sub,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: ts(12.5, c: C.grey, w: FontWeight.w600, h: 1.35)),
              if (r.phase == TaoPhase.error) ...[
                const SizedBox(height: 16),
                YellowButton('RÉESSAYER', onTap: () => r.init()),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
