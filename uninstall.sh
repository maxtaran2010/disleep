#!/bin/bash
set -e
echo "Removing Disleep sudoers rule and restoring normal sleep (admin password required)…"
sudo rm -f /etc/sudoers.d/disleep
sudo pmset -a disablesleep 0
echo "Done. Quit the app and delete build/Disleep.app to remove it completely."
