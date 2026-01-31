# Hotspot setup (automated)

This repository now includes an automated hotspot configuration as part of `setup.sh` and is tested for Raspberry Pi OS on Pi 5.

Usage
- Run the consolidated setup script and follow prompts:

  sudo ./setup.sh

  The script will:
  - Install required packages (`hostapd`, `dnsmasq`, `iptables-persistent`, etc.)
  - Prompt for hotspot SSID and passphrase, interface (default `wlan0`), IP range
  - Backup `/etc/dhcpcd.conf`, `/etc/dnsmasq.conf`, `/etc/hostapd/hostapd.conf`, and `/etc/default/hostapd` before making changes
  - Configure a static IP for the hotspot, set up `dnsmasq` DHCP settings, write `hostapd` config, and enable IP forwarding
  - Optionally set up NAT to share internet from another interface (e.g., `eth0`)

Rollback
- To remove the hotspot and restore backups run:

  sudo ./setup.sh hotspot-teardown

Notes & Safety
- The script makes backups of the modified files with a `.marsrover.bak.TIMESTAMP` suffix. Review backups before removing them.
- Some changes (interface enable, camera, serial) may require a reboot to take effect.
- For advanced networks or when your Pi will be connected to other networks, review the generated files in `/etc` before rebooting.

