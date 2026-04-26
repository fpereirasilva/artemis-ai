# Troubleshooting

> Os problemas reais que travam tutoriais copiados, e como resolver cada um.

---

## Diagnóstico rápido — onde olhar primeiro

```bash
# 1. Containers estão de pé?
docker compose ps

# 2. Logs do serviço com problema
docker compose logs <serviço> --tail=100

# 3. DNS está propagado?
dig +short fabio.<seu-dominio>

# 4. Porta 443 alcança a VM?
curl -I https://fabio.<seu-dominio> -k

# 5. Cert é Let's Encrypt válido?
echo | openssl s_client -connect fabio.<seu-dominio>:443 \
  -servername fabio.<seu-dominio> 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```

Se algum desses falhar, abra a seção correspondente abaixo.

---

## Cloudflare proxy quebra tudo

**Sintoma:** Let's Encrypt falha, vídeo não carrega, conexão WebRTC trava.

**Causa:** Quando o **proxy laranja** do Cloudflare está ativo:
- Termina TLS no edge → desafio TLS-ALPN-01 do Let's Encrypt nunca chega na origem
- Não proxya UDP → WebRTC tenta conectar no IP do CF e falha
- WebSocket pode ter limites de tempo

**Solução:** No painel Cloudflare, defina o registro como **DNS only** (nuvem cinza), não Proxied (laranja).

```
fabio.dominio.com    A    1.2.3.4    [DNS only ☁️]   ← correto
fabio.dominio.com    A    1.2.3.4    [Proxied 🟠]    ← errado para esta POC
```

**Alternativa para manter proxy ativo (mais complexa):**
1. Trocar Traefik para usar **DNS-01 challenge** (precisa de API token Cloudflare)
2. Subir um servidor **TURN** (coturn) acessível diretamente (sem CF)
3. Configurar Neko com `NEKO_WEBRTC_ICELITE=false` e ICE servers do TURN
4. Ainda assim, latência vai aumentar

---

## Docker 29 vs Traefik antigo

**Sintoma:** Traefik fica em loop de erro:
```
Failed to retrieve information of the docker client and server host
error="Error response from daemon: client version 1.24 is too old.
Minimum supported API version is 1.40"
```

**Causa:** Docker 29.x dropou suporte a API < 1.40. Traefik anterior à v3.5 usa SDK Go que envia API 1.24 hardcoded. A env var `DOCKER_API_VERSION` não corrige.

**Solução:** atualize o Traefik:

```yaml
# docker-compose.yml
traefik:
  image: traefik:v3.6   # ou superior
```

Recriar:
```bash
docker compose pull traefik
docker compose up -d traefik
```

---

## Vídeo não aparece (tela preta após login)

**Sintoma:** Login funciona, sidebar do Neko aparece, mas a área principal de vídeo fica preta ou só com loading.

**Causa quase sempre:** WebRTC não consegue estabelecer conexão UDP.

### Checklist

1. **Portas UDP abertas no firewall da cloud?**
   ```bash
   # Azure
   az network nsg rule list -g <rg> --nsg-name <nsg> -o table
   # deve ter regra para UDP 59000-59400
   ```

2. **Portas UDP abertas no UFW da VM?**
   ```bash
   sudo ufw status
   # deve mostrar 59000:59400/udp ALLOW
   ```

3. **Variável `NEKO_WEBRTC_NAT1TO1` está com o IP público correto?**
   ```bash
   docker exec neko-fabio env | grep NEKO_WEBRTC_NAT1TO1
   # deve ser o IP que aparece em: curl ifconfig.me
   ```

4. **Cliente está em rede com WebRTC aberto?**
   - Algumas redes corporativas bloqueiam UDP arbitrário
   - Algumas VPNs interferem com NAT traversal
   - Teste de outra rede (4G, casa) para isolar

5. **Faixa de portas correta no compose?**
   ```yaml
   environment:
     NEKO_WEBRTC_EPR: "59000-59099"   # 100 portas
   ports:
     - "59000-59099:59000-59099/udp"   # mesma faixa
   ```

---

## Certificado Let's Encrypt não emite

**Sintoma:** Browser mostra cert auto-assinado do Traefik, ou cert inválido.

**Causa:** Vários possíveis.

### Verificações

```bash
# 1. DNS está apontando para a VM?
dig +short fabio.<seu-dominio>
# deve retornar o IP da VM

# 2. Porta 443 está alcançável de fora?
curl -I https://fabio.<seu-dominio> -k
# deve retornar status HTTP, não timeout

# 3. Logs do Traefik
docker compose logs traefik | grep -iE "acme|certificate|error"
```

### Causas comuns

| Erro nos logs | Causa | Solução |
|---|---|---|
| `urn:ietf:params:acme:error:rateLimited` | Bateu rate limit do LE (5 certs/semana/domain) | Aguarde 7 dias ou use staging environment |
| `unable to obtain ACME certificate` | DNS não resolve ainda | Aguarde propagação (pode levar até 48h em alguns casos) |
| `connection refused` | Porta 443 fechada externamente | Verifique NSG/security group |
| Cert para `TRAEFIK DEFAULT CERT` | ACME ainda não emitiu (pode estar tentando) | Aguarde 1-2 minutos, recheque logs |

---

## Containers reiniciando em loop

**Sintoma:** `docker compose ps` mostra um Neko com status `Restarting`.

**Diagnóstico:**
```bash
docker logs neko-<perfil> --tail=50
```

**Causas comuns:**

1. **Falta `cap_add: SYS_ADMIN`** — Chromium precisa para sandbox interna
2. **`shm_size` muito pequeno** — Chromium precisa de pelo menos 1 GB de SHM
3. **Imagem não baixou** — `docker pull ghcr.io/m1k1o/neko/chromium:latest`
4. **Variável obrigatória faltando** — verifique `.env` e logs do container

---

## Login Neko não autentica

**Sintoma:** Senha correta retorna "wrong password" ou tela em branco após login.

**Verificações:**

1. **Senha tem caracteres especiais não escapados?**
   - No `.env`, senha NÃO precisa de aspas
   - Caracteres como `$`, `\`, `"` podem precisar de escape em compose
   - Teste com senha simples temporariamente para isolar

2. **`.env` foi recarregado pelo compose?**
   ```bash
   docker compose down
   docker compose up -d
   ```
   `restart` não recarrega variáveis novas.

3. **Modo de membership está em `multiuser`?**
   ```bash
   docker exec neko-fabio env | grep NEKO_MEMBER
   # deve ter NEKO_MEMBER_PROVIDER=multiuser
   ```

---

## Upload de arquivo não funciona

**Sintoma:** Drag & drop não anexa, sidebar de arquivos não aparece.

**Solução:**

```yaml
# docker-compose.yml — em cada perfil
environment:
  NEKO_FILETRANSFER_ENABLED: "true"
  NEKO_FILETRANSFER_ROOT_DIR: "/home/neko/Downloads"
```

Crie o diretório no host e ajuste owner:
```bash
sudo mkdir -p data/<perfil>/Downloads
sudo chown -R 1000:1000 data/
docker compose up -d
```

---

## VM caiu / precisei reiniciar

**Sintoma:** SSH retorna `Connection refused`.

```bash
# Azure - verifique status
az vm show -d -g <rg> -n <vm> --query powerState
# Se "VM stopped" ou "VM deallocated":
az vm start -g <rg> -n <vm>
```

Após VM voltar:
```bash
ssh ${user}@${ip}
cd ~/artemis-ai
docker compose ps
# Se containers não subiram automaticamente:
docker compose up -d
```

Se você usou `make` no bootstrap, o systemd já reinicia o Docker, e os containers com `restart: unless-stopped` voltam sozinhos.

---

## "Resource temporarily unavailable" / OOM

**Sintoma:** containers começam a morrer aleatoriamente, logs mostram OOM.

**Causa:** VM subdimensionada para a carga.

**Diagnóstico:**
```bash
docker stats --no-stream
free -h
df -h
```

**Solução:**
- Aumentar RAM da VM (ex: D4 → D8)
- Reduzir `cpus` e `memory` limites por perfil
- Reduzir resolução de display: `NEKO_DESKTOP_SCREEN: "1280x720@30"`

---

## Disco cheio

**Sintoma:** `No space left on device` em logs.

**Diagnóstico:**
```bash
df -h
du -sh ~/artemis-ai/data/*/Downloads/
docker system df
```

**Limpeza:**
```bash
# Limpar Downloads dos perfis
sudo rm -rf ~/artemis-ai/data/*/Downloads/*

# Limpar imagens Docker não usadas
docker image prune -af

# Limpar cache do navegador (drástico)
docker compose down
sudo rm -rf ~/artemis-ai/data/*/Cache
docker compose up -d
```

---

## Renovação de certificado falhou

**Sintoma:** Próximo da data de expiração (90 dias após emissão), navegador alerta cert inválido.

**Verificação:**
```bash
docker compose logs traefik | grep -iE "renew|expire"
```

**Solução:**
```bash
docker compose restart traefik
# aguarde 2 min e recheque
```

Se persistir, force renovação:
```bash
sudo rm -f ~/artemis-ai/certs/acme.json
sudo touch ~/artemis-ai/certs/acme.json
sudo chmod 600 ~/artemis-ai/certs/acme.json
docker compose restart traefik
```

> ⚠️ Cuidado com rate limits do Let's Encrypt (5 certs/semana por domínio).

---

## Latência alta / vídeo travando

**Sintoma:** Vídeo com micro-pausas, mouse com delay perceptível.

**Causas e soluções:**

| Causa | Como confirmar | Solução |
|---|---|---|
| CPU saturada | `docker stats` mostra >100% por container | Reduzir uso simultâneo, aumentar VM |
| Banda da VM saturada | `iftop` ou `nload` na VM | Migrar para SKU com mais bandwidth |
| Cliente em rede ruim | Testar de outra rede | Reduzir resolução: `1280x720@25` |
| Buffer UDP do kernel | `sysctl net.core.rmem_max` < 16777216 | Reaplicar tuning do bootstrap |

---

## Como pedir ajuda

Antes de abrir uma issue, colete:

```bash
# Versões
docker version
docker compose version
uname -a

# Status
docker compose ps
docker compose logs --tail=200 > artemis-logs.txt

# Sanitizar logs (remover seu domínio se quiser)
sed -i 's/seudominio.com/example.com/g' artemis-logs.txt
sed -i 's/<seu-ip-publico>/X.X.X.X/g' artemis-logs.txt
```

Cole no issue (sem `.env`, sem senhas, sem IPs reais se preferir).

Não encontrou aqui? Abra uma [issue](https://github.com/fpereirasilva/artemis-ai/issues) com o cenário detalhado.
