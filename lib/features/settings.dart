import 'package:flutter/material.dart';

import '../app.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _key;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: Config.prefs.getString('sncf_key') ?? '');
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Config.setSncfKey(_key.text);
    await App.ter.resetStations();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Clé enregistrée')));
    App.ter.refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final gtfs = App.tao.gtfsDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
      child: ListView(children: [
        Text('RÉGLAGES', style: ts(28, w: FontWeight.w900, ls: -0.5)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Clé API SNCF', color: C.yellow),
                  const SizedBox(height: 6),
                  Text(
                    Config.hasBuildKey
                        ? 'Une clé a été intégrée à la compilation. Vous pouvez la remplacer ici.'
                        : 'Aucune clé intégrée : collez votre clé (api.sncf.com).',
                    style: ts(12.5, c: C.grey, h: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _key,
                    obscureText: !_show,
                    style: ts(14, w: FontWeight.w600),
                    decoration: inputDeco('Clé personnelle (laisser vide = clé intégrée)',
                            Icons.key_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _show = !_show),
                        icon: Icon(
                            _show
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: C.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  YellowButton('ENREGISTRER', onTap: _save),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Données TAO', color: C.yellow),
                  const SizedBox(height: 6),
                  Text(
                    gtfs == null
                        ? 'Horaires pas encore téléchargés.'
                        : 'Horaires téléchargés le ${gtfs.day}/${two(gtfs.month)}/${gtfs.year} à ${hhmm(gtfs)}. Mise à jour automatique chaque semaine.',
                    style: ts(12.5, c: C.grey, h: 1.35),
                  ),
                  const SizedBox(height: 12),
                  YellowButton('METTRE À JOUR MAINTENANT', onTap: () {
                    App.tao.init(forceDownload: true);
                    App.nav.value = 2;
                  }),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: App.tao,
          builder: (context, _) {
            final t = App.tao;
            final ok = t.rtError == null && t.rtFetchedAt != null;
            final at = t.rtFetchedAt;
            return Panel(
              child: Row(children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: ok ? C.green : C.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Diagnostic temps réel TAO',
                          color: C.yellow),
                      const SizedBox(height: 4),
                      Text(
                        ok
                            ? 'OK · ${t.rtTripCount} courses suivies · MAJ ${hhmm(at!)}'
                            : 'Erreur : ${t.rtErrorDetail ?? t.rtError ?? 'pas encore chargé'}'
                                '${at != null ? ' · dernier succès ${hhmm(at)}' : ''}',
                        style: ts(13, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                YellowButton('TESTER', onTap: () => t.refreshRt(force: true)),
              ]),
            );
          },
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('À propos des données', color: C.yellow),
              const SizedBox(height: 8),
              Text(
                '• TER : API SNCF (moteur Navitia), horaires théoriques et temps réel. '
                'Le numéro de voie n\'est pas fourni par l\'API : il s\'affiche « – » et reste à vérifier sur les écrans en gare.\n'
                '• TAO : données ouvertes d\'Orléans Métropole / Keolis Métropole Orléans '
                '(GTFS et GTFS-RT, Licence Ouverte 2.0). Les retards sont calculés en comparant '
                'le temps réel aux horaires prévus ; l\'info trafic est déduite des suppressions '
                'et des arrêts non desservis.\n'
                '• Carte : © OpenStreetMap contributors, fond © CARTO.',
                style: ts(12.5, c: C.grey, h: 1.45),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
