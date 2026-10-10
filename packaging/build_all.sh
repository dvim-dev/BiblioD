#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== [1/4] Compilation Flutter Linux Release ==="
cd "$PROJECT_ROOT"
flutter build linux --release

echo "=== [2/4] Génération des icônes SVG et PNG ==="
for s in 16 32 48 64 128 256 512; do
  mkdir -p "$PROJECT_ROOT/packaging/icons/${s}x${s}"
  rsvg-convert -w $s -h $s "$PROJECT_ROOT/packaging/bibliod.svg" -o "$PROJECT_ROOT/packaging/icons/${s}x${s}/bibliod.png"
done

mkdir -p "$PROJECT_ROOT/dist"

echo "=== [3/4] Création du paquet Arch Linux (.pkg.tar.zst) ==="
cd "$PROJECT_ROOT/packaging/arch"
makepkg -f --nodeps
cp bibliod-*.pkg.tar.zst "$PROJECT_ROOT/dist/"

echo "=== [4/4] Création du paquet Debian / Ubuntu (.deb) ==="
cd "$PROJECT_ROOT"
python3 "$PROJECT_ROOT/packaging/build_deb.py"

echo ""
echo "=== Paquets prêts dans $PROJECT_ROOT/dist/ ==="
ls -lh "$PROJECT_ROOT/dist/"
