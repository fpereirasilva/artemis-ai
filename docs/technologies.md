# Tecnologias

> Catálogo de tudo que compõe o Artemis AI, com motivação técnica, alternativas consideradas e referências para aprofundamento.

---

## Browser streaming

### [Neko](https://github.com/m1k1o/neko)

**Licença:** Apache 2.0
**Versão usada:** `ghcr.io/m1k1o/neko/chromium:latest`

Servidor de browser streaming via WebRTC. Origem do projeto Mat Hertel (m1k1o), atualmente projeto open-source ativo com comunidade engajada.

**Componentes internos:**
- `Xvfb` — display X virtual sem GPU
- `Chromium` (ou Firefox/Brave/Edge/Vivaldi) — o navegador
- `GStreamer` — pipeline de captura e codificação
- `pion/webrtc` (Go) — servidor WebRTC
- `supervisord` — orquestração de processos

**Por que Neko:**
- Apache 2.0, sem teto de usuários (diferente de Kasm Community Edition que limita em 5)
- Multi-tenancy nativa via modo `multiuser`
- WebRTC nativo (latência baixa vs VNC tradicional)
- Imagens Docker oficiais para múltiplos navegadores

**Alternativas consideradas:**

| Opção | Licença | Por que não |
|---|---|---|
| Kasm Workspaces | Proprietária (CE limitada) | Limite de 5 sessões simultâneas no tier gratuito |
| Apache Guacamole | Apache 2.0 | RDP/VNC (mais pesado), sem WebRTC nativo |
| Selkies-GStreamer | Apache 2.0 | Foco em GPU/CAD; overkill para web |
| WebTop (LinuxServer.io) | Apache 2.0 | Desktop completo (não só browser) |
| Cloudflare Browser Isolation | Proprietária | Não auto-hospedável |

---

## Reverse proxy + TLS

### [Traefik](https://traefik.io/)

**Licença:** MIT
**Versão usada:** `traefik:v3.6`

Proxy reverso moderno com auto-discovery de serviços via Docker labels e provisionamento automático de certificados Let's Encrypt.

**Por que Traefik:**
- **Zero configuração estática** — toda rota declarada como label no `docker-compose.yml`
- **ACME nativo** — Let's Encrypt com 4 desafios suportados (HTTP-01, TLS-ALPN-01, DNS-01)
- **Dashboard web** com basic auth pronto
- **Middlewares plugáveis** — rate limiting, headers, redirect, basic auth
- **Atualização hot** — sem restart quando você adiciona um serviço

**Alternativas consideradas:**

| Opção | Por que não nesta POC |
|---|---|
| NGINX | Configuração manual de cada server block; cert renovation via certbot externo |
| Caddy | Excelente, mas menor base de exemplos para Docker label discovery |
| HAProxy | Foco em load balancing TCP; ACME via terceiros |
| Cloudflare Tunnel | Não funciona com WebRTC UDP |

### Let's Encrypt

**Licença:** Open / gratuito
**Versão usada:** ACME v2

CA gratuita que emite certificados TLS válidos por 90 dias, com renovação automática.

**Desafio escolhido:** TLS-ALPN-01 (mais simples, requer apenas porta 443 alcançável).

---

## Containers e orquestração

### [Docker](https://www.docker.com/)

**Licença:** Apache 2.0
**Versão mínima:** 24.0+ (testado com 29.4)

Container runtime padrão de mercado. A partir do Docker 25+, a API mínima é 1.40, o que afeta clientes antigos (ver [troubleshooting.md](troubleshooting.md#docker-29-vs-traefik-antigo)).

### [Docker Compose](https://docs.docker.com/compose/)

**Licença:** Apache 2.0
**Versão mínima:** v2.20+ (testado com v5.1)

Orquestrador declarativo para múltiplos containers em uma única máquina. Ideal para POCs e ambientes de desenvolvimento.

**Quando migrar para Kubernetes:** quando o número de containers, hosts ou requisitos de HA/auto-scaling justificar. Para ≤10 perfis em VM única, Compose é mais que suficiente.

---

## Sistema operacional

### Ubuntu 24.04 LTS

**Licença:** GPL (várias)

Distribuição padrão para servidor em cloud, com:
- Suporte LTS até 2029
- Pacotes Docker oficiais via repositório
- Kernel recente (6.x) com bom suporte a cgroups v2

**Alternativas viáveis:** Debian 12, Rocky Linux 9, openSUSE Leap 15.6, AlmaLinux 9.

---

## Segurança

### [UFW](https://launchpad.net/ufw) (Uncomplicated Firewall)

**Licença:** GPLv3

Frontend simples para `iptables`/`nftables`. Defesa em profundidade: mesmo se o NSG da cloud for mal configurado, o UFW na VM bloqueia.

**Regras nesta POC:**
- TCP 22 (SSH)
- TCP 80 (HTTP, redirect → 443)
- TCP 443 (HTTPS)
- UDP 59000-59400 (WebRTC EPR)

### [fail2ban](https://www.fail2ban.org/)

**Licença:** GPLv2

Monitora logs de auth e banane IPs com tentativas repetidas de brute-force SSH.

### unattended-upgrades

**Licença:** GPL

Instala automaticamente patches de segurança do Ubuntu sem reinício automático (configurável).

---

## DNS

### [Cloudflare DNS](https://www.cloudflare.com/dns/) (ou qualquer outro)

**Licença:** SaaS gratuito

DNS autoritativo com painel web amigável e API REST para automação.

**⚠️ Cuidado:** o **proxy laranja** do Cloudflare quebra esta POC (ver [troubleshooting.md](troubleshooting.md#cloudflare-proxy-quebra-tudo)). Use **DNS only (nuvem cinza)** nos subdomínios do Artemis.

**Alternativas:**
- Route 53 (AWS)
- Cloud DNS (GCP)
- Azure DNS
- Bind9 self-hosted

Qualquer um serve — o requisito é poder criar registros A/CNAME.

---

## Cloud (não-obrigatória)

### Microsoft Azure (testado)

VM `Standard_D4s_v5` em Brazil South, ~US$ 155/mês ligada 24/7.

**Por que Azure:**
- Créditos gratuitos via Visual Studio Subscription
- Latência baixa pra usuários BR
- Reputação boa na ASN (não cai em blacklists)

**Outras clouds testadas/viáveis:** AWS EC2, GCP Compute Engine, DigitalOcean Droplet, Hetzner Cloud, OVH, Vultr.

---

## Linguagens e ferramentas auxiliares

### [GNU Make](https://www.gnu.org/software/make/)

**Licença:** GPLv3

Atalhos para operação cotidiana (`make up`, `make down`, `make logs`).

### [bash](https://www.gnu.org/software/bash/)

**Licença:** GPLv3

Scripts de bootstrap e criação de VM.

### [Python 3](https://www.python.org/) (opcional)

**Licença:** PSF License

Geração de senhas fortes via `secrets` no setup inicial.

---

## Arquitetura de rede

### WebRTC

Standard W3C/IETF para comunicação peer-to-peer no navegador.

- **Mídia:** H.264 (vídeo) + Opus (áudio) sobre SRTP/DTLS
- **Sinalização:** WebSocket (no Neko)
- **NAT traversal:** ICE com `host` candidates (com `NAT1TO1`); STUN/TURN opcional para casos restritivos

### TLS-ALPN-01

Desafio ACME que usa a extensão TLS ALPN (Application-Layer Protocol Negotiation) para provar controle do domínio. Requer apenas porta 443.

**Limitação:** não funciona atrás de proxies que terminam TLS (Cloudflare laranja, alguns load balancers).

---

## O que NÃO é usado (e por quê)

| Tecnologia | Por que não |
|---|---|
| Kubernetes | Overhead para 4 perfis fixos. Caminho de evolução para produto. |
| Helm | Sem K8s, sem necessidade |
| Terraform | Scripts bash bastam para uma VM. Para multi-cloud/produto, Terraform vira útil. |
| Vault | Segredos no `.env` por simplicidade. Para produto, Vault ou AWS Secrets Manager. |
| Prometheus/Grafana | Fora do escopo POC. Adicionar quando precisar monitorar. |
| ELK / Loki | Logs via `docker compose logs` bastam para POC. |
| Keycloak | Fora do escopo POC. Está no roadmap. |
| coturn (TURN server) | Não necessário sem proxy CDN à frente. Adicionar se for usar Cloudflare proxy ativo. |

---

## Referências oficiais

- [Neko Documentation](https://neko.m1k1o.net/)
- [Traefik v3 Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Spec](https://github.com/compose-spec/compose-spec/blob/master/spec.md)
- [Let's Encrypt ACME v2](https://letsencrypt.org/docs/client-options/)
- [WebRTC W3C Specification](https://www.w3.org/TR/webrtc/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
