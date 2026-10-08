#!/usr/bin/env bash
set -e
systemctl enable NetworkManager.service
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
