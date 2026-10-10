# BiblioD — Gestionnaire de Bibliothèque Personnelle

BiblioD est une application bureautique (Linux Desktop) de gestion de bibliothèque personnelle, développée en Dart avec le framework Flutter et SQLite FFI. L'application stocke l'intégralité des données en local sur le poste utilisateur, propose des modules d'enrichissement par Internet (Wikipédia, Open Library) et intègre un système de sauvegarde et de synchronisation distante via le protocole WebDAV.

---

<img width="1495" height="740" alt="image" src="https://github.com/user-attachments/assets/3fdab064-1e85-4bd0-ae69-334525d63663" />


## Sommaire

1. [Fonctionnalités](#fonctionnalités)
   - [Gestion des livres](#1-gestion-des-livres)
   - [Recherche et enrichissement ISBN](#2-recherche-et-enrichissement-isbn)
   - [Tableau de bord et affichage](#3-tableau-de-bord-et-affichage)
   - [Recherche instantanée (Omnibox)](#4-recherche-instantanée-omnibox)
   - [Statistiques de collection](#5-statistiques-de-collection)
   - [Fiche auteur Wikipédia](#6-fiche-auteur-wikipédia)
   - [Bibliographie de l'auteur et comparatif](#7-bibliographie-de-lauteur-et-comparatif)
   - [Gestion du stockage local et import/export](#8-gestion-du-stockage-local-et-importexport)
   - [Sauvegarde et synchronisation WebDAV](#9-sauvegarde-et-synchronisation-webdav)
2. [Architecture Technique Globale](#architecture-technique-globale)
   - [Schéma d'architecture](#schéma-darchitecture)
   - [Description des couches](#description-des-couches)
   - [Protocole de synchronisation WebDAV](#protocole-de-synchronisation-webdav)
   - [Matrice de gestion des conflits](#matrice-de-gestion-des-conflits)
3. [Installation et Exécution](#installation-et-exécution)
   - [Prérequis](#prérequis-linux)
   - [Installation des dépendances](#installation-des-dépendances)
   - [Lancement en mode développement](#lancement-en-mode-développement)
   - [Compilation binaire release](#compilation-binaire-release)
4. [Empaquetage Linux (v1.0)](#empaquetage-linux-v10)
5. [Tests et Qualité de Code](#tests-et-qualité-de-code)
6. [Licence](#licence)

---

## Fonctionnalités

### 1. Gestion des livres
- **Fiche détaillée** : Enregistrement du titre, nom et prénom de l'auteur, série, numéro de tome, genre, format de support (Physique, Numérique, etc.), année d'édition, éditeur, numéro ISBN, appréciation personnelle (notation de 0 à 5 étoiles), notes libres et image de couverture.
- **Raccourci clavier** : Ouverture rapide du formulaire d'ajout via le raccourci `Ctrl + N`.
- **Mémorisation du support** : Le format du dernier livre saisi est automatiquement proposé par défaut pour les ajouts suivants.
- **Édition et suppression** : Double-clic sur une ligne du tableau pour ouvrir la fiche de modification, avec confirmation avant suppression définitive.

### 2. Recherche et enrichissement ISBN
- **Interrogation en ligne** : Saisie d'un code ISBN-10 ou ISBN-13 avec interrogation de l'API Open Library.
- **Auto-complétion** : Récupération du titre, de l'auteur, de l'éditeur, de l'année de publication et téléchargement local de l'image de couverture.

### 3. Tableau de bord et affichage
- **Notation directe** : Attribution ou modification de la note par clic direct sur les étoiles dans la colonne *Appréciation*, sans ouvrir la boîte de dialogue d'édition.
- **Ajustement de la taille de texte** : Boutons `A-`, `100%` et `A+` dans la barre d'outils pour modifier la taille de la police du tableau (delta de -2 à +6 points).
- **Gestion des colonnes** : Activation et désactivation des colonnes à afficher (*Titre, Auteur, Prénom, Appréciation, Genre, Série, N° série, Format, ISBN, Remarques*).
- **Tri multi-colonnes** : Tri croissant ou décroissant par clic sur les en-têtes de colonnes.
- **Barre d'état** : Compteur d'ouvrages affichés / total et rappel du tri actif.

### 4. Recherche instantanée (Omnibox)
- Filtrage en temps réel dès la saisie dans le champ de recherche.
- Recherche simultanée sur le titre, le nom, le prénom, la série, l'ISBN, le genre et les remarques.

### 5. Statistiques de collection
- Synthèse chiffrée de la bibliothèque : total d'ouvrages, nombre d'auteurs distincts et nombre de séries.
- Répartition par support (physique vs numérique).
- Distribution des appréciations (de 1 à 5 étoiles, et non notés).
- Classement des auteurs les plus représentés et des genres les plus fréquents.

### 6. Fiche auteur Wikipédia
- Consultation de la biographie d'un auteur depuis la fiche d'un livre via l'API Wikipédia France.
- Affichage du portrait, d'un extrait biographique et lien direct vers l'article complet dans le navigateur.

### 7. Bibliographie de l'auteur et comparatif
- Recensement des œuvres d'un auteur via l'API Open Library.
- **Sélecteur de langue** : Filtrage des œuvres par langue (`fre` français par défaut, `eng` anglais, `spa` espagnol, ou toutes les langues).
- **Résolution des titres traduits** : Affichage prioritaire de l'édition traduite avec le titre original en sous-titre.
- **Comparatif de collection** :
  - Détection automatique des œuvres déjà possédées dans la base locale (badge vert).
  - Identification des œuvres manquantes (badge orange) avec statistiques de complétion.
  - Bouton d'ajout direct d'une œuvre manquante pré-remplissant titre, auteur, année et ISBN officiel.

### 8. Gestion du stockage local et import/export
- **Emplacement par défaut** : Données stockées dans `~/.local/share/com.bibliod.bibliod/`.
- **Déplacement à chaud de la base** : Possibilité de relocaliser le fichier SQLite (`bibliod.db`) et les couvertures vers un dossier personnalisé (ex. clé USB, disque externe, dossier partagé).
- **Import / Export CSV** :
  - Export complet au format CSV avec séparateur point-virgule et encodage UTF-8 avec BOM.
  - Import tolérant aux variations d'en-têtes et formats.
- **Gestion des thèmes** : Sélection du thème Clair, Sombre ou synchronisé avec le Système.

### 9. Sauvegarde et synchronisation WebDAV
- **Sauvegarde distante sécurisée** : Envoi de la base SQLite et de son manifeste d'intégrité vers un serveur WebDAV (Nextcloud, ownCloud, NAS Synology/QNAP, Apache/Nginx WebDAV).
- **Déclenchement automatique à la fermeture** : L'application effectue une sauvegarde lors de sa fermeture si :
  1. Le service WebDAV est activé et configuré dans les paramètres ;
  2. Des modifications locales n'ont pas encore été synchronisées (`hasUnsyncedChanges`) ;
  3. Le serveur distant est accessible (avec un délai d'expiration strict de 4 secondes pour ne jamais retarder la fermeture).
- **Contrôles dans les Paramètres** :
  - Saisie de l'URL du dossier distant, du nom d'utilisateur et du mot de passe / jeton d'application.
  - Bouton « Tester la connexion » avec indicateur visuel de diagnostic.
  - Bouton « Synchroniser maintenant » avec rapport d'état immédiat.
  - Affichage de la date/heure de la dernière synchronisation réussie et du nombre de modifications en attente.

---

## Architecture Technique Globale

L'application est construite selon une architecture en couches (Clean Architecture simplifiée) séparant la présentation, la logique métier et l'accès aux données. La gestion d'état repose sur les primitives natives de Flutter (`ChangeNotifier`, `ValueNotifier`, `ListenableBuilder`) afin de limiter les dépendances externes.

### Schéma d'architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Présentation (Widgets & UI)                     │
│  HomeScreen, BookTableView, ToolbarWidget, SettingsDialog, Dialogs     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Écoute (ListenableBuilder)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Contrôleurs d'état (State Notifiers)                 │
│         BookNotifier           │           SettingsNotifier            │
└─────────────────┬──────────────┴───────────────────┬───────────────────┘
                  │                                  │
                  ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Domaine (Entités Métier)                        │
│   Book, AuthorItem, BookStatistics, SyncManifest, SyncResult           │
└─────────────────┬──────────────────────────────────┬───────────────────┘
                  │                                  │
                  ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    Couche Données & Services (Data)                    │
│                                                                        │
│  ┌──────────────────────┐  ┌─────────────────┐  ┌──────────────────┐   │
│  │    BookRepository    │  │ WebDavService   │  │ StoragePathServ. │   │
│  └──────────┬───────────┘  └────────┬────────┘  └─────────┬────────┘   │
│             │                       │                     │            │
│  ┌──────────▼───────────┐  ┌────────▼────────┐  ┌─────────▼────────┐   │
│  │    DatabaseHelper    │  │  Client WebDAV  │  │ Fichiers locaux  │   │
│  │ (SQLite FFI / Linux) │  │  (HTTP / SSL)   │  │   & Couvertures  │   │
│  └──────────────────────┘  └─────────────────┘  └──────────────────┘   │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Services Externes : IsbnLookupService, AuthorWorksService,       │  │
│  │                     WikipediaService, CsvService                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Description des couches

1. **Couche Présentation (`lib/features/*/presentation`)** :
   - Widgets réactifs découpés par fonctionnalité (`books`, `settings`).
   - Dialogue des paramètres (`SettingsDialog`) regroupant l'import/export, le déplacement du stockage et la configuration WebDAV.
   - Surveillance du cycle de vie de l'application via `AppLifecycleListener` dans `HomeScreen` pour le déclenchement de la sauvegarde à la fermeture.

2. **Couche Contrôleurs (`BookNotifier`, `SettingsNotifier`)** :
   - Maintient l'état en mémoire (livres filtrés, tri, recherche, colonnes, préférences de thème, paramètres WebDAV).
   - Notifie l'interface graphique de façon granulaire sans rebuild global inutile.

3. **Couche Domaine (`lib/features/*/domain`)** :
   - Modèles de données immutables : `Book`, `AuthorItem`, `BookStatistics`.
   - Modèles de synchronisation : `SyncManifest` (métadonnées distantes et hash SHA-256) et `SyncResult` (statut et diagnostic).

4. **Couche Données (`lib/features/*/data` et `lib/core/*`)** :
   - **`BookRepository`** : Exécute les requêtes SQL (CRUD, transactions par lot, recherche). Incrémente automatiquement le compteur de modifications `local_change_counter` à chaque écriture et gère le point de contrôle `last_synced_counter`.
   - **`DatabaseHelper`** : Gestion de la connexion SQLite native via `sqflite_common_ffi` et `databaseFactoryFfi`.
   - **`StoragePathService`** : Détermine les chemins du système de fichiers (`getApplicationSupportDirectory`) et orchestre la relocalisation des fichiers.
   - **`WebDavService`** : Implémente les verbes HTTP WebDAV (`PROPFIND`, `MKCOL`, `GET`, `PUT`), le calcul d'empreinte SHA-256 de la base SQLite et la gestion des révisions.

### Protocole de synchronisation WebDAV

Le serveur WebDAV distant conserve deux fichiers dans le répertoire dédié :
- `bibliod.db` : Fichier de base de données SQLite complet.
- `bibliod_sync.json` : Fichier manifeste contenant :
  ```json
  {
    "client_id": "client_1728123456789_123",
    "client_name": "hostname-machine",
    "revision": 12,
    "last_modified": "2026-10-05T09:30:00.000Z",
    "books_count": 215,
    "db_sha256": "3a7bd8c9e..."
  }
  ```

### Matrice de gestion des conflits

| État local | État distant (WebDAV) | Situation | Action exécutée |
| :--- | :--- | :--- | :--- |
| **Aucune modification** | **Révision inchangée** | À jour | Aucune action réseau requise. |
| **Modifications locales** | **Révision inchangée** | Sauvegarde normale | Envoi de `bibliod.db`, incrémentation de la révision sur le manifeste distant. |
| **Aucune modification** | **Révision plus récente** | Mise à jour distante | Remplacement automatique et silencieux de la base locale par la version distante. |
| **Modifications locales** | **Révision plus récente** | **Conflit concurrent** | Traitement sécurisé anti-écrasement (voir ci-dessous). |

**Traitement des conflits concurrents :**
- **À la fermeture automatique de l'application** : La base locale modifiée est téléversée sous le nom d'archive `bibliod_conflict_local_<horodatage>.db` sur le serveur WebDAV. Le fichier principal distant `bibliod.db` reste inchangé. Un drapeau de conflit est consigné localement pour inviter l'utilisateur à arbitrer lors du prochain lancement.
- **En synchronisation manuelle dans les paramètres** : Une boîte de dialogue affiche les informations de chaque version et propose à l'utilisateur de conserver sa version locale (avec archivage de la version distante) ou d'adopter la version en ligne (avec sauvegarde préalable de la base locale).

---

## Installation et Exécution

### Prérequis (Linux)
Assurez-vous de disposer des outils de développement et des bibliothèques C système :
```bash
# Debian / Ubuntu / Mint
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsqlite3-dev

# Arch Linux / Manjaro
sudo pacman -Syu --needed base-devel cmake ninja pkgconf gtk3 sqlite
```

### Installation des dépendances
```bash
git clone https://github.com/dvim-dev/bibliod.git
cd bibliod
flutter pub get
```

### Lancement en mode développement
```bash
flutter run -d linux
```

### Compilation binaire release
```bash
flutter build linux
```
L'exécutable compilé et ses dépendances partagées se trouvent dans :  
`build/linux/x64/release/bundle/`

---

## Empaquetage Linux (v1.0.1)

Des scripts d'empaquetage automatisés sont disponibles dans le dossier `packaging/` :

- **Debian / Ubuntu (`.deb`)** :
  ```bash
  python3 packaging/build_deb.py
  ```
  Le paquet `.deb` est généré dans le répertoire `dist/`.

- **Arch Linux (`.pkg.tar.zst`)** :
  ```bash
  cd packaging/arch && makepkg -f && cd ../..
  ```

- **Génération globale de tous les paquets** :
  ```bash
  ./packaging/build_all.sh
  ```

---

## Tests et Qualité de Code

Le projet intègre une suite de tests unitaires et de tests de composants d'interface :

```bash
# Exécution de l'ensemble de la suite de tests (38 tests)
flutter test .

# Analyse statique du code (linter Flutter)
flutter analyze .

# Formatage automatique selon les standards Dart
dart format .
```

---

## Licence

Ce projet est sous licence MIT. Pour plus d'informations, consultez le fichier `LICENSE` (ou les mentions d'en-tête du projet).
