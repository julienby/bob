#!/bin/bash
# bob_install_venv.sh - Installation complète d'ICAGING Node v2 avec environnement virtuel
#
# Usage:
#   ./bob_install_venv.sh [OPTIONS]
#
# Options:
#   --install-dir DIR     Répertoire d'installation (défaut: ./icaging)
#   --git-user USER       Nom d'utilisateur GitLab
#   --git-token TOKEN     Token d'accès GitLab
#   --repo-url URL        URL complète du dépôt (avec auth)
#   --branch BRANCH       Branche à cloner (défaut: main)
#   --no-systemd          Ne pas configurer systemd
#   --skip-deps           Ne pas installer les dépendances système
#   --help                Afficher cette aide

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration par défaut
REPO_BASE_URL="https://git.litislab.fr/icaging/icaging.git"
BRANCH="${BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-./icaging}"
INSTALL_SYSTEMD="${INSTALL_SYSTEMD:-true}"
INSTALL_DEPS="${INSTALL_DEPS:-true}"
GIT_USER=""
GIT_TOKEN=""
REPO_URL=""

# Fonction pour afficher les messages
info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_help() {
    cat << EOF
bob_install_venv.sh - Installation complète d'ICAGING Node v2 avec environnement virtuel

Usage:
    ./bob_install_venv.sh [OPTIONS]

Options:
    --install-dir DIR     Répertoire d'installation (défaut: ./icaging)
    --git-user USER       Nom d'utilisateur GitLab
    --git-token TOKEN     Token d'accès GitLab (Personal Access Token)
    --repo-url URL        URL complète du dépôt avec authentification
    --branch BRANCH       Branche à cloner (défaut: main)
    --no-systemd          Ne pas configurer systemd
    --skip-deps           Ne pas installer les dépendances système
    --help                Afficher cette aide

Exemples:
    # Installation interactive (demande user et token)
    ./bob_install_venv.sh

    # Installation avec authentification en ligne de commande
    ./bob_install_venv.sh --git-user jbaudry --git-token glpat-xxxxx

    # Installation dans un répertoire spécifique
    ./bob_install_venv.sh --install-dir /opt/icaging --git-user jbaudry --git-token glpat-xxxxx

EOF
}

# Parser les arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --git-user)
                GIT_USER="$2"
                shift 2
                ;;
            --git-token)
                GIT_TOKEN="$2"
                shift 2
                ;;
            --repo-url)
                REPO_URL="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --no-systemd)
                INSTALL_SYSTEMD=false
                shift
                ;;
            --skip-deps)
                INSTALL_DEPS=false
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Option inconnue: $1"
                echo "Utilisez --help pour voir les options disponibles"
                exit 1
                ;;
        esac
    done
}

# Demander les identifiants GitLab si non fournis
get_git_credentials() {
    if [[ -z "$REPO_URL" ]]; then
        if [[ -z "$GIT_USER" ]]; then
            echo ""
            read -p "Nom d'utilisateur GitLab: " GIT_USER
            if [[ -z "$GIT_USER" ]]; then
                error "Nom d'utilisateur requis"
                exit 1
            fi
        fi
        
        if [[ -z "$GIT_TOKEN" ]]; then
            echo ""
            read -sp "Token d'accès GitLab (Personal Access Token): " GIT_TOKEN
            echo ""
            if [[ -z "$GIT_TOKEN" ]]; then
                error "Token d'accès requis"
                exit 1
            fi
        fi
        
        # Construire l'URL avec authentification
        # Format: https://user:token@git.litislab.fr/icaging/icaging.git
        REPO_URL="https://${GIT_USER}:${GIT_TOKEN}@git.litislab.fr/icaging/icaging.git"
    fi
    
    info "URL du dépôt configurée (avec authentification)"
}

# Détecter le gestionnaire de paquets
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# Installer les dépendances système
install_system_dependencies() {
    section "Installation des dépendances système"
    
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    if [[ "$pkg_manager" == "unknown" ]]; then
        error "Gestionnaire de paquets non détecté (apt-get, yum, dnf)"
        error "Veuillez installer manuellement: python3 python3-pip python3-venv git rsync openssh-client"
        exit 1
    fi
    
    info "Gestionnaire de paquets détecté: $pkg_manager"
    
    # Liste des paquets à installer
    local packages=(
        "python3"
        "python3-pip"
        "python3-venv"
        "git"
        "rsync"
        "openssh-client"
    )
    
    # Pour Debian/Ubuntu/Raspberry Pi OS
    if [[ "$pkg_manager" == "apt" ]]; then
        info "Mise à jour de la liste des paquets..."
        sudo apt-get update -qq
        
        info "Installation des paquets système..."
        for pkg in "${packages[@]}"; do
            if dpkg -l | grep -q "^ii  $pkg "; then
                info "  $pkg: déjà installé"
            else
                info "  Installation de $pkg..."
                sudo apt-get install -y "$pkg" > /dev/null 2>&1 || {
                    error "Échec de l'installation de $pkg"
                    exit 1
                }
            fi
        done
    fi
    
    # Pour RedHat/CentOS/Fedora
    if [[ "$pkg_manager" == "yum" ]] || [[ "$pkg_manager" == "dnf" ]]; then
        info "Mise à jour de la liste des paquets..."
        sudo "$pkg_manager" check-update -q || true
        
        info "Installation des paquets système..."
        for pkg in "${packages[@]}"; do
            if rpm -q "$pkg" &> /dev/null; then
                info "  $pkg: déjà installé"
            else
                info "  Installation de $pkg..."
                sudo "$pkg_manager" install -y "$pkg" > /dev/null 2>&1 || {
                    error "Échec de l'installation de $pkg"
                    exit 1
                }
            fi
        done
    fi
    
    info "Toutes les dépendances système sont installées"
}

# Cloner le dépôt GitLab
clone_repository() {
    section "Clonage du dépôt GitLab"
    
    # Convertir le chemin relatif en absolu
    INSTALL_DIR=$(cd "$(dirname "$INSTALL_DIR")" && pwd)/$(basename "$INSTALL_DIR")
    
    info "URL du dépôt: ${REPO_URL%%@*}@***"  # Masquer le token dans l'affichage
    info "Branche: $BRANCH"
    info "Répertoire d'installation: $INSTALL_DIR"
    
    # Si le répertoire existe déjà
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -d "$INSTALL_DIR/.git" ]]; then
            warn "Le répertoire $INSTALL_DIR existe déjà et contient un dépôt Git"
            read -p "Voulez-vous mettre à jour le dépôt existant ? (o/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Oo]$ ]]; then
                info "Mise à jour du dépôt existant..."
                cd "$INSTALL_DIR"
                git fetch origin
                git checkout "$BRANCH"
                git pull origin "$BRANCH"
                return 0
            else
                error "Installation annulée"
                exit 1
            fi
        else
            error "Le répertoire $INSTALL_DIR existe déjà mais n'est pas un dépôt Git"
            exit 1
        fi
    fi
    
    # Cloner le dépôt
    info "Clonage du dépôt..."
    set +e  # Désactiver set -e temporairement pour gérer les erreurs
    local clone_output
    clone_output=$(git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR" 2>&1)
    local clone_exit=$?
    set -e  # Réactiver set -e
    
    if [[ $clone_exit -eq 0 ]]; then
        info "Dépôt cloné avec succès"
    else
        # Vérifier si c'est une erreur d'authentification
        if echo "$clone_output" | grep -qi "authentication\|unauthorized\|permission\|denied"; then
            error "Échec de l'authentification GitLab"
            error "Vérifiez votre nom d'utilisateur et votre token d'accès"
            echo ""
            echo "Pour créer un token GitLab:"
            echo "  1. Allez sur https://git.litislab.fr/-/user_settings/personal_access_tokens"
            echo "  2. Créez un token avec les permissions 'read_repository'"
            exit 1
        else
            error "Échec du clonage du dépôt"
            echo "$clone_output" | grep -v "token" | tail -5
            exit 1
        fi
    fi
    
    # Rendre les scripts exécutables
    info "Configuration des permissions..."
    find "$INSTALL_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    find "$INSTALL_DIR" -name "*.py" -type f -exec chmod +x {} \;
    
    info "Installation terminée dans: $INSTALL_DIR"
}

# Créer et configurer l'environnement virtuel
create_venv() {
    section "Création de l'environnement virtuel"
    
    local venv_dir="$INSTALL_DIR/venv"
    local venv_python="$venv_dir/bin/python"
    local venv_pip="$venv_dir/bin/pip"
    
    # Vérifier que python3-venv est disponible
    if ! python3 -c "import venv" 2>/dev/null; then
        error "python3-venv n'est pas disponible"
        error "Installez-le avec: sudo apt-get install python3-venv"
        exit 1
    fi
    
    # Créer ou réutiliser l'environnement virtuel
    if [[ -d "$venv_dir" ]]; then
        info "Environnement virtuel existant trouvé: $venv_dir"
        read -p "Voulez-vous le réutiliser ? (O/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            warn "Suppression de l'ancien environnement virtuel..."
            rm -rf "$venv_dir"
            info "Création d'un nouvel environnement virtuel..."
            python3 -m venv "$venv_dir"
        fi
    else
        info "Création de l'environnement virtuel dans: $venv_dir"
        python3 -m venv "$venv_dir"
    fi
    
    # Vérifier que le venv fonctionne
    if [[ ! -f "$venv_python" ]]; then
        error "Échec de la création de l'environnement virtuel"
        exit 1
    fi
    
    info "Environnement virtuel créé avec succès"
    info "Python du venv: $($venv_python --version)"
    
    # Mettre à jour pip dans le venv
    section "Mise à jour de pip"
    "$venv_pip" install --upgrade pip --quiet > /dev/null 2>&1
    local pip_version
    pip_version=$("$venv_pip" --version | awk '{print $2}')
    info "pip dans le venv: $pip_version"
    
    # Installer les dépendances Python dans le venv
    section "Installation des dépendances Python dans le venv"
    
    local dependencies=(
        "flask"
        "psutil"
        "pyserial"
        "pytz"
    )
    
    info "Installation des dépendances Python..."
    for dep in "${dependencies[@]}"; do
        local module_name="${dep//-/_}"
        
        # Vérifier si déjà installé
        if "$venv_python" -c "import $module_name" 2>/dev/null; then
            info "  $dep: déjà installé"
        else
            info "  Installation de $dep..."
            if "$venv_pip" install "$dep" > /tmp/pip_install.log 2>&1; then
                # Vérifier que l'installation a réussi
                if "$venv_python" -c "import $module_name" 2>/dev/null; then
                    info "  $dep: installé avec succès"
                else
                    error "  Échec de l'installation de $dep (vérification échouée)"
                    cat /tmp/pip_install.log | tail -5
                    exit 1
                fi
            else
                error "  Échec de l'installation de $dep"
                cat /tmp/pip_install.log | tail -5
                exit 1
            fi
        fi
    done
    
    # Vérification finale
    info "Vérification des modules Python..."
    local all_ok=true
    for dep in "${dependencies[@]}"; do
        local module_name="${dep//-/_}"
        if "$venv_python" -c "import $module_name" 2>/dev/null; then
            info "  ✓ $dep"
        else
            error "  ✗ $dep: MANQUANT"
            all_ok=false
        fi
    done
    
    if [[ "$all_ok" == "true" ]]; then
        info "Toutes les dépendances Python sont installées dans le venv"
    else
        error "Certaines dépendances Python sont manquantes"
        exit 1
    fi
    
    # Créer un wrapper Python pour utiliser automatiquement le venv
    section "Configuration des scripts"
    local python_wrapper="$INSTALL_DIR/python3_venv"
    cat > "$python_wrapper" << 'EOF'
#!/bin/bash
# Wrapper Python qui utilise automatiquement le venv
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$SCRIPT_DIR/venv/bin/python"

if [ -f "$VENV_PYTHON" ]; then
    exec "$VENV_PYTHON" "$@"
else
    echo "ERREUR: Environnement virtuel introuvable. Exécutez: ./init/bob_install_venv.sh"
    exit 1
fi
EOF
    chmod +x "$python_wrapper"
    info "Wrapper Python créé: $python_wrapper"
}

# Configuration systemd
configure_systemd() {
    section "Configuration systemd"
    
    if [[ "$INSTALL_SYSTEMD" != "true" ]]; then
        info "Configuration systemd ignorée (--no-systemd)"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        warn "systemd n'est pas disponible sur ce système"
        warn "Vous devrez démarrer les services manuellement"
        return 0
    fi
    
    local service_file="$INSTALL_DIR/init/bob-cron.service"
    
    if [[ ! -f "$service_file" ]]; then
        warn "Fichier de service systemd introuvable: $service_file"
        return 0
    fi
    
    # Mettre à jour le chemin dans le fichier de service pour utiliser le venv
    local temp_service="/tmp/bob-cron.service"
    sed "s|/home/pi/icaging|$INSTALL_DIR|g" "$service_file" | \
        sed "s|ExecStart=/usr/bin/python3|ExecStart=$INSTALL_DIR/venv/bin/python3|g" > "$temp_service"
    
    info "Installation du service systemd..."
    sudo cp "$temp_service" /etc/systemd/system/bob-cron.service
    rm "$temp_service"
    
    sudo systemctl daemon-reload
    sudo systemctl enable bob-cron.service
    
    info "Service systemd installé et activé (utilise le venv)"
    info "Pour démarrer le service: sudo systemctl start bob-cron.service"
}

# Résumé de l'installation
show_summary() {
    section "Résumé de l'installation"
    
    info "Installation terminée avec succès !"
    echo ""
    echo "Répertoire d'installation: $INSTALL_DIR"
    echo "Environnement virtuel: $INSTALL_DIR/venv"
    echo ""
    echo "Prochaines étapes:"
    echo ""
    echo "1. Accéder au répertoire d'installation:"
    echo "   cd $INSTALL_DIR"
    echo ""
    echo "2. Utiliser le venv:"
    echo "   # Option 1: Activer le venv"
    echo "   source venv/bin/activate"
    echo "   python3 bob_app_cli.py start"
    echo ""
    echo "   # Option 2: Utiliser le wrapper"
    echo "   ./python3_venv bob_app_cli.py start"
    echo ""
    echo "3. Configurer SSH pour rsync (optionnel):"
    echo "   ./init/setup_ssh_keys.sh"
    echo ""
    echo "4. Accéder à l'interface web:"
    echo "   http://\$(hostname -I | awk '{print \$1}'):5000"
    echo ""
    if [[ "$INSTALL_SYSTEMD" == "true" ]] && command -v systemctl &> /dev/null; then
        echo "5. Démarrer le service systemd (si configuré):"
        echo "   sudo systemctl start bob-cron.service"
        echo ""
    fi
    echo "Vous pouvez maintenant utiliser les outils de captation de données !"
    echo ""
}

# Fonction principale
main() {
    echo ""
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║         ICAGING Node v2 - Installation avec Environnement Virtuel      ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parser les arguments
    parse_args "$@"
    
    # Obtenir les identifiants GitLab
    get_git_credentials
    
    # Installation des dépendances système
    if [[ "$INSTALL_DEPS" == "true" ]]; then
        install_system_dependencies
    else
        info "Installation des dépendances système ignorée (--skip-deps)"
    fi
    
    # Clonage du dépôt
    clone_repository
    
    # Création et configuration du venv
    create_venv
    
    # Configuration systemd
    configure_systemd
    
    # Résumé
    show_summary
}

# Point d'entrée
main "$@"
