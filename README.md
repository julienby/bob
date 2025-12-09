# BOB - Behaviour Observation Base

BOB (Behaviour Observation Base) est un outil IoT pour la capture et la gestion de données provenant de bio capteurs.

## Description

BOB permet de:
- Capturer des données en temps réel depuis des bio capteurs
- Publier les données via MQTT pour une intégration facile
- Sauvegarder les données localement pour archivage
- Gérer plusieurs capteurs simultanément
- Fonctionner comme service système pour une disponibilité continue

## Prérequis

- Système Linux (Ubuntu/Debian, CentOS/RHEL, Fedora)
- Droits administrateur (root)
- Connexion Internet pour l'installation des dépendances

## Installation

### Installation Rapide

Pour installer BOB avec la configuration par défaut:

```bash
sudo ./install.sh
```

### Installation Personnalisée

Vous pouvez personnaliser l'installation en définissant des variables d'environnement:

```bash
# Personnaliser les répertoires
export BOB_HOME=/opt/bob
export BOB_DATA_DIR=/var/lib/bob
export BOB_LOG_DIR=/var/log/bob
export BOB_CONFIG_DIR=/etc/bob
export BOB_USER=bob

# Lancer l'installation
sudo -E ./install.sh
```

### Composants Installés

L'installation configure automatiquement:
- **Python 3** avec environnement virtuel
- **Bibliothèques Python**: paho-mqtt, pyserial, requests, numpy, pandas, influxdb-client
- **Mosquitto**: Broker MQTT pour la communication
- **Service systemd**: Pour exécuter BOB en arrière-plan
- **Configuration**: Fichier de configuration dans `/etc/bob/bob.conf`
- **Script de capture**: Script Python exemple pour la capture de données

## Configuration

Après l'installation, éditez le fichier de configuration:

```bash
sudo nano /etc/bob/bob.conf
```

### Paramètres Principaux

```ini
[general]
data_dir = /var/lib/bob      # Répertoire des données
log_dir = /var/log/bob        # Répertoire des logs
log_level = INFO              # Niveau de log (DEBUG, INFO, WARNING, ERROR)

[mqtt]
broker = localhost            # Adresse du broker MQTT
port = 1883                   # Port MQTT
topic_prefix = bob/sensors    # Préfixe des topics MQTT
keepalive = 60               # Intervalle keepalive MQTT

[sensors]
scan_interval = 5            # Intervalle de scan en secondes
retry_attempts = 3           # Nombre de tentatives en cas d'erreur
timeout = 10                 # Timeout en secondes

[data]
format = json                # Format des données (json)
retention_days = 30          # Jours de rétention des données
compression = true           # Compression des données
```

## Utilisation

### Démarrer le Service

```bash
# Démarrer BOB
sudo systemctl start bob

# Activer le démarrage automatique
sudo systemctl enable bob

# Vérifier le statut
sudo systemctl status bob
```

### Arrêter le Service

```bash
sudo systemctl stop bob
```

### Consulter les Logs

```bash
# Logs en temps réel
sudo journalctl -u bob -f

# Derniers logs
sudo journalctl -u bob -n 100
```

### Données Capturées

Les données sont sauvegardées dans `/var/lib/bob/` au format JSON avec un fichier par jour:
- Format: `sensors_YYYY-MM-DD.json`
- Chaque ligne contient un objet JSON avec les données d'un capteur

### Topics MQTT

Les données sont publiées sur MQTT avec la structure:
```
bob/sensors/{sensor_id}
```

Exemple de payload:
```json
{
  "timestamp": "2025-12-09T13:21:37.123456",
  "sensor_id": "biosensor_001",
  "temperature": 36.5,
  "heart_rate": 75,
  "oxygen_level": 98,
  "status": "active"
}
```

## Personnalisation

### Ajouter vos Propres Capteurs

Modifiez le fichier `/opt/bob/bob_capture.py` pour adapter la fonction `read_sensor_data()` à vos capteurs spécifiques:

```python
def read_sensor_data(self):
    # Implémentez ici la lecture de vos capteurs
    # Exemple avec un capteur série
    import serial
    ser = serial.Serial('/dev/ttyUSB0', 9600)
    data = ser.readline()
    return parse_sensor_data(data)
```

### Intégration avec d'Autres Systèmes

Les données publiées sur MQTT peuvent être consommées par:
- Home Assistant
- Node-RED
- InfluxDB + Grafana
- Applications personnalisées

## Dépannage

### Le service ne démarre pas

Vérifiez les logs:
```bash
sudo journalctl -u bob -n 50
```

Vérifiez les permissions:
```bash
ls -la /opt/bob
ls -la /var/lib/bob
```

### Mosquitto n'est pas accessible

Vérifiez le service Mosquitto:
```bash
sudo systemctl status mosquitto
sudo systemctl start mosquitto
```

### Problèmes de permissions

Réinitialisez les permissions:
```bash
sudo chown -R bob:bob /opt/bob
sudo chown -R bob:bob /var/lib/bob
sudo chown -R bob:bob /var/log/bob
```

## Architecture

```
BOB
├── /opt/bob/                  # Installation principale
│   ├── venv/                 # Environnement Python virtuel
│   └── bob_capture.py        # Script de capture
├── /etc/bob/                 # Configuration
│   └── bob.conf              # Fichier de configuration
├── /var/lib/bob/             # Données capturées
│   └── sensors_*.json        # Fichiers de données
└── /var/log/bob/             # Logs (via journald)
```

## Sécurité

- Le service s'exécute avec un utilisateur dédié non-privilégié (`bob`)
- Les fichiers de configuration ont des permissions restreintes
- Les données sont sauvegardées avec des permissions appropriées
- MQTT peut être configuré avec authentification et TLS

## Support

Pour toute question ou problème:
1. Consultez les logs: `sudo journalctl -u bob -f`
2. Vérifiez la configuration: `/etc/bob/bob.conf`
3. Testez manuellement: `sudo -u bob /opt/bob/venv/bin/python /opt/bob/bob_capture.py`

## Licence

Ce projet est un outil de base pour la capture de données de bio capteurs IoT.
