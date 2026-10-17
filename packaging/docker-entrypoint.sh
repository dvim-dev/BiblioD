#!/usr/bin/env bash
set -euo pipefail

cd /workspace

# Configuration de git pour accepter le répertoire monté
git config --global --add safe.directory /workspace || true

# Configuration du cache pub
export PUB_CACHE="${PUB_CACHE:-/tmp/.pub-cache}"
mkdir -p "$PUB_CACHE"

echo "=========================================================="
echo "  BiblioD - Compilation .deb pour Ubuntu 22.04+ / Debian 12+"
echo "=========================================================="

# Si des arguments spécifiques ont été passés au conteneur, les exécuter
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

echo "--> [1/5] Nettoyage des caches Linux précédents..."
# Supprimer le cache de compilation CMake/Linux pour éviter toute contamination
rm -rf build/linux

echo "--> [2/5] Téléchargement et résolution des dépendances Dart/Flutter..."
flutter pub get

echo "--> [3/5] Compilation Flutter Linux Release (glibc 2.35)..."
flutter build linux --release

echo "--> [4/5] Génération des icônes SVG/PNG pour l'intégration bureau..."
if [ -f "packaging/bibliod.svg" ]; then
    for s in 16 32 48 64 128 256 512; do
        mkdir -p "packaging/icons/${s}x${s}"
        rsvg-convert -w "$s" -h "$s" "packaging/bibliod.svg" -o "packaging/icons/${s}x${s}/bibliod.png"
    done
fi

echo "--> [5/5] Création de l'archive Debian (.deb)..."
mkdir -p dist
python3 packaging/build_deb.py

# Rétablissement de la propriété des fichiers générés à l'utilisateur hôte
if [ -n "${TARGET_UID:-}" ] && [ -n "${TARGET_GID:-}" ]; then
    echo "--> Ajustement des permissions (UID: ${TARGET_UID}, GID: ${TARGET_GID})..."
    chown -R "${TARGET_UID}:${TARGET_GID}" dist build packaging/icons 2>/dev/null || true
fi

echo "=========================================================="
echo "  Succès ! Paquet Debian généré avec succès dans dist/:"
echo "=========================================================="
ls -lh dist/*.deb 2>/dev/null || ls -lh dist/
