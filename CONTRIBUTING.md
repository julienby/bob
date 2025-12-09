# Guide de Contribution à BOB

Merci de votre intérêt pour contribuer au projet BOB (Behaviour Observation Base) !

## Comment Contribuer

### Rapporter des Bugs

Si vous trouvez un bug, veuillez ouvrir une issue avec:
- Une description claire du problème
- Les étapes pour reproduire le bug
- Votre environnement (OS, version, etc.)
- Les logs pertinents

### Proposer des Améliorations

Pour proposer de nouvelles fonctionnalités:
1. Ouvrez une issue pour discuter de votre idée
2. Attendez les retours avant de commencer le développement
3. Soumettez une Pull Request avec votre implémentation

### Ajouter le Support de Nouveaux Capteurs

Pour ajouter le support d'un nouveau type de capteur:

1. **Modifiez le script de capture** `/opt/bob/bob_capture.py`:

```python
def read_sensor_data(self):
    """Lecture de données de votre capteur"""
    # Votre code ici
    # Exemple pour un capteur I2C
    import smbus
    bus = smbus.SMBus(1)
    data = bus.read_i2c_block_data(0x48, 0x00, 2)
    
    return {
        'timestamp': datetime.utcnow().isoformat(),
        'sensor_id': 'your_sensor_001',
        'value': process_data(data),
        'status': 'active'
    }
```

2. **Ajoutez les dépendances nécessaires** dans `install.sh`:

```bash
sudo -u "$BOB_USER" "$BOB_HOME/venv/bin/pip" install \
    your-sensor-library
```

3. **Documentez votre capteur** dans le README.md

### Structure du Code

```
bob/
├── install.sh          # Script d'installation principal
├── uninstall.sh        # Script de désinstallation
├── README.md           # Documentation complète
├── QUICKSTART.md       # Guide de démarrage rapide
└── CONTRIBUTING.md     # Ce fichier
```

### Conventions de Code

#### Scripts Bash

- Utilisez `set -e` pour arrêter en cas d'erreur
- Validez toujours les entrées utilisateur
- Quotez les variables: `"$VARIABLE"`
- Ajoutez des commentaires pour les sections complexes
- Utilisez des fonctions pour la réutilisabilité
- Retournez des messages d'erreur clairs

Exemple:
```bash
function_name() {
    if [ condition ]; then
        print_error "Message d'erreur clair"
        exit 1
    fi
    # Code...
}
```

#### Python

- Suivez PEP 8 pour le style
- Documentez les fonctions avec des docstrings
- Gérez les exceptions proprement
- Utilisez des logs plutôt que des prints
- Testez votre code avant de soumettre

Exemple:
```python
def capture_data(self):
    """
    Capture les données du capteur
    
    Returns:
        dict: Données du capteur au format JSON
    """
    try:
        # Code de capture
        return data
    except Exception as e:
        logger.error(f"Erreur de capture: {e}")
        raise
```

### Configuration

Toute nouvelle option de configuration doit:
- Être ajoutée au fichier `/etc/bob/bob.conf`
- Avoir une valeur par défaut raisonnable
- Être documentée dans le README.md
- Être rétrocompatible si possible

### Tests

Avant de soumettre:
1. Testez l'installation sur une machine propre
2. Vérifiez que le service démarre correctement
3. Testez la désinstallation
4. Validez que les données sont capturées comme prévu
5. Vérifiez les logs pour les erreurs

### Processus de Pull Request

1. **Fork** le projet
2. **Créez une branche** pour votre fonctionnalité:
   ```bash
   git checkout -b feature/ma-nouvelle-fonctionnalite
   ```
3. **Committez** vos changements:
   ```bash
   git commit -m "Ajout: description de la fonctionnalité"
   ```
4. **Poussez** vers votre fork:
   ```bash
   git push origin feature/ma-nouvelle-fonctionnalite
   ```
5. **Ouvrez une Pull Request** avec:
   - Une description claire des changements
   - Les raisons de ces changements
   - Les tests effectués
   - Les captures d'écran si applicable

### Standards de Documentation

- Écrivez en français pour la cohérence du projet
- Utilisez des exemples concrets
- Incluez des commandes complètes et testées
- Ajoutez des sections de dépannage si nécessaire

### Sécurité

Si vous trouvez une vulnérabilité de sécurité:
- **NE PAS** ouvrir une issue publique
- Contactez les mainteneurs directement
- Attendez un correctif avant de divulguer

### Améliorations Prioritaires

Contributions particulièrement bienvenues pour:
- Support de nouveaux types de capteurs
- Intégrations avec d'autres plateformes IoT
- Amélioration de la documentation
- Optimisation des performances
- Support de nouvelles distributions Linux
- Tests automatisés
- Tableaux de bord et visualisations

### Questions ?

Si vous avez des questions:
1. Consultez d'abord le README.md et QUICKSTART.md
2. Recherchez dans les issues existantes
3. Ouvrez une nouvelle issue avec le tag "question"

## Code de Conduite

- Soyez respectueux et professionnel
- Acceptez les critiques constructives
- Concentrez-vous sur ce qui est le mieux pour le projet
- Aidez les nouveaux contributeurs

Merci de contribuer à BOB ! 🚀
