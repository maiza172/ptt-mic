#!/bin/sh
# Install ptt-mic for the current user. The udev rule is printed, not applied:
# it has to be written under /etc by root.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}

install -D -m 755 "$root/ptt-mic" "$HOME/.local/bin/ptt-mic"
mkdir -p "$config_home/ptt-mic"
if [ ! -f "$config_home/ptt-mic/config" ]; then
    cp "$root/config.example" "$config_home/ptt-mic/config"
    echo "Wrote $config_home/ptt-mic/config"
    echo "Edit device_name and button, then start the service."
else
    echo "Left existing $config_home/ptt-mic/config in place"
fi
install -D -m 644 "$root/systemd/user/ptt-mic.service" "$config_home/systemd/user/ptt-mic.service"

cat <<EOF

User files are installed. As root, install the seat rule and reload udev:

  sudo install -m 644 $root/udev/65-ptt-mic.rules /etc/udev/rules.d/65-ptt-mic.rules
  sudo udevadm control --reload-rules

Then start one instance:

  systemctl --user daemon-reload
  systemctl --user enable --now ptt-mic.service

Check: journalctl --user -u ptt-mic.service -e
EOF
