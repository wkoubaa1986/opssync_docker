#!/bin/bash

echo "=== Configuration du mode serveur en cours... ==="

# 1. Empêcher la mise en veille et l'extinction d'écran
echo "[1/5] Désactivation de la mise en veille..."
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false

# 2. Charger le module watchdog logiciel
echo "[2/5] Chargement du module watchdog logiciel..."
sudo modprobe softdog
if ! grep -q "softdog" /etc/modules; then
    echo "softdog" | sudo tee -a /etc/modules
fi

# 3. Installer le package watchdog
echo "[3/5] Installation du service watchdog..."
sudo apt update && sudo apt install -y watchdog

# 4. Configurer watchdog.conf
echo "[4/5] Configuration de /etc/watchdog.conf..."
sudo cp /etc/watchdog.conf /etc/watchdog.conf.backup.$(date +%F-%H-%M)
sudo sed -i 's|#watchdog-device.*|watchdog-device = /dev/watchdog|' /etc/watchdog.conf
sudo sed -i 's|#max-load-1.*|max-load-1 = 24|' /etc/watchdog.conf
sudo sed -i 's|#ping =.*|ping = 8.8.8.8|' /etc/watchdog.conf
sudo sed -i 's|#interval =.*|interval = 10|' /etc/watchdog.conf
sudo sed -i 's|#logtick =.*|logtick = 60|' /etc/watchdog.conf
sudo sed -i 's|#realtime =.*|realtime = yes|' /etc/watchdog.conf
sudo sed -i 's|#priority =.*|priority = 1|' /etc/watchdog.conf

# 5. Activer le service watchdog
echo "[5/5] Activation et démarrage de watchdog..."
sudo systemctl enable watchdog
sudo systemctl restart watchdog

# 6. Configurer systemd pour ignorer les actions sur le bouton power
echo "Configuration de /etc/systemd/logind.conf..."
sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.backup.$(date +%F-%H-%M)
sudo sed -i 's|^#HandlePowerKey=.*|HandlePowerKey=ignore|' /etc/systemd/logind.conf
sudo sed -i 's|^#HandleLidSwitch=.*|HandleLidSwitch=ignore|' /etc/systemd/logind.conf
sudo sed -i 's|^#HandleLidSwitchDocked=.*|HandleLidSwitchDocked=ignore|' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

echo "✅ Configuration terminée. Ton serveur est prêt à rester allumé 24/7."
