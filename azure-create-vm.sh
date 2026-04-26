#!/usr/bin/env bash
# =============================================================================
# Artemis AI - Criacao da VM Azure (exemplo)
# =============================================================================
# Cria uma VM Ubuntu 24.04 no Azure preparada para rodar Artemis AI.
# Pre-requisitos:
#   - Azure CLI instalado e autenticado (az login)
#   - Subscription correta selecionada (az account set --subscription <ID>)
# =============================================================================
# Para outras clouds, use este como referencia para adaptar (AWS, GCP, etc).
# =============================================================================

set -euo pipefail

# -------- VARIAVEIS (ajuste conforme necessario) --------
RG="${RG:-rg-artemis-ai}"
LOCATION="${LOCATION:-brazilsouth}"
VM_NAME="${VM_NAME:-vm-artemis-ai}"
VM_SIZE="${VM_SIZE:-Standard_D4s_v5}"
ADMIN_USER="${ADMIN_USER:-azureuser}"
DNS_LABEL="${DNS_LABEL:-artemis-ai-CHANGE_ME}"   # globalmente unico no Azure
DISK_SIZE_GB="${DISK_SIZE_GB:-64}"
NSG_NAME="${VM_NAME}NSG"

# -------- CORES --------
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
log()  { echo -e "${G}[+]${N} $1"; }
warn() { echo -e "${Y}[!]${N} $1"; }
err()  { echo -e "${R}[x]${N} $1"; }

# -------- VALIDACAO --------
command -v az >/dev/null 2>&1 || { err "Azure CLI nao encontrado. Instale: https://aka.ms/azcli"; exit 1; }
az account show >/dev/null 2>&1 || { err "Faca login: az login"; exit 1; }

log "Subscription ativa: $(az account show --query name -o tsv)"
log "Resource Group:    ${RG}"
log "Localizacao:       ${LOCATION}"
log "VM:                ${VM_NAME} (${VM_SIZE})"
log "Usuario admin:     ${ADMIN_USER}"
log "FQDN previsto:     ${DNS_LABEL}.${LOCATION}.cloudapp.azure.com"
echo
read -rp "Prosseguir? [s/N] " confirma
[[ "${confirma,,}" == "s" ]] || { warn "Cancelado."; exit 0; }

# -------- 1. RESOURCE GROUP --------
log "Criando resource group..."
az group create -n "$RG" -l "$LOCATION" -o none

# -------- 2. VM --------
log "Criando VM (pode levar 2-3 minutos)..."
az vm create \
  -g "$RG" -n "$VM_NAME" \
  --image Ubuntu2404 \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USER" \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --public-ip-address-dns-name "$DNS_LABEL" \
  --os-disk-size-gb "$DISK_SIZE_GB" \
  --storage-sku Premium_LRS \
  --nsg-rule NONE \
  -o none

# -------- 3. NSG: REGRAS --------
MEU_IP=$(curl -4 -s ifconfig.me)
log "Seu IP detectado: ${MEU_IP}"

log "Criando regras NSG..."

# SSH so do seu IP
az network nsg rule create \
  -g "$RG" --nsg-name "$NSG_NAME" \
  -n allow-ssh --priority 100 \
  --source-address-prefixes "${MEU_IP}/32" \
  --destination-port-ranges 22 \
  --protocol Tcp --access Allow \
  -o none

# HTTP (Let's Encrypt)
az network nsg rule create \
  -g "$RG" --nsg-name "$NSG_NAME" \
  -n allow-http --priority 110 \
  --destination-port-ranges 80 \
  --protocol Tcp --access Allow \
  -o none

# HTTPS (Neko web)
az network nsg rule create \
  -g "$RG" --nsg-name "$NSG_NAME" \
  -n allow-https --priority 120 \
  --destination-port-ranges 443 \
  --protocol Tcp --access Allow \
  -o none

# WebRTC UDP (4 perfis x 100 portas = 59000-59400)
az network nsg rule create \
  -g "$RG" --nsg-name "$NSG_NAME" \
  -n allow-webrtc --priority 130 \
  --destination-port-ranges 59000-59400 \
  --protocol Udp --access Allow \
  -o none

# -------- 4. RESULTADO --------
FQDN=$(az vm show -d -g "$RG" -n "$VM_NAME" --query fqdns -o tsv)
PUBLIC_IP=$(az vm show -d -g "$RG" -n "$VM_NAME" --query publicIps -o tsv)

echo
log "========================================================"
log "VM CRIADA COM SUCESSO"
log "========================================================"
echo -e "  ${Y}IP Publico:${N}  ${PUBLIC_IP}"
echo -e "  ${Y}FQDN Azure:${N}  ${FQDN}"
echo -e "  ${Y}SSH:${N}         ssh ${ADMIN_USER}@${PUBLIC_IP}"
echo
log "PROXIMOS PASSOS:"
echo "  1. Aponte os DNS do seu dominio para: ${FQDN} (CNAME) ou ${PUBLIC_IP} (A)"
echo "       profile1.<seu-dominio>"
echo "       profile2.<seu-dominio>"
echo "       profile3.<seu-dominio>"
echo "       profile4.<seu-dominio>"
echo "       traefik.<seu-dominio>"
echo
echo "  2. Edite o arquivo .env (copie de .env.example primeiro):"
echo "       PUBLIC_IP=${PUBLIC_IP}"
echo
echo "  3. Copie os arquivos para a VM:"
echo "       scp -r ./* ${ADMIN_USER}@${PUBLIC_IP}:~/artemis-ai/"
echo
echo "  4. Conecte e execute o bootstrap:"
echo "       ssh ${ADMIN_USER}@${PUBLIC_IP}"
echo "       cd ~/artemis-ai && bash bootstrap-vm.sh"
echo
warn "Para DESLIGAR a VM e parar de pagar compute (mantem disco):"
echo "       az vm deallocate -g ${RG} -n ${VM_NAME}"
warn "Para LIGAR de novo:"
echo "       az vm start -g ${RG} -n ${VM_NAME}"
warn "Para DESTRUIR tudo:"
echo "       az group delete -n ${RG} --yes"
