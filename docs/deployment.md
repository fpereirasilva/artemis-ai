# Deployment

> Guia passo-a-passo para subir o Artemis AI do zero, com qualquer cloud provider e qualquer DNS.

---

## Pré-requisitos

### Na sua máquina local

- **Sistema operacional:** Linux, macOS, ou Windows com Git Bash/WSL
- **Cloud CLI** autenticada (Azure CLI, AWS CLI, GCP gcloud — qualquer uma)
- **SSH client** (`ssh`, `scp`)
- **Editor de texto** para o `.env`

### Na cloud

- Permissão para criar VM Linux, Resource Group/VPC, Network Security Group
- Quota suficiente para a SKU escolhida (4 vCPU mínimo)

### No DNS

- Domínio próprio com acesso a criar registros A ou CNAME
- Possibilidade de criar wildcard ou múltiplos subdomínios

---

## Passo 1 — Criar a VM

### Sizing recomendado

| Cenário | vCPU | RAM | Disco | Exemplo Azure |
|---|---|---|---|---|
| Dev/teste 1-2 perfis ativos simultâneos | 2 | 8 GB | 32 GB | `Standard_D2s_v5` |
| POC com até 4 perfis em uso paralelo | 4 | 16 GB | 64 GB | `Standard_D4s_v5` |
| Carga média 8 perfis simultâneos | 8 | 32 GB | 128 GB | `Standard_D8s_v5` |

> Cada Neko sob uso ativo consome ~1.5 vCPU. Em idle consome muito pouco.

### Azure (script incluído)

```bash
# Login e configuração
az login
az account set --subscription "<sua-subscription>"

# Editar variáveis se quiser (opcional)
nano azure-create-vm.sh

# Executar
chmod +x azure-create-vm.sh
./azure-create-vm.sh
```

O script cria:
- Resource Group
- VM Ubuntu 24.04 LTS
- IP público estático
- NSG com regras: SSH (apenas seu IP), HTTP/HTTPS, UDP 59000-59400

Anote o **IP público** e **FQDN** retornados.

### Outras clouds (manual)

A criação é equivalente em qualquer cloud — apenas adapte a CLI:

**AWS:**
```bash
aws ec2 run-instances \
  --image-id ami-<ubuntu-24.04> \
  --instance-type t3.xlarge \
  --key-name minha-chave \
  --security-group-ids sg-<grupo>
# Configure o SG para liberar 22/80/443/UDP 59000-59400
```

**GCP:**
```bash
gcloud compute instances create artemis-vm \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --tags=http-server,https-server
# Configure firewall rules para UDP 59000-59400
```

**DigitalOcean / Hetzner / OVH:** mesmo princípio. Suba VM Ubuntu, libere portas, anote IP.

---

## Passo 2 — Configurar DNS

Você precisa de **5 registros** apontando para o IP/FQDN da VM:

| Nome | Tipo | Valor |
|---|---|---|
| `<perfil1>.<seu-dominio>` | A ou CNAME | IP da VM ou FQDN |
| `<perfil2>.<seu-dominio>` | A ou CNAME | IP da VM ou FQDN |
| `<perfil3>.<seu-dominio>` | A ou CNAME | IP da VM ou FQDN |
| `<perfil4>.<seu-dominio>` | A ou CNAME | IP da VM ou FQDN |
| `traefik.<seu-dominio>` | A ou CNAME | IP da VM ou FQDN |

Ou, mais simples, **um wildcard**:

```
*.<seu-dominio>    A ou CNAME    IP da VM ou FQDN
```

### ⚠️ Cloudflare proxy (laranja) NÃO

Se você usa Cloudflare, **deixe os subdomínios desta POC com nuvem cinza (DNS only)**. Veja [troubleshooting.md](troubleshooting.md#cloudflare-proxy-quebra-tudo) para o motivo.

### Verificação

Após criar os registros, espere ~5 minutos e verifique:

```bash
dig +short fabio.<seu-dominio>
# deve retornar o IP da VM
```

Não passe para o próximo passo sem confirmar a propagação.

---

## Passo 3 — Copiar os arquivos para a VM

```bash
# A partir da pasta do projeto
ADMIN_USER=ubuntu  # ou o usuário admin que você criou
VM_IP=<IP_da_VM>

ssh ${ADMIN_USER}@${VM_IP} 'mkdir -p ~/artemis-ai'
scp -r ./* ${ADMIN_USER}@${VM_IP}:~/artemis-ai/
```

---

## Passo 4 — Bootstrap da VM

```bash
ssh ${ADMIN_USER}@${VM_IP}
cd ~/artemis-ai
chmod +x bootstrap-vm.sh
bash bootstrap-vm.sh
```

O script:
- Atualiza pacotes (`apt upgrade`)
- Instala Docker oficial + Compose
- Configura UFW (firewall do host)
- Habilita fail2ban
- Habilita unattended-upgrades para patches automáticos de segurança
- Ajusta buffers UDP no kernel (otimização WebRTC)
- Cria estrutura `data/` e `certs/`

**Importante:** após o bootstrap, faça **logout e login** para entrar no grupo `docker`:

```bash
exit
ssh ${ADMIN_USER}@${VM_IP}
```

---

## Passo 5 — Configurar variáveis

```bash
cd ~/artemis-ai
cp .env.example .env
nano .env
```

Edite os campos:

| Variável | O que colocar |
|---|---|
| `PUBLIC_IP` | IP público da VM (ICE candidate WebRTC) |
| `DOMAIN_BASE` | Seu domínio base (ex: `meudominio.com`) |
| `LE_EMAIL` | E-mail para Let's Encrypt (avisos de expiração) |
| `<PERFIL>_USER_PASS` | Senha forte para o nível USER de cada perfil |
| `<PERFIL>_ADMIN_PASS` | Senha forte para o nível ADMIN |
| `TRAEFIK_BASIC_AUTH` | Hash bcrypt para o dashboard Traefik (gere com `make hash`) |

**Gere senhas fortes:**

```bash
python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#%&*+=?') for _ in range(20)))"
```

**Gere o hash do dashboard:**

```bash
sudo apt install -y apache2-utils
htpasswd -nbB admin SUASENHAFORTE
# copie o resultado para TRAEFIK_BASIC_AUTH no .env
# IMPORTANTE: dobre os $ → "$2y$05$..." vira "$$2y$$05$$..."
```

---

## Passo 6 — Subir o stack

```bash
cd ~/artemis-ai
make up
# ou: docker compose up -d
```

Acompanhe o Traefik emitindo certificados:

```bash
make logs-traefik
# ou: docker compose logs -f traefik
```

Você verá logs do `acme` se registrando no Let's Encrypt e obtendo certs (~1-2 minutos).

Verifique status:

```bash
make ps
```

Saída esperada: 5 containers (`traefik` + 4 `neko-*`), todos `Up` e `healthy`.

---

## Passo 7 — Acessar

Abra no navegador:

```
https://<perfil>.<seu-dominio>
```

Login Neko:
- **Display name:** qualquer nome (apelido público)
- **Password:** a senha USER ou ADMIN definida no `.env`

Login Traefik dashboard:
- **URL:** `https://traefik.<seu-dominio>`
- **Usuário:** `admin`
- **Senha:** a definida em `TRAEFIK_BASIC_AUTH`

---

## Operação no dia-a-dia

```bash
# Status
make ps                  # containers ativos
make status              # com uso de CPU/RAM

# Logs
make logs                # tudo
make logs-traefik        # só Traefik (TLS, routing)
make logs-<perfil>       # log específico

# Restart e atualização
make restart             # reinicia tudo
make pull                # baixa imagens novas
make update              # pull + recreate

# Manutenção
make down                # derruba tudo (mantém volumes)
make clean               # ⚠️ remove containers, redes E volumes
```

---

## Backup

Os perfis são pastas em `~/artemis-ai/data/`. Para backup:

```bash
# Backup local na VM
sudo tar czf ~/artemis-backup-$(date +%F).tar.gz -C ~/artemis-ai data certs

# Backup remoto
ssh ${ADMIN_USER}@${VM_IP} 'sudo tar czf - -C ~/artemis-ai data certs' \
  | gzip -d | tar xf - -C ./backup-$(date +%F)/
```

Para automatizar, use cron + rclone para S3/MinIO/Backblaze.

---

## Atualização do Artemis

Quando este projeto liberar versões novas:

```bash
ssh ${ADMIN_USER}@${VM_IP}
cd ~/artemis-ai

# Salve seu .env
cp .env .env.bak

# Puxe o repo
git pull

# Rebuild se houver mudanças no compose
docker compose pull
docker compose up -d
```

---

## Desligando para economizar

Quando não estiver em uso, desligue a VM (preserva disco e IP):

**Azure:**
```bash
az vm deallocate -g <rg> -n <vm>
az vm start      -g <rg> -n <vm>
```

**AWS:**
```bash
aws ec2 stop-instances --instance-ids <id>
aws ec2 start-instances --instance-ids <id>
```

Após reiniciar, suba o stack:
```bash
ssh ${ADMIN_USER}@${VM_IP} 'cd ~/artemis-ai && make up'
```

Os containers voltam com os perfis intactos.

---

## Próximos passos

- Habilite gravação de sessão (sidecar ffmpeg — em [roadmap](../README.md#roadmap))
- Integre com Keycloak para SSO (em roadmap)
- Migre para Kubernetes/Rancher quando passar de 10 perfis simultâneos
- Configure monitoramento (Prometheus + Grafana + Loki)
- Configure alertas (CPU, disco, certs próximos da expiração)

Dúvidas? Veja [troubleshooting.md](troubleshooting.md) ou abra uma issue.
