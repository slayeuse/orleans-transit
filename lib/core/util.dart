/// Petites fonctions utilitaires (heures, dates, normalisation, JSON).

String two(int v) => v.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

DateTime fromEpoch(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

int nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Format Navitia : 20261022T093000 (heure locale).
DateTime? parseNavitia(dynamic v) {
  if (v is! String || v.length < 15) return null;
  try {
    return DateTime(
      int.parse(v.substring(0, 4)),
      int.parse(v.substring(4, 6)),
      int.parse(v.substring(6, 8)),
      int.parse(v.substring(9, 11)),
      int.parse(v.substring(11, 13)),
      int.parse(v.substring(13, 15)),
    );
  } catch (_) {
    return null;
  }
}

String navitiaDate(DateTime d) =>
    '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}';

const jours = [
  'LUNDI',
  'MARDI',
  'MERCREDI',
  'JEUDI',
  'VENDREDI',
  'SAMEDI',
  'DIMANCHE'
];
const mois = [
  'JANVIER',
  'FÉVRIER',
  'MARS',
  'AVRIL',
  'MAI',
  'JUIN',
  'JUILLET',
  'AOÛT',
  'SEPTEMBRE',
  'OCTOBRE',
  'NOVEMBRE',
  'DÉCEMBRE'
];

String dateLabel(DateTime d) =>
    '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';

/// "PROCHE", "7 MIN" ou l'heure si > 1 h.
String countdown(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final m = (t.difference(n).inSeconds / 60).floor();
  if (m <= 0) return 'PROCHE';
  if (m >= 60) return hhmm(t);
  return '$m MIN';
}

const _accents = <String, String>{
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Minuscules, sans accents ni ponctuation : sert de clé de regroupement et de recherche.
String norm(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String? str(dynamic v) => v is String ? v : null;
List<dynamic> lst(dynamic v) => v is List ? v : const [];
Map<dynamic, dynamic> mp(dynamic v) => v is Map ? v : const {};

String stripHtml(String s) => s
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// "Orléans (Orléans)" -> "Orléans"
String cleanStation(String s) => s.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
