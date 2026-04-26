# Casos de uso

> Cenários reais onde o Artemis AI agrega valor — com a honestidade do que ele faz e do que não faz.

---

## 1. 🤖 Acesso compartilhado a contas de IA

**O problema:** Empresas pequenas e médias adotam várias ferramentas de IA generativa. Em pouco tempo, viram dezenas de licenças individuais — ChatGPT Plus para 5 pessoas, Claude Pro para 3, Perplexity Pro para 2. Custo escala linearmente com usuários.

**Como Artemis ajuda:** uma única conta da ferramenta acessada por múltiplos usuários através de um navegador remoto compartilhado. Cada perfil isolado mantém sessão autenticada; usuários acessam pelo navegador local sem nunca ver a credencial.

**Vantagens:**
- Custo proporcional ao tamanho do time, não ao número de logins
- Sem compartilhamento direto de senha (a senha vive no servidor)
- Histórico de prompts compartilhado vira ativo coletivo
- Onboarding instantâneo (basta dar link e senha do perfil)

**Limites importantes:**
- Verifique os Termos de Uso de cada provedor de IA — alguns proíbem uso compartilhado
- Para ferramentas que exigem identidade individual (logs de auditoria, billing por usuário), este modelo não serve
- Se um usuário sai da empresa, troca-se a senha do perfil — cada caso de uso decide se isso é aceitável

---

## 2. 🔒 Browser Isolation para acesso a sistemas críticos

**O problema:** Equipes precisam acessar portais sensíveis (judicial, governo, bancário, fiscal) a partir de máquinas que podem estar comprometidas. Malware no notebook do funcionário pode capturar credenciais, sessões, downloads.

**Como Artemis ajuda:** o navegador roda no servidor isolado. Mesmo se o notebook do usuário tiver keylogger, ele captura apenas senhas digitadas localmente — não credenciais que ficam no perfil remoto. Downloads ficam no servidor; usuário precisa explicitamente baixar.

**Vantagens:**
- Defesa em profundidade contra malware no endpoint
- Auditoria centralizada (log de quem abriu o quê, quando)
- Política de retenção controlada (limpar downloads após X dias)
- Compatível com BYOD (bring your own device)

**Limites importantes:**
- Não substitui antivírus/EDR no endpoint, complementa
- Se o servidor for comprometido, o problema é maior — proteja o servidor com NeuVector ou similar
- Performance pode ser inferior ao acesso direto (latência de WebRTC)

---

## 3. 👥 Suporte remoto e treinamento

**O problema:** Funcionário de help desk precisa ver o que o usuário está vendo. Soluções tradicionais (TeamViewer, AnyDesk) exigem instalação no endpoint, têm custo de licença por sessão e nem sempre funcionam atrás de firewalls corporativos.

**Como Artemis ajuda:** ambos abrem o mesmo perfil simultaneamente (modo `multiuser`). O suporte entra como ADMIN, o usuário como USER. O suporte vê em tempo real, e pode pedir/dar controle do cursor com um clique.

**Vantagens:**
- Zero instalação em qualquer ponta
- Funciona em qualquer dispositivo com navegador (mobile inclusive)
- Sessão pode ser gravada (com sidecar ffmpeg, em roadmap)
- Útil para treinamento de software corporativo

**Limites importantes:**
- Pra suporte da máquina LOCAL do usuário, não serve — Artemis não acessa a máquina dele, só o navegador remoto
- Para auditoria de quem fez o quê, modo `multiuser` único ainda mistura ações entre admin e user

---

## 4. 🧪 Sandbox para testar links suspeitos

**O problema:** Time recebe e-mail com link estranho. Clicar no notebook pessoal é arriscado. Alguns SOCs têm sandboxes pagos (Joe Sandbox, ANY.RUN); times menores não.

**Como Artemis ajuda:** abre o link num perfil dedicado e descartável. Após análise, recriar o container limpa qualquer coisa que o site tentou plantar (cookies, localStorage, downloads).

**Vantagens:**
- Container isolado por kernel namespaces — exploit típico não escapa
- Reset trivial: `docker compose down neko-sandbox && docker compose up -d`
- Não precisa de licença comercial de sandbox

**Limites importantes:**
- Não é sandbox forense — não captura tráfego, não analisa arquivos automaticamente
- Para análise séria de malware, use ferramenta dedicada (Cuckoo, ANY.RUN, etc.)
- Vulnerabilidades zero-day em Chromium ainda existem; container reduz mas não elimina risco

---

## 5. 🏛️ Acesso supervisionado a dados sensíveis (jurídico, regulatório)

**O problema:** Áreas jurídica, compliance ou auditoria precisam acessar bases sensíveis (Receita Federal, Tribunais, ANS, BACEN) com auditoria de quem viu o quê.

**Como Artemis ajuda:** sessão registrada (com gravação no roadmap), egress controlado (com NetworkPolicy se for K8s), retenção definida.

**Vantagens:**
- Compliance LGPD com trilha auditável
- Watermark dinâmico (na evolução produto) com nome+timestamp na tela
- Acesso revogável instantaneamente (mudar senha do perfil)

**Limites importantes:**
- Esta POC não tem gravação automática ainda (em roadmap)
- Para compliance formal, valide com o responsável legal
- Evolua para Rancher + NeuVector + MinIO Object Lock para produto

---

## 6. 🎬 Demonstrações ao vivo de produto SaaS

**O problema:** Pre-sales precisa demonstrar produto SaaS em apresentações. Compartilhar tela do notebook expõe abas, notificações, e-mails. Maquininhas dedicadas são caras.

**Como Artemis ajuda:** abre o perfil "demo" no projetor; participantes recebem link e veem ao vivo no notebook deles (modo `multiuser`). Vários demos por mês compartilham o mesmo container limpo.

**Vantagens:**
- Sem distrações de notificação pessoal
- Demo persiste entre apresentações (favoritos, login pré-feito)
- Cliente vê do dispositivo dele, não tem zoom/qualidade ruim de projetor

**Limites importantes:**
- Demos com vídeo embedded (call de cliente, vídeo de marketing) podem ter latência
- Precisa de internet boa nos dois lados

---

## 7. 🌐 Onboarding e acesso temporário sem instalação

**O problema:** Estagiários, freelancers, consultores precisam acessar ferramentas corporativas por dias ou semanas. Provisioning de notebook + VPN + licenças leva semanas e tem custo.

**Como Artemis ajuda:** crie um perfil dedicado, dê o link e a senha. Acesso imediato pelo navegador. Quando o engajamento termina, destrua o container.

**Vantagens:**
- Zero hardware, zero instalação
- Acesso revogável em 1 segundo
- Custo de provisioning ≈ 0

**Limites importantes:**
- Para acesso a sistemas que exigem cliente nativo (SAP GUI, CAD), não serve
- Para acesso a recursos de rede interna, precisa de VPN no servidor (não documentado nesta POC)

---

## 8. 🧩 Hub corporativo de bookmarks e SaaS

**O problema:** Time corporativo usa 30+ ferramentas SaaS. Cada um tem seu set de tabs, marcadores, atalhos diferentes. Reonboarding em novo notebook leva horas.

**Como Artemis ajuda:** um perfil "hub" pré-configurado com todos os bookmarks, abas pré-abertas, extensões padronizadas. Funcionário acessa de qualquer dispositivo e tem o ambiente igual.

**Vantagens:**
- Padronização de experiência
- Onboarding em 2 minutos
- Atualizações centralizadas (mude num lugar, todo mundo vê)

**Limites importantes:**
- Não substitui um Single Sign-On — apenas coloca todos os logins num perfil
- Para personalização individual, melhor cada um ter seu perfil

---

## Quando NÃO usar Artemis AI

Em alguns cenários, a solução não é a melhor. Seja honesto consigo:

| Cenário | Por que não usar |
|---|---|
| Streaming de vídeo / Netflix / DRM | Chromium não tem Widevine. Use Chrome real ou solução nativa. |
| Videoconferência (Meet/Teams/Zoom) | Áudio/vídeo aninhado funciona mal sobre WebRTC sobre WebRTC |
| Edição gráfica pesada (Figma, Photoshop web) | Latência atrapalha precisão de mouse |
| Multi-conta com antidetect | Esta solução é o oposto: foca em transparência, não em mascarar fingerprint |
| Acesso a sistemas que exigem cliente nativo | Artemis é puramente browser |
| Cargas com >50 usuários simultâneos numa VM | Migre para Kubernetes/Rancher |
| Compliance pesado (PCI-DSS, HIPAA) sem evolução | A POC base não atende sozinha; precisa evolução para produto |

---

## Inspirando-se em outros casos

- **Cloudflare Browser Isolation** — mesmo conceito comercial, vendido como segurança
- **Menlo Security** — pioneiro em RBI corporativo
- **Talon (Palo Alto)** — Enterprise Browser
- **Island Browser** — Enterprise Browser focado em produtividade
- **Kasm Workspaces** — open-core, tier comercial
- **Mighty / Hyperbeam** — RBI focados em consumer e dev (alguns descontinuados)

Se algum desses ressoa com seu caso, Artemis pode ser o caminho self-hosted para validar antes de comprar comercial.
