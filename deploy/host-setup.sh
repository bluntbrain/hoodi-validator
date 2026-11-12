#!/usr/bin/env bash
# Prepare a fresh Ubuntu 24.04 host for the stack. Run once as a sudo-capable user.
# Does: Docker CE, chrony, ufw with only SSH + p2p ports, a few sysctl tweaks, unattended upgrades.
# Does not: create users, change SSH config. Do those by hand first (key-only auth, no root login).
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then echo "run as a normal user with sudo, not root"; exit 1; fi

echo "== packages"
sudo apt-get update -q
sudo apt-get install -y -q ca-certificates curl gnupg ufw chrony unattended-upgrades openssl rsync

echo "== docker ce"
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -q
  sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker "$USER"
  echo "added $USER to the docker group; log out and in again before 'make up'"
fi

echo "== time sync (attestations are slot-timed; drift costs rewards)"
sudo systemctl enable --now chrony
chronyc tracking | head -3 || true

echo "== firewall: ssh + p2p only. Grafana stays on localhost."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 30303/tcp comment 'reth p2p'
sudo ufw allow 30303/udp comment 'reth discovery'
sudo ufw allow 9000/tcp  comment 'lighthouse p2p'
sudo ufw allow 9000/udp  comment 'lighthouse discovery'
sudo ufw allow 9001/udp  comment 'lighthouse quic'
sudo ufw --force enable
sudo ufw status numbered

echo "== sysctl: more sockets and file handles for p2p"
sudo tee /etc/sysctl.d/90-ethereum-node.conf >/dev/null <<'EOF'
fs.file-max = 1048576
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_max_syn_backlog = 4096
vm.swappiness = 10
EOF
sudo sysctl --system >/dev/null

echo "== unattended security upgrades (kernel reboots still manual)"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "host ready. next: clone the repo, 'make init', 'make up'."
