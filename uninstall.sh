#!/bin/bash
#
# BOB (Behaviour Observation Base) - Uninstall Script
# Script de désinstallation pour l'outil BOB
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration (same defaults as install)
BOB_HOME="${BOB_HOME:-/opt/bob}"
BOB_USER="${BOB_USER:-bob}"
BOB_DATA_DIR="${BOB_DATA_DIR:-/var/lib/bob}"
BOB_LOG_DIR="${BOB_LOG_DIR:-/var/log/bob}"
BOB_CONFIG_DIR="${BOB_CONFIG_DIR:-/etc/bob}"

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

confirm_uninstall() {
    echo ""
    print_warn "ATTENTION: Cette opération va supprimer BOB et ses données!"
    echo ""
    echo "Les éléments suivants seront supprimés:"
    echo "  - Service BOB"
    echo "  - Installation: $BOB_HOME"
    echo "  - Configuration: $BOB_CONFIG_DIR"
    echo "  - Utilisateur: $BOB_USER"
    echo ""
    
    if [ "$1" != "--yes" ]; then
        read -p "Voulez-vous également supprimer les données dans $BOB_DATA_DIR? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            REMOVE_DATA=true
        else
            REMOVE_DATA=false
        fi
        
        echo ""
        read -p "Êtes-vous sûr de vouloir désinstaller BOB? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Désinstallation annulée"
            exit 0
        fi
    else
        REMOVE_DATA=true
    fi
}

stop_service() {
    print_info "Arrêt du service BOB..."
    
    if systemctl is-active --quiet bob; then
        systemctl stop bob
        print_info "Service arrêté"
    else
        print_info "Service déjà arrêté"
    fi
    
    if systemctl is-enabled --quiet bob 2>/dev/null; then
        systemctl disable bob
        print_info "Service désactivé"
    fi
}

remove_service() {
    print_info "Suppression du service systemd..."
    
    if [ -f /etc/systemd/system/bob.service ]; then
        rm -f /etc/systemd/system/bob.service
        systemctl daemon-reload
        print_info "Service supprimé"
    else
        print_info "Fichier service non trouvé"
    fi
}

remove_directories() {
    print_info "Suppression des répertoires..."
    
    if [ -d "$BOB_HOME" ]; then
        rm -rf "$BOB_HOME"
        print_info "Installation supprimée: $BOB_HOME"
    fi
    
    if [ -d "$BOB_CONFIG_DIR" ]; then
        rm -rf "$BOB_CONFIG_DIR"
        print_info "Configuration supprimée: $BOB_CONFIG_DIR"
    fi
    
    if [ -d "$BOB_LOG_DIR" ]; then
        rm -rf "$BOB_LOG_DIR"
        print_info "Logs supprimés: $BOB_LOG_DIR"
    fi
    
    if [ "$REMOVE_DATA" = true ] && [ -d "$BOB_DATA_DIR" ]; then
        rm -rf "$BOB_DATA_DIR"
        print_info "Données supprimées: $BOB_DATA_DIR"
    elif [ -d "$BOB_DATA_DIR" ]; then
        print_warn "Données conservées dans: $BOB_DATA_DIR"
    fi
}

remove_user() {
    if id "$BOB_USER" &>/dev/null; then
        print_info "Suppression de l'utilisateur $BOB_USER..."
        # Note: Not using -r flag to preserve user home directory if it contains important data
        # Home directory was already cleaned in remove_directories if it's in BOB_HOME
        userdel "$BOB_USER" 2>/dev/null || true
        print_info "Utilisateur supprimé"
    else
        print_info "Utilisateur $BOB_USER n'existe pas"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  BOB Désinstallé avec Succès!"
    echo "=========================================="
    echo ""
    
    if [ "$REMOVE_DATA" != true ] && [ -d "$BOB_DATA_DIR" ]; then
        echo "Note: Les données ont été conservées dans: $BOB_DATA_DIR"
        echo "Pour les supprimer manuellement: sudo rm -rf $BOB_DATA_DIR"
        echo ""
    fi
    
    print_info "BOB a été complètement désinstallé"
}

# Main uninstallation flow
main() {
    print_info "Début de la désinstallation de BOB..."
    
    check_root
    confirm_uninstall "$1"
    stop_service
    remove_service
    remove_directories
    remove_user
    
    print_summary
}

# Run uninstallation
main "$@"
