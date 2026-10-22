# Orléans Transit 🚆🚋

Application Android **en format paysage** de suivi en temps réel :
- **TER Artenay ⇄ Orléans** (les deux sens côte à côte, retards, suppressions, perturbations, détail des arrêts)
- **Réseau TAO** bus & tram (recherche d'arrêt, tableau des prochains passages, plan de ligne, info trafic)
- **Carte** OpenStreetMap des arrêts et des gares
- **Favoris** affichés sur l'écran d'accueil

Direction artistique « NYC Transit » (Vignelli) : fond noir, puces de ligne rondes, jaune signalétique #FFCC00.

---

## Obtenir l'APK sans rien installer (≈ 15 minutes, une seule fois)

La compilation se fait gratuitement sur les serveurs de GitHub.

### 1. Créer le dépôt
1. Créez un compte gratuit sur **https://github.com** (ou connectez-vous).
2. En haut à droite : **+ → New repository**.
3. Nom : `orleans-transit` · cochez **Private** · cliquez **Create repository**.

### 2. Envoyer les fichiers
1. Sur la page du dépôt, cliquez **uploading an existing file**.
2. Décompressez le zip sur votre ordinateur, ouvrez le dossier `orleans_transit`,
   sélectionnez **tout son contenu** (dossiers `lib`, `test`, `.github` et les fichiers) et glissez-le dans la page.
3. Cliquez **Commit changes**.

> ⚠️ Le dossier `.github` commence par un point : sur Mac il est masqué (Cmd + Maj + . pour l'afficher).
> S'il manque après l'envoi : **Add file → Create new file**, nommez-le
> `.github/workflows/build-apk.yml` et collez-y le contenu du fichier du même nom.

### 3. Ajouter la clé SNCF (secrète)
1. Dans le dépôt : **Settings → Secrets and variables → Actions → New repository secret**.
2. Name : `SNCF_API_KEY` · Secret : votre clé SNCF · **Add secret**.

(La clé n'apparaît ainsi jamais dans le code. Vous pouvez aussi la coller plus tard dans l'écran **RÉGLAGES** de l'application.)

### 4. Lancer la compilation
1. Onglet **Actions** → **Build APK** → **Run workflow** → **Run workflow**.
2. Attendez la coche verte (≈ 8 à 10 minutes).

### 5. Installer sur le téléphone
1. Sur le téléphone, ouvrez le dépôt GitHub → **Releases** (colonne de droite) → dernière version → **app-release.apk**.
2. Android demandera d'autoriser l'installation depuis le navigateur : acceptez.
3. Au premier lancement, l'onglet TAO télécharge les horaires (≈ 16 Mo, une fois par semaine) : utilisez de préférence le Wi-Fi.

Chaque nouvel envoi de fichiers relance automatiquement une compilation.

---

## Sources de données
| Donnée | Source | Clé |
|---|---|---|
| TER | API SNCF (Navitia) `api.sncf.com/v1` | Oui (gratuite) |
| TAO horaires | GTFS Orléans Métropole / Keolis (Licence Ouverte 2.0) | Non |
| TAO temps réel | GTFS-RT `ara-api.enroute.mobi/tao` | Non |
| Carte | OpenStreetMap + fond sombre CARTO | Non |

### Limites connues
- **Voie / quai TER** : l'API SNCF ne la fournit pas ; l'application affiche « VOIE – ». À vérifier sur les écrans en gare.
- **Info trafic TAO** : le réseau ne publie pas de flux d'alertes ; l'état des lignes est déduit du temps réel
  (passages supprimés, arrêts non desservis = déviation, retards calculés).
- **Retards TAO** : calculés en comparant le temps réel aux horaires prévus (apparaissent quelques secondes après l'ouverture).

## Structure du code
```
lib/
├── main.dart              orientation paysage, thème
├── app.dart               accès globaux, favoris
├── core/                  config (URLs, clé), thème Vignelli, utilitaires
├── data/
│   ├── sncf.dart          client Navitia + fusion théorique / temps réel (TER)
│   ├── gtfs_static.dart   téléchargement + lecture GTFS TAO, index des horaires
│   ├── gtfs_rt.dart       décodeur GTFS-Realtime (Protobuf)
│   └── tao.dart           arrêts, tableaux, lignes, info trafic
├── widgets/               puces de ligne, cartes, FAB jaune, frise d'arrêts
└── features/              accueil, TER, TAO, carte, réglages
```

## Compiler soi-même (optionnel, si Flutter est installé)
```
flutter create --platforms=android --org fr.laurent --project-name transit_orleans .
flutter build apk --release --dart-define=SNCF_API_KEY=VOTRE_CLE
```
Puis ajouter dans `android/app/src/main/AndroidManifest.xml` la permission INTERNET et
`android:screenOrientation="sensorLandscape"` sur l'activité (le workflow GitHub le fait automatiquement).
