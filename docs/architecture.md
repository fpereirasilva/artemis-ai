# Arquitetura

> Visão técnica detalhada do Artemis AI: componentes, fluxos de dados, decisões de design e trade-offs.

---

## Visão geral

Artemis AI é um sistema de **Browser Isolation** auto-hospedado. Cada sessão de navegação acontece dentro de um container Docker isolado, e o cliente final acessa via HTTPS+WebRTC pelo navegador local. Não há instalação de software no cliente.

A arquitetura segue 4 princípios:

1. **Isolamento por container** — kernel namespaces + cgroups + volume dedicado
2. **Stateless por design** — qualquer container pode ser destruído e recriado sem perda relevante
3. **Estado em volumes nomeados** — dados persistentes ficam em pastas mapeadas, não na imagem
4. **TLS automático** — Traefik + Let's Encrypt, zero configuração manual de cert

---

## Diagrama lógico

```
┌─────────────────────────────────────────────────────────────────────┐
│                            Cliente                                   │
│      (qualquer navegador HTML5 com suporte WebRTC + HTTPS)          │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                  HTTPS 443 (controle/UI/WebSocket)
                  UDP 59000-59399 (mídia WebRTC)
                                 │
┌────────────────────────────────▼────────────────────────────────────┐
│                       Cloud Provider Edge                            │
│             (NSG / Security Group / Firewall externo)                │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────────┐
│                          VM Linux                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  UFW (firewall do host)                                       │   │
│  └──┬───────────────────────────────────────────────────────────┘   │
│     │                                                                │
│  ┌──▼─────────────────────────────────────────────────────────────┐ │
│  │              Docker bridge network "neko-net"                   │ │
│  │                                                                  │ │
│  │  ┌──────────┐                                                    │ │
│  │  │ Traefik  │ ← :80 (redirect→443), :443 (TLS termination)       │ │
│  │  │  v3.6+   │ ← Lê labels via Docker socket (read-only)          │ │
│  │  │  (ACME)  │ ← Mantém acme.json em volume local                 │ │
│  │  └──┬───────┘                                                    │ │
│  │     │ proxy reverso por Host:                                    │ │
│  │     │                                                             │ │
│  │  ┌──▼─────┐  ┌────────┐  ┌────────┐  ┌─────────┐                │ │
│  │  │Perfil A│  │Perfil B│  │Perfil C│  │Perfil D │                │ │
│  │  │  Neko  │  │  Neko  │  │  Neko  │  │  Neko   │                │ │
│  │  │Chromium│  │Chromium│  │Chromium│  │Chromium │                │ │
│  │  │+GStream│  │+GStream│  │+GStream│  │+GStream │                │ │
│  │  │+Xvfb   │  │+Xvfb   │  │+Xvfb   │  │+Xvfb    │                │ │
│  │  └──┬─────┘  └──┬─────┘  └──┬─────┘  └──┬──────┘                │ │
│  │     │           │            │           │                       │ │
│  └─────┼───────────┼────────────┼───────────┼───────────────────────┘ │
│        │           │            │           │                         │
│        ▼           ▼            ▼           ▼                         │
│   ./data/A    ./data/B     ./data/C    ./data/D                       │
│   (volume bind mounts — perfis persistentes)                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Componentes

### Traefik (reverse proxy + TLS)

**Função:** termina TLS, roteia tráfego HTTP/HTTPS para o container correto baseado no Host header, e provisiona certificados Let's Encrypt automaticamente via TLS-ALPN-01.

**Por que Traefik (e não NGINX/Caddy):**
- Auto-discovery via Docker labels — adicionar um perfil é só declarar labels no compose
- Configuração 100% declarativa, sem arquivos de config separados
- Suporte first-class a ACME com renovação automática
- Dashboard nativo

**Volumes:**
- `/var/run/docker.sock` (read-only) — para auto-discovery
- `./certs:/certs` — armazena `acme.json` com certificados emitidos

### Neko (browser streaming)

**Função:** roda um Chromium completo dentro do container, captura a tela (via Xvfb) e o áudio, codifica em H.264/Opus e transmite via WebRTC para o cliente. Recebe eventos de mouse/teclado pelo WebSocket de controle.

**Componentes internos do container Neko:**
- `Xvfb` — display virtual (1920x1080@30Hz)
- `Chromium headful` — o navegador propriamente
- `GStreamer` — pipeline de captura e encoding
- `pion/webrtc` (Go) — servidor WebRTC
- `supervisord` — gerencia todos os processos

**Modos de membership:**
- `multiuser` (usado nesta POC) — 2 senhas (USER e ADMIN), múltiplos clientes na mesma sessão
- `file` — banco de usuários em JSON
- `noauth` — sem autenticação (apenas dev)

**Persistência:**
- `/home/neko` é mapeado para `./data/<perfil>` no host
- Cookies, bookmarks, downloads, cache do Chromium ficam aqui

### Docker network "neko-net"

Bridge network isolada onde todos os containers conversam. Apenas o Traefik expõe portas externamente (80/443 TCP). Cada Neko expõe sua faixa UDP diretamente para o WebRTC.

### Volumes

| Volume | Tipo | Conteúdo | Tamanho típico |
|---|---|---|---|
| `./data/<perfil>/` | bind mount | `~/neko/` (cookies, downloads, cache) | 100 MB – 5 GB |
| `./certs/` | bind mount | `acme.json` com certs LE | < 100 KB |
| `/var/run/docker.sock` | bind mount RO | Socket do Docker daemon (Traefik) | — |

---

## Fluxos de dados

### 1. Conexão inicial do cliente

```
Cliente              Traefik              Neko                Let's Encrypt
   │                    │                    │                       │
   │ HTTPS 443          │                    │                       │
   │ Host: a.dom.com    │                    │                       │
   │───────────────────▶│                    │                       │
   │                    │ Cert válido?       │                       │
   │                    │  Não → ACME flow ──┼──────────────────────▶│
   │                    │◀──────────────────────────── cert ─────────│
   │                    │ rota baseada em    │                       │
   │                    │ Host: a.dom.com    │                       │
   │                    │ → service "fabio"  │                       │
   │                    │ HTTP 8080 ────────▶│                       │
   │                    │◀─────────────────  │                       │
   │◀───────────────────│  HTML + JS Neko    │                       │
```

### 2. Estabelecimento WebRTC

```
Cliente                   Neko                  ICE Server
  │                         │                       │
  │ WebSocket /api/ws       │                       │
  │ (autenticação, sessão)  │                       │
  │────────────────────────▶│                       │
  │◀────────────────────────│ token + room          │
  │                         │                       │
  │ SDP Offer (WebRTC)      │                       │
  │────────────────────────▶│                       │
  │                         │ ICE gather            │
  │                         │ candidates incluem    │
  │                         │ NEKO_WEBRTC_NAT1TO1   │
  │◀────────────────────────│ SDP Answer            │
  │                         │                       │
  │ ICE conn check (UDP)    │                       │
  │────────────────────────▶│                       │
  │◀────────────────────────│ STUN/peer-reflexive   │
  │                         │                       │
  │      Mídia H.264/Opus (UDP via DTLS-SRTP)       │
  │◀═══════════════════════▶│                       │
  │      Eventos input (DataChannel)                 │
```

### 3. Upload de arquivo (drag & drop)

```
Cliente                     Neko                  Chromium
  │                           │                      │
  │ drag arquivo .png         │                      │
  │ DataChannel "filetransfer"│                      │
  │──────────────────────────▶│                      │
  │                           │ salva em /home/neko/ │
  │                           │   Downloads/         │
  │                           │ aciona file dialog ──▶│
  │                           │◀────────────────────│ <input type=file>
  │                           │ arquivo anexado      │
```

---

## Decisões de design

### Por que Docker Compose e não Kubernetes nesta POC?

Para 4 perfis fixos numa VM única, K8s adiciona overhead operacional sem retorno proporcional. Compose é direto, bem documentado e roda em qualquer máquina com Docker. Para escalar (50+ perfis, múltiplas VMs, HA), o caminho natural é migrar para Rancher/RKE2 — os mesmos containers viram pods sem refatoração.

### Por que volume bind mount e não named volume?

Bind mount (`./data/<perfil>:/home/neko`) torna os arquivos visíveis no host, facilita backup com `tar`/`rsync` e auditoria. Named volumes (`docker volume create`) são mais portáveis mas opacos. Em produção, vale considerar Longhorn/CephFS para replicação.

### Por que `multiuser` em vez de banco de usuários?

POC busca simplicidade. Em produção, integrar com Keycloak (OIDC) e ter cada usuário com identidade própria. O modo `multiuser` ainda assim permite **multiplos clientes simultâneos por perfil**, que é uma feature útil para suporte/treinamento mesmo após SSO.

### Por que TLS-ALPN-01 e não DNS-01?

TLS-ALPN-01 é mais simples: não exige API token do provedor DNS, não exige propagação. Funciona desde que a porta 443 chegue na máquina. **Limitação:** quebra atrás de Cloudflare proxy ativo — neste caso, migrar para DNS-01.

### Por que Cloudflare DNS only (proxy desligado)?

O proxy laranja do Cloudflare termina TLS no edge, fazendo o desafio TLS-ALPN-01 nunca chegar à origem. Além disso, Cloudflare não proxya UDP, então WebRTC vai direto e o cliente precisa do IP de origem. **Solução POC:** desligar proxy. **Solução produto:** DNS-01 + coturn.

---

## Trade-offs

| Decisão | Ganho | Custo |
|---|---|---|
| Compose puro | Simplicidade, debug fácil | Sem auto-scaling, sem HA |
| Bind mount | Backup trivial, visibilidade | Acoplado ao filesystem do host |
| Multiuser único por perfil | UX simples para POC | Sem identidade individual / audit por usuário |
| Cloudflare DNS only | TLS-ALPN funciona, WebRTC direto | Sem DDoS protection no edge |
| Sem TURN | Menos serviços | Falha em redes muito restritivas (CGNAT estrito) |
| Chromium (não Chrome) | Imagem menor, sem Widevine | Não toca DRM (Netflix, Prime) |

---

## Caminho de evolução

Para virar produto comercial:

1. **Orquestração:** Rancher Prime + RKE2 + Longhorn (storage) + NeuVector (segurança L7)
2. **Identidade:** Keycloak com SSO SAML/OIDC, integração corporativa
3. **Provisioning:** API Go ou FastAPI que cria pods sob demanda, destrói após sessão
4. **Auditoria:** ffmpeg sidecar gravando MP4 com timestamp, S3/MinIO com Object Lock
5. **DLP:** NeuVector inspeciona L7, bloqueia exfiltração, alerta sobre padrões
6. **Multi-região:** GeoDNS (Route 53/Cloudflare) + clusters em diferentes regiões
7. **Billing:** integração com Stripe ou faturamento corporativo

Esses componentes não são parte do escopo desta POC, mas são o caminho lógico de produtização.
