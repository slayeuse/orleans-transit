import 'package:flutter/material.dart';

import '../core/theme.dart';

class TimelineStop {
  final String name;
  final String? time;
  final String? oldTime;
  final String? note;
  final Color? timeColor;
  final Color? noteColor;
  final bool highlight;
  final bool skipped;
  final VoidCallback? onTap;
  const TimelineStop({
    required this.name,
    this.time,
    this.oldTime,
    this.note,
    this.timeColor,
    this.noteColor,
    this.highlight = false,
    this.skipped = false,
    this.onTap,
  });
}

/// Liste d'arrêts reliés par une ligne verticale (style plan de métro).
class Timeline extends StatefulWidget {
  final List<TimelineStop> stops;
  final Color color;
  final int? scrollTo;
  const Timeline(
      {super.key, required this.stops, required this.color, this.scrollTo});

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  static const rowH = 58.0;
  late final ScrollController _c;

  @override
  void initState() {
    super.initState();
    final i = widget.scrollTo ?? 0;
    _c = ScrollController(
        initialScrollOffset: i > 1 ? (i - 1) * rowH : 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    return ListView.builder(
      controller: _c,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: stops.length,
      itemBuilder: (context, i) =>
          _row(stops[i], i == 0, i == stops.length - 1),
    );
  }

  Widget _row(TimelineStop s, bool first, bool last) {
    final color = widget.color;
    final big = first || last || s.highlight;
    final dotSize = big ? 22.0 : 14.0;
    final dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: s.skipped ? C.card : (s.highlight ? C.yellow : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
            color: s.skipped ? C.dim : Colors.black, width: big ? 4 : 3),
      ),
    );
    final nameStyle = ts(
      big ? 16 : 14.5,
      w: big ? FontWeight.w800 : FontWeight.w600,
      c: s.skipped ? C.dim : Colors.white,
      deco: s.skipped ? TextDecoration.lineThrough : null,
    );
    final content = SizedBox(
      height: rowH,
      child: Row(children: [
        SizedBox(
          width: 36,
          height: rowH,
          child: Stack(children: [
            Align(
              alignment: Alignment.center,
              child: Column(children: [
                Expanded(
                    child: Container(
                        width: 6,
                        color: first ? Colors.transparent : color)),
                Expanded(
                    child: Container(
                        width: 6,
                        color: last ? Colors.transparent : color)),
              ]),
            ),
            Center(child: dot),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
              if (s.note != null && s.note!.isNotEmpty)
                Text(s.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(11.5,
                        w: FontWeight.w700,
                        c: s.noteColor ?? C.grey,
                        ls: 0.4)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (s.time != null)
              Text(s.time!,
                  style: ts(16,
                      w: FontWeight.w800,
                      c: s.skipped ? C.dim : (s.timeColor ?? Colors.white))),
            if (s.oldTime != null)
              Text(s.oldTime!,
                  style: ts(11.5,
                      c: C.grey, deco: TextDecoration.lineThrough)),
          ],
        ),
        if (s.onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: C.grey),
        ],
      ]),
    );
    if (s.onTap == null) return content;
    return InkWell(onTap: s.onTap, borderRadius: BorderRadius.circular(12), child: content);
  }
}
