#!/bin/bash
#
# BOB (Behaviour Observation Base) - Installation Script
# Script d'installation pour l'outil BOB IoT de capture de données de bio capteurs
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi
    print_info "Système d'exploitation détecté: $OS $OS_VERSION"
}

install_dependencies() {
    print_info "Installation des dépendances..."
    
    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                git \
                curl \
                build-essential \
                libssl-dev \
                libffi-dev \
                python3-dev \
                mosquitto \
                mosquitto-clients
            ;;
        centos|rhel)
            yum install -y \
                python3 \
                python3-pip \
                git \
                curl \
                gcc \
                openssl-devel \
                libffi-devel \
                python3-devel \
                mosquitto \
                mosquitto-clients
            ;;
        fedora)
            dnf install -y \
                python3 \
                python3-pip \
                git \
                curl \
                gcc \
                openssl-devel \
                libffi-devel \
                python3-devel \
                mosquitto \
                mosquitto-clients
            ;;
        *)
            print_warn "OS non supporté officiellement, tentative d'installation générique..."
            ;;
    esac
    
    print_info "Dépendances installées avec succès"
}

create_user() {
    if id "$BOB_USER" &>/dev/null; then
        print_info "L'utilisateur $BOB_USER existe déjà"
    else
        print_info "Création de l'utilisateur $BOB_USER..."
        useradd -r -s /bin/false -d "$BOB_HOME" "$BOB_USER"
    fi
}

create_directories() {
    print_info "Création des répertoires..."
    
    # Verify user exists before creating directories
    if ! id "$BOB_USER" &>/dev/null; then
        print_error "L'utilisateur $BOB_USER n'existe pas. Création du user requise d'abord."
        exit 1
    fi
    
    mkdir -p "$BOB_HOME"
    mkdir -p "$BOB_DATA_DIR"
    mkdir -p "$BOB_LOG_DIR"
    mkdir -p "$BOB_CONFIG_DIR"
    
    # Set proper permissions
    chown -R "$BOB_USER:$BOB_USER" "$BOB_HOME"
    chown -R "$BOB_USER:$BOB_USER" "$BOB_DATA_DIR"
    chown -R "$BOB_USER:$BOB_USER" "$BOB_LOG_DIR"
    chmod 755 "$BOB_HOME"
    chmod 750 "$BOB_CONFIG_DIR"
    
    print_info "Répertoires créés avec succès"
}

setup_python_environment() {
    print_info "Configuration de l'environnement Python..."
    
    cd "$BOB_HOME"
    sudo -u "$BOB_USER" python3 -m venv venv
    
    # Activate virtual environment and install packages
    sudo -u "$BOB_USER" "$BOB_HOME/venv/bin/pip" install --upgrade pip
    sudo -u "$BOB_USER" "$BOB_HOME/venv/bin/pip" install \
        paho-mqtt \
        pyserial \
        requests \
        numpy \
        pandas \
        influxdb-client
    
    print_info "Environnement Python configuré"
}

create_config() {
    print_info "Création de la configuration par défaut..."
    
    cat > "$BOB_CONFIG_DIR/bob.conf" <<EOF
# BOB Configuration File
# Configuration pour la capture de données de bio capteurs

[general]
data_dir = $BOB_DATA_DIR
log_dir = $BOB_LOG_DIR
log_level = INFO

[mqtt]
broker = localhost
port = 1883
topic_prefix = bob/sensors
keepalive = 60

[sensors]
scan_interval = 5
retry_attempts = 3
timeout = 10

[data]
format = json
retention_days = 30
compression = true
EOF
    
    chmod 640 "$BOB_CONFIG_DIR/bob.conf"
    chown root:"$BOB_USER" "$BOB_CONFIG_DIR/bob.conf"
    
    print_info "Configuration créée: $BOB_CONFIG_DIR/bob.conf"
}

create_systemd_service() {
    print_info "Création du service systemd..."
    
    cat > /etc/systemd/system/bob.service <<EOF
[Unit]
Description=BOB - Behaviour Observation Base
After=network.target mosquitto.service
Wants=mosquitto.service

[Service]
Type=simple
User=$BOB_USER
Group=$BOB_USER
WorkingDirectory=$BOB_HOME
Environment="BOB_CONFIG=$BOB_CONFIG_DIR/bob.conf"
ExecStart=$BOB_HOME/venv/bin/python $BOB_HOME/bob_capture.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    print_info "Service systemd créé"
}

create_sample_script() {
    print_info "Création du script de capture exemple..."
    
    cat > "$BOB_HOME/bob_capture.py" <<'EOF'
#!/usr/bin/env python3
"""
BOB - Behaviour Observation Base
Script de capture de données de bio capteurs
"""

import json
import time
import logging
import configparser
import os
from datetime import datetime
import paho.mqtt.client as mqtt

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('BOB')

class BiosensorCapture:
    """Classe principale pour la capture de données de bio capteurs"""
    
    def __init__(self, config_file='/etc/bob/bob.conf'):
        self.config = configparser.ConfigParser()
        self.config.read(config_file)
        
        self.mqtt_client = None
        self.running = False
        
    def setup_mqtt(self):
        """Configure la connexion MQTT"""
        broker = self.config.get('mqtt', 'broker', fallback='localhost')
        port = self.config.getint('mqtt', 'port', fallback=1883)
        
        self.mqtt_client = mqtt.Client()
        
        try:
            self.mqtt_client.connect(broker, port)
            self.mqtt_client.loop_start()
            logger.info(f"Connecté au broker MQTT: {broker}:{port}")
        except Exception as e:
            logger.error(f"Erreur de connexion MQTT: {e}")
            
    def read_sensor_data(self):
        """Simule la lecture de données de capteurs"""
        # TODO: Implémenter la lecture réelle des capteurs
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'sensor_id': 'biosensor_001',
            'temperature': 36.5 + (time.time() % 2),
            'heart_rate': 70 + int(time.time() % 20),
            'oxygen_level': 95 + int(time.time() % 5),
            'status': 'active'
        }
        
    def publish_data(self, data):
        """Publie les données sur MQTT"""
        if self.mqtt_client:
            topic_prefix = self.config.get('mqtt', 'topic_prefix', fallback='bob/sensors')
            topic = f"{topic_prefix}/{data['sensor_id']}"
            payload = json.dumps(data)
            
            self.mqtt_client.publish(topic, payload)
            logger.info(f"Données publiées: {topic}")
            
    def save_data(self, data):
        """Sauvegarde les données localement"""
        data_dir = self.config.get('general', 'data_dir', fallback='/var/lib/bob')
        date_str = datetime.utcnow().strftime('%Y-%m-%d')
        filename = os.path.join(data_dir, f'sensors_{date_str}.json')
        
        try:
            with open(filename, 'a') as f:
                f.write(json.dumps(data) + '\n')
        except Exception as e:
            logger.error(f"Erreur de sauvegarde: {e}")
            
    def run(self):
        """Boucle principale de capture"""
        self.running = True
        self.setup_mqtt()
        
        scan_interval = self.config.getint('sensors', 'scan_interval', fallback=5)
        
        logger.info("Démarrage de la capture de données...")
        
        try:
            while self.running:
                data = self.read_sensor_data()
                self.publish_data(data)
                self.save_data(data)
                time.sleep(scan_interval)
        except KeyboardInterrupt:
            logger.info("Arrêt demandé par l'utilisateur")
        finally:
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            logger.info("Capture arrêtée")

if __name__ == '__main__':
    capture = BiosensorCapture()
    capture.run()
EOF
    
    chown "$BOB_USER:$BOB_USER" "$BOB_HOME/bob_capture.py"
    chmod 755 "$BOB_HOME/bob_capture.py"
    
    print_info "Script de capture créé"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  BOB Installation Terminée avec Succès!"
    echo "=========================================="
    echo ""
    echo "Répertoires:"
    echo "  - Installation: $BOB_HOME"
    echo "  - Configuration: $BOB_CONFIG_DIR"
    echo "  - Données: $BOB_DATA_DIR"
    echo "  - Logs: $BOB_LOG_DIR"
    echo ""
    echo "Commandes utiles:"
    echo "  - Démarrer BOB:    systemctl start bob"
    echo "  - Arrêter BOB:     systemctl stop bob"
    echo "  - Statut BOB:      systemctl status bob"
    echo "  - Activer démarrage auto: systemctl enable bob"
    echo "  - Voir les logs:   journalctl -u bob -f"
    echo ""
    echo "Configuration: $BOB_CONFIG_DIR/bob.conf"
    echo ""
    echo "Note: Modifiez la configuration selon vos besoins avant de démarrer le service"
    echo ""
}

# Main installation flow
main() {
    print_info "Début de l'installation de BOB..."
    
    check_root
    detect_os
    install_dependencies
    create_user
    create_directories
    setup_python_environment
    create_config
    create_sample_script
    create_systemd_service
    
    print_summary
}

# Run installation
main "$@"
