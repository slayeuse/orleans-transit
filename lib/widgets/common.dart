import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/util.dart';

/// Carte gris très foncé à coins très arrondis.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = C.card,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Puce de ligne circulaire (subway bullet).
class LineBullet extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final double size;
  const LineBullet(this.label,
      {super.key, required this.color, this.textColor, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final auto = color.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    var fg = textColor ?? auto;
    // Si la couleur de texte fournie est trop proche du fond, on corrige.
    if ((fg.computeLuminance() - color.computeLuminance()).abs() < 0.25) {
      fg = auto;
    }
    final n = label.length;
    final factor = n <= 1 ? 0.6 : (n == 2 ? 0.46 : 0.34);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      padding: EdgeInsets.all(size * 0.1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: ts(size * factor, w: FontWeight.w800, c: fg, ls: -0.5, h: 1),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const StatusChip(this.text,
      {super.key, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled
        ? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withAlpha(38),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!filled) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(text, style: ts(11, w: FontWeight.w800, c: fg, ls: 0.8)),
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SectionLabel(this.text, {super.key, this.color = C.grey});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: ts(11.5, w: FontWeight.w800, c: color, ls: 1.6));
}

/// Bouton d'action flottant jaune signalétique.
class YellowFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  final String? tooltip;
  const YellowFab(
      {super.key,
      required this.icon,
      required this.onTap,
      this.busy = false,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: C.yellow,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.black),
                )
              : Icon(icon, color: Colors.black, size: 30),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Pastille de sélection (onglets, directions).
class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const Pill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.yellow : C.raised,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ts(12,
                w: FontWeight.w800,
                c: selected ? Colors.black : Colors.white,
                ls: 0.8),
          ),
        ),
      ),
    );
  }
}

class SegmentedPills extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegmentedPills(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Pill(
              label: labels[i],
              selected: i == index,
              onTap: () => onChanged(i)),
        ),
      ],
    ]);
  }
}

/// Horloge qui se met à jour toute seule.
class LiveClock extends StatefulWidget {
  final TextStyle style;
  const LiveClock({super.key, required this.style});
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(hhmm(DateTime.now()), style: widget.style, maxLines: 1);
}

/// Petite étiquette de voie.
class VoieTag extends StatelessWidget {
  final String? voie;
  const VoieTag(this.voie, {super.key});
  @override
  Widget build(BuildContext context) {
    final known = voie != null && voie!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: known ? Colors.white : C.dim, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'VOIE ${known ? voie : '–'}',
        style: ts(10.5, w: FontWeight.w800, c: known ? Colors.white : C.grey, ls: 0.6),
      ),
    );
  }
}

/// Cadre commun des bottom sheets.
class SheetFrame extends StatelessWidget {
  final Widget header;
  final Widget child;
  const SheetFrame({super.key, required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      height: h * 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: C.dim, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            header,
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

Future<void> showAppSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.card,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 680),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: builder,
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState(this.icon, this.text, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: C.dim, size: 40),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: ts(14, c: C.grey, w: FontWeight.w600, h: 1.35)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      ),
    );
  }
}

class YellowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const YellowButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.yellow,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(label,
              style: ts(13, w: FontWeight.w800, c: Colors.black, ls: 0.8)),
        ),
      ),
    );
  }
}
