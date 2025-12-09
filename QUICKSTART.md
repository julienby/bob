# Guide de Démarrage Rapide BOB

## Installation en 3 Étapes

### 1. Télécharger et Installer

```bash
# Cloner le dépôt
git clone https://github.com/julienby/bob.git
cd bob

# Lancer l'installation
sudo ./install.sh
```

### 2. Configurer (Optionnel)

```bash
# Éditer la configuration si nécessaire
sudo nano /etc/bob/bob.conf
```

### 3. Démarrer

```bash
# Démarrer le service
sudo systemctl start bob

# Activer au démarrage
sudo systemctl enable bob

# Vérifier le statut
sudo systemctl status bob
```

## Vérifier que Tout Fonctionne

### 1. Vérifier les logs

```bash
sudo journalctl -u bob -f
```

Vous devriez voir des messages indiquant que la capture est en cours.

### 2. Vérifier les données MQTT

```bash
# S'abonner aux topics MQTT
mosquitto_sub -t "bob/sensors/#" -v
```

### 3. Vérifier les fichiers de données

```bash
# Voir les dernières données capturées
sudo tail -f /var/lib/bob/sensors_$(date +%Y-%m-%d).json
```

## Exemple de Sortie

Données capturées (format JSON):
```json
{"timestamp": "2025-12-09T13:21:37.123456", "sensor_id": "biosensor_001", "temperature": 36.5, "heart_rate": 75, "oxygen_level": 98, "status": "active"}
```

## Commandes Utiles

```bash
# Démarrer BOB
sudo systemctl start bob

# Arrêter BOB
sudo systemctl stop bob

# Redémarrer BOB
sudo systemctl restart bob

# Statut de BOB
sudo systemctl status bob

# Logs en temps réel
sudo journalctl -u bob -f

# Recharger la configuration
sudo systemctl restart bob
```

## Personnalisation Rapide

Pour adapter à vos capteurs, modifiez:
```bash
sudo nano /opt/bob/bob_capture.py
```

Recherchez la fonction `read_sensor_data()` et implémentez votre logique de lecture de capteurs.

## Intégration Simple

### Avec Node-RED

1. Installer Node-RED
2. Ajouter un nœud MQTT Input
3. Configurer le serveur MQTT: `localhost:1883`
4. Topic: `bob/sensors/#`

### Avec InfluxDB

Modifier le script pour écrire directement dans InfluxDB (bibliothèque déjà installée):

```python
from influxdb_client import InfluxDBClient

client = InfluxDBClient(url="http://localhost:8086", token="your-token", org="your-org")
# Écrire vos données...
```

## Problèmes Courants

### "Permission denied"
Solution: Exécutez avec `sudo`

### "mosquitto: command not found"
Solution: Réexécutez l'installation ou installez manuellement:
```bash
sudo apt-get install mosquitto mosquitto-clients
```

### Les données ne s'affichent pas
Solution: Vérifiez que le service est démarré et consultez les logs:
```bash
sudo systemctl status bob
sudo journalctl -u bob -n 50
```

## Prochaines Étapes

1. **Configurer vos capteurs réels** dans `/opt/bob/bob_capture.py`
2. **Sécuriser MQTT** avec authentification et TLS
3. **Intégrer avec votre dashboard** préféré (Grafana, Home Assistant, etc.)
4. **Configurer la rétention des données** selon vos besoins
5. **Ajouter des alertes** basées sur les valeurs des capteurs

## Support

Consultez le README.md complet pour plus de détails et d'options avancées.
