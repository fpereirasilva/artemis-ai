# Contribuindo com Artemis AI

Obrigado pelo interesse em contribuir! Este projeto é um experimento aberto e acolhe melhorias de qualquer pessoa.

## Como contribuir

### Reportando bugs

1. Verifique se já não existe uma [Issue aberta](https://github.com/fpereirasilva/artemis-ai/issues) para o problema.
2. Abra uma nova issue com:
   - Descrição clara do problema
   - Passos para reproduzir
   - Comportamento esperado vs observado
   - Versões de Docker, Traefik, Neko, OS
   - Logs relevantes (sanitizados — sem credenciais)

### Sugerindo features

Abra uma issue marcada como `enhancement` descrevendo:
- O caso de uso que motiva a feature
- Como você imagina a implementação
- Alternativas consideradas

### Pull Requests

1. Faça fork do repositório
2. Crie uma branch a partir de `main`: `git checkout -b feat/minha-feature`
3. Faça suas mudanças seguindo os padrões abaixo
4. Adicione/atualize documentação em `docs/` se aplicável
5. Abra um Pull Request descrevendo o **porquê** da mudança (não apenas o quê)

## Padrões

### Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — nova funcionalidade
- `fix:` — correção de bug
- `docs:` — apenas documentação
- `chore:` — tarefas de manutenção (deps, CI)
- `refactor:` — mudança sem alterar comportamento
- `test:` — testes
- `perf:` — melhoria de performance

Exemplos:
- `feat: add Keycloak SSO integration`
- `fix: handle Cloudflare proxy edge case in setup script`
- `docs: clarify NEKO_WEBRTC_NAT1TO1 requirement`

### Código

- Bash: `set -euo pipefail` em scripts; valide entradas; nunca confie em variáveis sem default
- YAML/Compose: 2 espaços, sem tabs; mantenha ordem alfabética em listas longas
- Markdown: linhas com até 120 caracteres; use code fences com linguagem (`bash`, `yaml`)

### Segurança

**Nunca commite segredos.** O `.gitignore` já protege casos comuns, mas:

- Antes de cada commit, execute `git diff --staged | grep -iE 'password|token|secret|key'`
- Se acidentalmente comitou um segredo, **rotacione imediatamente** e abra uma issue
- Use sempre `.env.example` com placeholders para novas variáveis

### Documentação

- Toda nova feature precisa de menção em `docs/` correspondente
- README.md deve permanecer enxuto — detalhes técnicos vão para `docs/`
- Não use jargão sem definir; assuma leitor esperto mas novo no projeto

## Revisão

- PRs precisam de pelo menos 1 aprovação para merge
- Mantenedores podem solicitar mudanças; responda no PR ou abra discussão
- Tenha paciência — este é um projeto comunitário em tempo voluntário

## Código de conduta

Seja gentil. Críticas técnicas são bem-vindas; ataques pessoais não. Veja [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Dúvidas?

Abra uma [Discussion](https://github.com/fpereirasilva/artemis-ai/discussions) ou marque uma issue como `question`.
