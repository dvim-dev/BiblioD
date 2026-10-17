#!/usr/bin/env bash
# ==============================================================================
# build-deb.sh - Script local de génération du paquet .deb pour BiblioD via Docker
#
# Compile et empaquète l'application dans un conteneur Ubuntu 22.04 LTS (Jammy)
# afin d'assurer la compatibilité binaire (glibc 2.35) avec :
#   - Ubuntu 22.04 LTS et versions supérieures (24.04 LTS, etc.)
#   - Debian 12 (Bookworm) et versions supérieures (Trixie, etc.)
#   - Linux Mint 21+, etc.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

IMAGE_NAME="bibliod-builder:ubuntu22.04"
FLUTTER_VERSION="3.38.9"
NO_CACHE=false
CLEAN_BUILD=false
INTERACTIVE_SHELL=false
CUSTOM_VERSION=""

# Affichage de l'aide
show_help() {
    cat << EOF
Usage: ./build-deb.sh [OPTIONS]

Options :
  -h, --help               Affiche ce message d'aide
  -c, --clean              Nettoie le dossier dist/ et build/ avant la compilation
  --no-cache               Reconstruit l'image Docker sans utiliser le cache
  --flutter-version <ver>  Spécifie la version Flutter (défaut : $FLUTTER_VERSION)
  --image-name <nom>       Nom du tag de l'image Docker (défaut : $IMAGE_NAME)
  --version <ver>          Spécifie la version du paquet Debian (ex: 1.0.1-1)
  --shell                  Ouvre un shell interactif bash dans le conteneur de build

Exemples :
  ./build-deb.sh
  ./build-deb.sh --clean
  ./build-deb.sh --no-cache
EOF
}

# Analyse des arguments de la ligne de commande
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --flutter-version)
            FLUTTER_VERSION="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --version)
            CUSTOM_VERSION="$2"
            shift 2
            ;;
        --shell)
            INTERACTIVE_SHELL=true
            shift
            ;;
        *)
            echo "Option inconnue : $1" >&2
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo "  BiblioD - Génération du paquet .deb via Docker"
echo "  Cible : Ubuntu 22.04+ / Debian 12+ (x86_64)"
echo "=========================================================="

# 1. Vérification de la présence de Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Erreur : La commande 'docker' est introuvable." >&2
    echo "Veuillez installer Docker sur votre système pour continuer." >&2
    exit 1
fi

# Détection de l'utilisateur réel pour préserver la propriété des fichiers générés
ACTUAL_UID="${SUDO_UID:-$(id -u)}"
ACTUAL_GID="${SUDO_GID:-$(id -g)}"

# Détermination du mode d'accès à Docker (direct ou via sudo)
DOCKER_CMD="docker"
if ! docker info >/dev/null 2>&1; then
    if [ -S /var/run/docker.sock ] && ! [ -w /var/run/docker.sock ]; then
        echo "Info : Accès non privilégié à /var/run/docker.sock restreint."
        echo "Basculement automatique vers 'sudo docker'..."
        DOCKER_CMD="sudo docker"
    fi
fi

# 2. Vérification de l'accessibilité du démon Docker
if ! $DOCKER_CMD info >/dev/null 2>&1; then
    echo "Erreur : Impossible de contacter le démon Docker avec '$DOCKER_CMD'." >&2
    echo "" >&2
    echo "Si le service n'est pas démarré :" >&2
    echo "  sudo systemctl start docker" >&2
    echo "" >&2
    echo "Pour exécuter Docker sans sudo à l'avenir, ajoutez votre utilisateur au groupe 'docker' :" >&2
    echo "  sudo usermod -aG docker \$USER" >&2
    echo "  newgrp docker   # ou fermez et rouvrez votre session utilisateur" >&2
    echo "" >&2
    echo "Sinon, vous pouvez lancer directement :" >&2
    echo "  sudo ./build-deb.sh" >&2
    exit 1
fi

# 3. Nettoyage si demandé
if [ "$CLEAN_BUILD" = true ]; then
    echo "==> Nettoyage préalable des répertoires build/ et dist/..."
    rm -rf "$PROJECT_ROOT/build" "$PROJECT_ROOT/dist"
fi

# 4. Construction / mise à jour de l'image Docker (utilise le cache de calques Docker)
echo "==> Vérification / construction de l'image Docker $IMAGE_NAME..."
BUILD_ARGS=()
if [ "$NO_CACHE" = true ]; then
    BUILD_ARGS+=(--no-cache)
fi
$DOCKER_CMD build "${BUILD_ARGS[@]}" \
    -f "$PROJECT_ROOT/Dockerfile.build" \
    -t "$IMAGE_NAME" \
    --build-arg FLUTTER_VERSION="$FLUTTER_VERSION" \
    "$PROJECT_ROOT"

# 5. Lancement de la compilation dans le conteneur
DOCKER_ENV=(
    -e TARGET_UID="$ACTUAL_UID"
    -e TARGET_GID="$ACTUAL_GID"
)

if [ -n "$CUSTOM_VERSION" ]; then
    DOCKER_ENV+=(-e APP_VERSION="$CUSTOM_VERSION")
fi

mkdir -p "$PROJECT_ROOT/dist"

if [ "$INTERACTIVE_SHELL" = true ]; then
    echo "==> Lancement d'un shell interactif dans le conteneur..."
    $DOCKER_CMD run --rm -it \
        "${DOCKER_ENV[@]}" \
        -v "$PROJECT_ROOT:/workspace" \
        "$IMAGE_NAME" \
        /bin/bash
    exit 0
fi

echo "==> Exécution du build dans le conteneur Docker..."
$DOCKER_CMD run --rm \
    "${DOCKER_ENV[@]}" \
    -v "$PROJECT_ROOT:/workspace" \
    "$IMAGE_NAME"

# 6. Vérification finale du paquet généré
echo ""
echo "=========================================================="
echo "  Vérification du paquet généré :"
echo "=========================================================="
DEB_FILES=("$PROJECT_ROOT/dist"/*.deb)
if [ -e "${DEB_FILES[0]}" ]; then
    for f in "${DEB_FILES[@]}"; do
        echo "  Fichier : $f ($(du -h "$f" | cut -f1))"
    done
    echo ""
    echo "Pour installer le paquet sur une machine Ubuntu ou Debian :"
    echo "  sudo apt install ./${DEB_FILES[0]#$PROJECT_ROOT/}"
    echo "ou :"
    echo "  sudo dpkg -i ./${DEB_FILES[0]#$PROJECT_ROOT/}"
else
    echo "Attention : Aucun fichier .deb trouvé dans $PROJECT_ROOT/dist/" >&2
    exit 1
fi
