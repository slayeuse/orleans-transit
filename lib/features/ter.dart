import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/sncf.dart';
import '../widgets/common.dart';
import '../widgets/timeline.dart';

Widget terChip(TerTrain t) => switch (t.state) {
      TrainState.onTime => const StatusChip('À L\'HEURE', color: C.green),
      TrainState.delayed =>
        StatusChip('+${t.delayMin} MIN', color: C.red, filled: true),
      TrainState.cancelled =>
        const StatusChip('SUPPRIMÉ', color: C.red, filled: true),
      TrainState.disrupted => const StatusChip('PERTURBÉ', color: C.orange),
      TrainState.theoretical => const StatusChip('THÉORIQUE', color: C.grey),
    };

/// Écran TER : les deux sens côte à côte (format paysage).
class TerScreen extends StatefulWidget {
  const TerScreen({super.key});
  @override
  State<TerScreen> createState() => _TerScreenState();
}

class _TerScreenState extends State<TerScreen> {
  @override
  void initState() {
    super.initState();
    App.ter.attach();
  }

  @override
  void dispose() {
    App.ter.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.ter,
      builder: (context, _) {
        final r = App.ter;
        final dis = r.disruptions;
        return Stack(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(r),
                if (r.error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBar(r.error!),
                ],
                if (dis.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DisruptionBar(dis),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: _DirectionPanel(
                              from: 'ARTENAY',
                              to: 'ORLÉANS',
                              board: r.toOrleans,
                              loading: r.loading)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _DirectionPanel(
                              from: 'ORLÉANS',
                              to: 'ARTENAY',
                              board: r.toArtenay,
                              loading: r.loading)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 26,
            bottom: 22,
            child: YellowFab(
              icon: Icons.refresh_rounded,
              busy: r.loading,
              tooltip: 'Actualiser',
              onTap: () => r.refresh(force: true),
            ),
          ),
        ]);
      },
    );
  }

  Widget _header(TerRepository r) {
    final at = r.updatedAt;
    return Row(children: [
      const LineBullet('TER', color: C.ter, size: 50),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ARTENAY ⇄ ORLÉANS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(28, w: FontWeight.w900, ls: -1, h: 1.05)),
            const SizedBox(height: 2),
            Text(
                at == null
                    ? 'TER Centre-Val de Loire · temps réel SNCF'
                    : 'TER Centre-Val de Loire · MAJ ${hhmm(at)}',
                style: ts(12.5, c: C.grey, w: FontWeight.w600)),
          ],
        ),
      ),
      LiveClock(style: ts(34, w: FontWeight.w900, ls: -1)),
    ]);
  }
}

class _ErrorBar extends StatelessWidget {
  final String text;
  const _ErrorBar(this.text);
  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: C.red),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: ts(13, w: FontWeight.w700), maxLines: 2)),
      ]),
    );
  }
}

class _DisruptionBar extends StatelessWidget {
  final List<TerDisruption> list;
  const _DisruptionBar(this.list);

  @override
  Widget build(BuildContext context) {
    final first = list.first;
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAppSheet(
          context,
          (ctx) => SheetFrame(
            header: Text('PERTURBATIONS TER',
                style: ts(22, w: FontWeight.w900)),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => Panel(
                color: C.raised,
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                        list[i].title.isEmpty ? 'Information' : list[i].title,
                        color: list[i].effect == 'NO_SERVICE'
                            ? C.red
                            : C.orange),
                    const SizedBox(height: 6),
                    Text(list[i].text, style: ts(14, h: 1.35)),
                  ],
                ),
              ),
            ),
          ),
        ),
        child: Row(children: [
          Container(width: 6, height: 46, color: C.orange),
          const SizedBox(width: 12),
          const Icon(Icons.warning_amber_rounded, color: C.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(first.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ts(13, w: FontWeight.w700)),
          ),
          if (list.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: StatusChip('+${list.length - 1}', color: C.orange),
            ),
          const Icon(Icons.chevron_right_rounded, color: C.grey),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

class _DirectionPanel extends StatelessWidget {
  final String from;
  final String to;
  final TerBoard? board;
  final bool loading;
  const _DirectionPanel(
      {required this.from,
      required this.to,
      required this.board,
      required this.loading});

  @override
  Widget build(BuildContext context) {
    final b = board;
    Widget body;
    if (b == null) {
      body = loading
          ? const Center(child: CircularProgressIndicator(color: C.yellow))
          : const EmptyState(Icons.cloud_off_rounded, 'Horaires indisponibles');
    } else if (b.trains.isEmpty) {
      body = const EmptyState(
          Icons.nightlight_round, 'Aucun train dans les prochaines heures');
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: b.trains.length,
        separatorBuilder: (_, __) => const Divider(
            height: 1, color: C.stroke, indent: 18, endIndent: 18),
        itemBuilder: (context, i) => _TrainRow(b.trains[i]),
      );
    }
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(children: [
              Flexible(
                child: Text(from,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(19, w: FontWeight.w900, ls: -0.3)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: C.yellow, size: 24),
              ),
              Flexible(
                child: Text(to,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(19, w: FontWeight.w900, ls: -0.3)),
              ),
            ]),
          ),
          Container(height: 4, color: C.ter),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _TrainRow extends StatelessWidget {
  final TerTrain t;
  const _TrainRow(this.t);

  @override
  Widget build(BuildContext context) {
    final cancelled = t.state == TrainState.cancelled;
    final delayed = t.state == TrainState.delayed;
    return InkWell(
      onTap: () => showTrainSheet(context, t),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        child: Row(children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hhmm(t.dep),
                    style: ts(26,
                        w: FontWeight.w900,
                        ls: -1,
                        h: 1.05,
                        c: cancelled
                            ? C.grey
                            : (delayed ? C.red : Colors.white),
                        deco: cancelled ? TextDecoration.lineThrough : null)),
                if (delayed)
                  Text(hhmm(t.baseDep),
                      style: ts(12,
                          c: C.grey, deco: TextDecoration.lineThrough)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '→ ${(t.direction.isEmpty ? 'TER' : t.direction).toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(14.5, w: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(
                    child: Text(
                      '${t.mode} ${t.number} · arr. ${hhmm(t.arr)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(12, c: C.grey, w: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  VoieTag(t.platformDep),
                ]),
                if (t.messages.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t.messages.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11.5, c: C.orange, w: FontWeight.w700)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              terChip(t),
              const SizedBox(height: 5),
              if (!cancelled)
                Text(countdown(t.dep),
                    style: ts(12, c: C.grey, w: FontWeight.w800)),
            ],
          ),
        ]),
      ),
    );
  }
}

void showTrainSheet(BuildContext context, TerTrain t) {
  final stops = <TimelineStop>[];
  for (var i = 0; i < t.stops.length; i++) {
    final s = t.stops[i];
    final time = s.time;
    final base = s.baseTime;
    final isLate = time != null &&
        base != null &&
        time.difference(base).inMinutes >= 1;
    stops.add(TimelineStop(
      name: s.name,
      time: time == null ? null : hhmm(time),
      oldTime: (isLate && base != null) ? hhmm(base) : null,
      timeColor: isLate ? C.red : null,
      note: (i == 0 || i == t.stops.length - 1)
          ? 'VOIE ${s.platform ?? '– (affichée en gare)'}'
          : null,
      skipped: t.state == TrainState.cancelled,
    ));
  }
  showAppSheet(
    context,
    (ctx) => SheetFrame(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const LineBullet('TER', color: C.ter, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.mode} ${t.number}',
                      style: ts(22, w: FontWeight.w900)),
                  Text('→ ${t.direction.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(13, c: C.grey, w: FontWeight.w700)),
                ],
              ),
            ),
            terChip(t),
          ]),
          for (final m in t.messages) ...[
            const SizedBox(height: 10),
            Panel(
              color: C.raised,
              radius: 16,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: C.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(m, style: ts(13, h: 1.3))),
              ]),
            ),
          ],
        ],
      ),
      child: stops.isEmpty
          ? const EmptyState(Icons.route_rounded, 'Détail des arrêts indisponible')
          : Timeline(stops: stops, color: C.ter),
    ),
  );
}
