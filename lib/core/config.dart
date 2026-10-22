import 'package:shared_preferences/shared_preferences.dart';

/// Configuration globale : URLs des sources et clé API SNCF.
class Config {
  static const sncfBase = 'https://api.sncf.com/v1/coverage/sncf';

  /// GTFS statique TAO (Keolis Métropole Orléans / Orléans Métropole, Licence Ouverte 2.0).
  static const taoGtfsUrl =
      'https://chouette.enroute.mobi/api/v1/datas/keolis_orleans/gtfs.zip';

  /// GTFS-RT TAO (trip updates).
  static const taoRtUrl = 'https://ara-api.enroute.mobi/tao/gtfs/trip-updates';

  static const userAgent = 'fr.laurent.transit_orleans';

  /// Clé injectée à la compilation : --dart-define=SNCF_API_KEY=...
  static const _envKey = String.fromEnvironment('SNCF_API_KEY');

  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// Clé saisie dans Réglages (prioritaire), sinon clé de compilation.
  static String get sncfKey {
    final k = prefs.getString('sncf_key');
    if (k != null && k.trim().isNotEmpty) return k.trim();
    return _envKey.trim();
  }

  static bool get hasBuildKey => _envKey.trim().isNotEmpty;

  static Future<void> setSncfKey(String k) async {
    await prefs.setString('sncf_key', k.trim());
  }
}
