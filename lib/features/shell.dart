import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme.dart';
import 'home.dart';
import 'map_screen.dart';
import 'settings.dart';
import 'tao_screen.dart';
import 'ter.dart';

/// Structure paysage : rail de navigation à gauche + contenu.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Row(children: [
          const _Rail(),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: App.nav,
              builder: (context, i, _) => switch (i) {
                0 => const HomeScreen(),
                1 => const TerScreen(),
                2 => const TaoScreen(),
                3 => const MapScreen(),
                _ => const SettingsScreen(),
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  static const _items = [
    (Icons.grid_view_rounded, 'ACCUEIL'),
    (Icons.train_rounded, 'TER'),
    (Icons.tram_rounded, 'TAO'),
    (Icons.map_rounded, 'CARTE'),
    (Icons.tune_rounded, 'RÉGLAGES'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      color: C.black,
      child: ValueListenableBuilder<int>(
        valueListenable: App.nav,
        builder: (context, sel, _) => Column(children: [
          const SizedBox(height: 14),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: C.yellow, shape: BoxShape.circle),
            child: Text('O',
                style: ts(24, w: FontWeight.w900, c: Colors.black, h: 1)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _RailItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: sel == i,
                    onTap: () => App.nav.value = i,
                  ),
              ],
            ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 54,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? C.yellow : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(icon,
                size: 22, color: selected ? Colors.black : C.grey),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: ts(9,
                  w: FontWeight.w800,
                  c: selected ? Colors.white : C.grey,
                  ls: 0.8)),
        ]),
      ),
    );
  }
}
