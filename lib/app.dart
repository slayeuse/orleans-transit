import 'package:flutter/foundation.dart';

import 'core/config.dart';
import 'data/sncf.dart';
import 'data/tao.dart';

/// Favoris : arrêts TAO (clé de regroupement).
class Favorites extends ChangeNotifier {
  final Set<String> stops = {};

  Favorites() {
    stops.addAll(Config.prefs.getStringList('fav_stops') ?? const <String>[]);
  }

  bool has(String key) => stops.contains(key);

  void toggle(String key) {
    if (!stops.remove(key)) stops.add(key);
    Config.prefs.setStringList('fav_stops', stops.toList());
    notifyListeners();
  }
}

/// Points d'accès globaux de l'application.
class App {
  static late TerRepository ter;
  static late TaoRepository tao;
  static late Favorites favs;

  /// Onglet courant : 0 accueil, 1 TER, 2 TAO, 3 carte, 4 réglages.
  static final nav = ValueNotifier<int>(0);

  static void init() {
    ter = TerRepository();
    tao = TaoRepository();
    favs = Favorites();
    tao.init();
  }

  static void openStop(String groupKey) {
    tao.select(groupKey);
    nav.value = 2;
  }
}
