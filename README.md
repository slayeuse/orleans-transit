<div align="center">

# 🟡 Orléans Transit

### TER Artenay ⇄ Orléans · Bus & Tram TAO · en temps réel

![Android](https://img.shields.io/badge/Android-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.32-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Version](https://img.shields.io/badge/version-1.2.2-FFCC00?style=for-the-badge)
![Format](https://img.shields.io/badge/format-paysage-000000?style=for-the-badge)

*Une application personnelle de suivi des transports de la métropole d'Orléans,
dessinée dans l'esprit de la signalétique du métro de New York (Unimark / Massimo Vignelli).*

</div>

---

## 📑 Sommaire

1. [Fonctionnalités](#-fonctionnalités)
2. [Direction artistique](#-direction-artistique)
3. [Installer l'application (Android)](#-installer-lapplication-android)
4. [Mettre à jour](#-mettre-à-jour)
5. [Clés API & secrets](#-clés-api--secrets)
6. [Sources de données](#-sources-de-données)
7. [Utilisation](#-utilisation)
8. [Dépannage](#-dépannage)
9. [Limites connues](#-limites-connues)
10. [Et sur iPhone ?](#-et-sur-iphone-)
11. [Architecture du code](#-architecture-du-code)
12. [Historique des versions](#-historique-des-versions)
13. [Crédits & licences](#-crédits--licences)

---

## ✨ Fonctionnalités

### 🚆 TER Artenay ⇄ Orléans
| | |
|---|---|
| **Deux sens côte à côte** | Artenay → Orléans et Orléans → Artenay sur le même écran |
| **Temps réel** | Comparaison horaire prévu / horaire réel : retard affiché en rouge, ancienne heure barrée |
| **Suppressions** | Trains supprimés barrés avec la pastille `SUPPRIMÉ` |
| **Perturbations** | Bandeau orange avec le message officiel SNCF (travaux, incidents…) |
| **Détail d'un train** | Frise verticale de tous les arrêts, avec heures et retards |
| **Compte à rebours** | « 7 MIN », « PROCHE »… |
| **Actualisation** | Automatique toutes les 60 s + bouton jaune ⟳ |

### 🚋 Réseau TAO (bus & tram)
| | |
|---|---|
| **Recherche d'arrêt** | Tous les quais d'un même arrêt sont regroupés |
| **Tableau des passages** | Par ligne et destination, 3 prochains passages, retards calculés |
| **Plan de ligne** | Tous les arrêts reliés, prochain passage à chaque arrêt, choix du sens |
| **Info trafic** | Lignes classées : normale · retards · déviation · suppressions |
| **Horaires de secours** | Si une course n'est pas suivie en temps réel, l'horaire prévu s'affiche (« théo. ») |
| **Actualisation** | Automatique toutes les 30 s |

### 🗺️ Carte
- Fond sombre **CARTO** haute définition
- **Tracés de toutes les lignes** aux couleurs officielles (tram épais, bus fin)
- Filtres **TRAM / BUS**, et **isolement d'une ligne** en touchant sa puce
- Arrêts affichés selon le zoom (tram en vue large, tous les arrêts en zoomant)
- Fiche d'arrêt avec prochains passages en touchant un point
- Raccourcis **ORL** (Orléans) et **ART** (Artenay)

### ⭐ Favoris & accueil
- Étoile ★ sur n'importe quel arrêt
- Accueil : grande horloge, prochain TER dans chaque sens, état du réseau TAO et passages des arrêts favoris

---

## 🎨 Direction artistique

Inspirée du *NYC Transit Graphics Standards Manual* (1970).

| Élément | Valeur |
|---|---|
| Fond | Noir absolu `#000000` |
| Cartes | Gris très foncé `#1C1C1E` / `#18181A`, coins arrondis 24–32 px |
| Action principale | Jaune signalétique `#FFCC00` (boutons, sélection, FAB) |
| À l'heure | Vert `#34C759` |
| Retard / supprimé | Rouge `#EE352E` |
| Perturbation | Orange `#FF6319` |
| TER | Bleu `#0062B0` |
| Typographie | **Inter**, titres en Extra-Bold, métadonnées en gris |
| Lignes | Puces circulaires (*subway bullets*) aux couleurs officielles TAO |

---

## 📲 Installer l'application (Android)

> **Rien à installer sur l'ordinateur** : l'APK est compilé gratuitement sur les serveurs de GitHub.

### 1. Le dépôt GitHub
1. Créez un compte sur **[github.com](https://github.com)**.
2. **+** (en haut à droite) → **New repository** → nom `orleans-transit` → **Private** → **Create repository**.
3. Sur la page qui s'ouvre, cliquez **uploading an existing file** (ou **Add file → Upload files**).
4. Glissez **le contenu** du dossier `orleans_transit` (les dossiers `lib`, `test`, `ci` et les fichiers), puis **Commit changes**.

> ⚠️ **Le dossier `.github` est souvent oublié** (son nom commence par un point, il est masqué).
> Créez-le à la main : onglet **Actions** → **set up a workflow yourself** → nommez le fichier
> `build-apk.yml`, collez le contenu de `.github/workflows/build-apk.yml`, puis **Commit changes**.

### 2. Les clés secrètes
**Settings → Secrets and variables → Actions → New repository secret** :

| Name | Valeur |
|---|---|
| `SNCF_API_KEY` | votre clé API SNCF |
| `CARTO_API_KEY` | votre clé CARTO |

### 3. Compiler
Onglet **Actions** → **Build APK** → **Run workflow**. Attendez la ✅ verte (≈ 10 min).
Chaque envoi de fichiers relance aussi la compilation automatiquement.

### 4. Installer sur le téléphone
1. Sur le téléphone : dépôt GitHub → **Releases** (colonne de droite) → dernière version → **app-release.apk**.
2. Autorisez l'installation depuis le navigateur quand Android le demande.
3. **Premier lancement** : l'onglet TAO télécharge les horaires du réseau (≈ 16 Mo). Préférez le Wi-Fi.

---

## 🔄 Mettre à jour

1. Envoyez les fichiers modifiés sur GitHub (**Add file → Upload files** → **Commit changes**).
2. Attendez la ✅ verte dans **Actions**.
3. Installez le nouvel APK depuis **Releases**, **par-dessus** l'ancien : pas besoin de désinstaller.

> La signature de l'application est fixe (fichier `ci/debug.keystore`), ce qui permet
> les mises à jour directes. Ne supprimez pas ce fichier.

Les horaires TAO se mettent à jour automatiquement **chaque semaine**
(ou tout de suite via **RÉGLAGES → Mettre à jour maintenant**).

---

## 🔑 Clés API & secrets

| Service | Utilisation | Gratuit | Obtenir une clé |
|---|---|---|---|
| **API SNCF** (Navitia) | Horaires TER, temps réel, perturbations | ✅ | [digital.sncf.com/startup/api](https://www.digital.sncf.com/startup/api) |
| **CARTO Basemaps** | Fond de carte sombre | ✅ usage non commercial | [carto.com/basemaps/apikey](https://carto.com/basemaps/apikey/) |
| TAO (GTFS / GTFS-RT) | Horaires et temps réel bus/tram | ✅ sans clé | — |

**Où sont les clés ?**
- **Jamais dans le code** : elles sont injectées à la compilation depuis les secrets GitHub.
- Elles peuvent aussi être saisies (ou remplacées) dans l'écran **RÉGLAGES** de l'application.
- Si une clé a circulé (messages, captures…), régénérez-la sur le site du service puis mettez à jour le secret.

---

## 📡 Sources de données

| Donnée | Source | Format | Rafraîchissement |
|---|---|---|---|
| TER | `api.sncf.com/v1` | JSON (Navitia) | 60 s |
| Horaires TAO | `chouette.enroute.mobi/api/v1/datas/keolis_orleans/gtfs.zip` | GTFS | 1×/semaine |
| Temps réel TAO | `ara-api.enroute.mobi/tao/gtfs/trip-updates` | GTFS-RT (Protobuf) | 30 s |
| Fond de carte | `basemaps.cartocdn.com` | Tuiles raster | à la demande |

---

## 🧭 Utilisation

```
┌──────┬─────────────────────────────────────────────┐
│  O   │                                             │
│      │                                             │
│ ACC. │   Accueil : horloge · TER · TAO · Favoris   │
│ TER  │   TER : les deux sens côte à côte           │
│ TAO  │   TAO : Arrêts | Lignes | Trafic  →  détail │
│CARTE │   Carte : plan du réseau                    │
│RÉGL. │   Réglages : clés, données, diagnostic      │
└──────┴─────────────────────────────────────────────┘
```

| Lecture des couleurs | |
|---|---|
| 🟢 `À L'HEURE` / heure verte | Conforme à l'horaire |
| 🔴 `+5 MIN` / heure rouge | Retard |
| 🔴 `SUPPRIMÉ` / `SUPPR.` | Train ou passage supprimé |
| 🟠 `PERTURBÉ` / `DÉVIATION` | Perturbation, arrêts non desservis |
| ⚪ `THÉORIQUE` / `théo.` | Horaire prévu, pas de suivi temps réel |

---

## 🛠️ Dépannage

| Symptôme | Solution |
|---|---|
| **« Build APK » n'apparaît pas dans Actions** | Le fichier `.github/workflows/build-apk.yml` manque → voir [Installer, étape 1](#1-le-dépôt-github) |
| **Compilation en ❌ rouge** | Cliquez sur la compilation → étape en rouge → copiez les dernières lignes du journal |
| **« Application non installée »** | Ancienne version signée différemment : désinstallez une fois, puis réinstallez |
| **« Clé API SNCF manquante / refusée »** | Vérifiez le secret `SNCF_API_KEY`, ou saisissez la clé dans RÉGLAGES |
| **Filigrane « API KEY REQUIRED » sur la carte** | Secret `CARTO_API_KEY` absent → ajoutez-le ou saisissez la clé dans RÉGLAGES |
| **TAO : aucun passage** | RÉGLAGES → **Diagnostic temps réel TAO** → **TESTER**. Le message indique la cause |
| **Pas de tracés sur la carte** | RÉGLAGES → **Mettre à jour maintenant** (données TAO) |
| **Données TAO bloquées au téléchargement** | Vérifiez la connexion, puis **Réessayer** |

Le **diagnostic temps réel TAO** (Réglages) affiche soit
`OK · 1 800 courses suivies · MAJ 10:45`, soit l'erreur exacte (taille, type et premiers octets de la réponse).

---

## ⚠️ Limites connues

- **Voie / quai TER** : l'API SNCF ne la fournit pas. L'application affiche `VOIE –`, à vérifier sur les écrans en gare.
- **Info trafic TAO** : le réseau ne publie pas de flux d'alertes officiel. L'état des lignes est **déduit du temps réel** (suppressions, arrêts non desservis, retards).
- **Retards TAO** : calculés en comparant le temps réel aux horaires prévus. Ils apparaissent quelques secondes après l'ouverture.
- **Pas de notifications** en arrière-plan (choix volontaire).
- **Format paysage uniquement** sur cette version.

---

## 🍏 Et sur iPhone ?

Le code (Flutter) peut aussi produire une app iPhone (IPA), mais **iOS impose une signature** : un IPA non signé est refusé à l'installation, même sans passer par l'App Store.

| Méthode | Coût | Durée de validité | Remarques |
|---|---|---|---|
| **TrollStore** | Gratuit | ♾️ permanente | Seulement iOS **14.0 → 16.6.1** et **17.0** |
| **AltStore** (identifiant Apple gratuit) | Gratuit | 7 jours, **renouvelés automatiquement** en Wi-Fi | Un ordinateur avec AltServer doit être allumé de temps en temps |
| **Compte Apple Developer** | 99 $/an | 1 an | Installation via TestFlight, la plus simple |

> 🚫 À éviter : les sites qui vendent des « certificats » d'installation, révoqués régulièrement par Apple.

Une **version verticale** adaptée à l'iPhone est envisagée (barre d'onglets en bas, écrans empilés).

---

## 🧱 Architecture du code

```
orleans_transit/
├── .github/workflows/
│   └── build-apk.yml        Compilation automatique de l'APK (GitHub Actions)
├── ci/
│   └── debug.keystore       Signature fixe (mises à jour sans désinstaller)
├── lib/
│   ├── main.dart            Démarrage, orientation paysage, thème
│   ├── app.dart             Accès globaux, navigation, favoris
│   ├── core/
│   │   ├── config.dart      URLs des sources, clés SNCF & CARTO
│   │   ├── theme.dart       Palette et typographie Vignelli
│   │   └── util.dart        Heures, dates, normalisation des noms
│   ├── data/
│   │   ├── sncf.dart        Client Navitia, fusion théorique / temps réel TER
│   │   ├── gtfs_static.dart Téléchargement GTFS, horaires prévus, tracés
│   │   ├── gtfs_rt.dart     Décodeur GTFS-Realtime (Protobuf, gzip, JSON)
│   │   └── tao.dart         Arrêts, tableaux, plans de ligne, info trafic
│   ├── widgets/
│   │   ├── common.dart      Puces de ligne, cartes, FAB jaune, pastilles
│   │   └── timeline.dart    Frise verticale des arrêts
│   └── features/
│       ├── shell.dart       Rail de navigation
│       ├── home.dart        Accueil
│       ├── ter.dart         Écran TER
│       ├── tao_screen.dart  Écran TAO
│       ├── map_screen.dart  Carte
│       └── settings.dart    Réglages & diagnostic
├── test/
└── pubspec.yaml             Dépendances
```

**Dépendances principales** : `http`, `shared_preferences`, `path_provider`, `archive`, `flutter_map`, `latlong2`, `google_fonts`.

**Compiler soi-même** (si Flutter est installé) :
```bash
flutter create --platforms=android --org fr.laurent --project-name transit_orleans .
flutter build apk --release \
  --dart-define=SNCF_API_KEY=VOTRE_CLE \
  --dart-define=CARTO_API_KEY=VOTRE_CLE
```
Puis ajouter dans `android/app/src/main/AndroidManifest.xml` la permission `INTERNET`
et `android:screenOrientation="sensorLandscape"` (le workflow GitHub le fait automatiquement).

---

## 📜 Historique des versions

| Version | Nouveautés |
|---|---|
| **1.2.2** | 🐛 Correction du décodeur temps réel TAO (« flux sans course ») |
| **1.2.1** | Décodage tolérant (gzip / JSON), diagnostic détaillé |
| **1.2.0** | 🗺️ Nouvelle carte : fond CARTO avec clé, tracés des lignes, filtres, fiches d'arrêt |
| **1.1.0** | Quais regroupés par arrêt, horaires prévus en secours, diagnostic TAO, signature fixe |
| **1.0.0** | Première version : TER, TAO, carte, favoris, design Vignelli |

---

## 🙏 Crédits & licences

- **Données TAO** : Orléans Métropole / Keolis Métropole Orléans — [Licence Ouverte 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/), via [transport.data.gouv.fr](https://transport.data.gouv.fr)
- **Données TER** : [API SNCF](https://www.digital.sncf.com/startup/api), moteur [Navitia](https://doc.navitia.io)
- **Carte** : © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors · © [CARTO](https://carto.com/attributions)
- **Police** : [Inter](https://rsms.me/inter/) (SIL Open Font License)
- **Inspiration graphique** : *NYC Transit Authority Graphics Standards Manual*, Unimark International (1970)

<div align="center">

**Application personnelle, non affiliée à la SNCF, à TAO, à Keolis ni à la MTA.**

🟡

</div>
