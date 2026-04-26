#!/usr/bin/env bash
# =============================================================================
# Artemis AI - Bootstrap da VM Ubuntu 24.04
# =============================================================================
# Instala Docker, Docker Compose, configura firewall e prepara estrutura.
# Rodar DENTRO da VM apos o primeiro SSH.
# =============================================================================

set -euo pipefail

G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
log()  { echo -e "${G}[+]${N} $1"; }
warn() { echo -e "${Y}[!]${N} $1"; }
err()  { echo -e "${R}[x]${N} $1"; }

# -------- 1. SISTEMA --------
log "Atualizando sistema..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

log "Instalando dependencias..."
sudo apt-get install -y -qq \
  ca-certificates curl gnupg lsb-release \
  ufw fail2ban htop tmux unattended-upgrades

# -------- 2. DOCKER OFICIAL --------
if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker oficial..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  log "Docker instalado: $(docker --version)"
else
  log "Docker ja instalado: $(docker --version)"
fi

# -------- 3. FIREWALL UFW (defesa em profundidade) --------
log "Configurando UFW..."
sudo ufw --force reset >/dev/null
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP - Lets Encrypt'
sudo ufw allow 443/tcp comment 'HTTPS - Neko web'
sudo ufw allow 59000:59400/udp comment 'WebRTC EPR'
sudo ufw --force enable

# -------- 4. FAIL2BAN --------
log "Habilitando fail2ban..."
sudo systemctl enable --now fail2ban

# -------- 5. ATUALIZACOES AUTOMATICAS --------
log "Habilitando unattended-upgrades..."
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# -------- 6. KERNEL TUNING (WebRTC se beneficia de UDP buffers maiores) --------
log "Ajustando buffers UDP..."
sudo tee /etc/sysctl.d/99-artemis.conf > /dev/null <<'EOF'
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=1048576
net.core.wmem_default=1048576
EOF
sudo sysctl -p /etc/sysctl.d/99-artemis.conf >/dev/null

# -------- 7. ESTRUTURA DE DIRETORIOS --------
log "Criando estrutura..."
mkdir -p ~/artemis-ai/{data/profile1,data/profile2,data/profile3,data/profile4,certs}
mkdir -p ~/artemis-ai/data/{profile1,profile2,profile3,profile4}/Downloads
sudo chown -R 1000:1000 ~/artemis-ai/data/
touch ~/artemis-ai/certs/acme.json
chmod 600 ~/artemis-ai/certs/acme.json

# -------- 8. CHECAGEM FINAL --------
echo
log "========================================================"
log "BOOTSTRAP CONCLUIDO"
log "========================================================"
echo -e "  ${Y}Docker:${N}        $(docker --version)"
echo -e "  ${Y}Compose:${N}       $(docker compose version --short)"
echo -e "  ${Y}IP Publico:${N}    $(curl -s ifconfig.me)"
echo
warn "IMPORTANTE: faca LOGOUT e LOGIN de novo (ou 'newgrp docker')"
warn "para o seu usuario entrar no grupo docker."
echo
log "Proximo passo:"
echo "  1. Edite ~/artemis-ai/.env (copie de .env.example primeiro)"
echo "  2. cd ~/artemis-ai && docker compose up -d"
echo "  3. docker compose logs -f traefik"
