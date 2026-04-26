# =============================================================================
# Artemis AI - Makefile
# =============================================================================
# Atalhos para operacao do laboratorio.
# Uso: make <alvo>
# =============================================================================

.PHONY: help up down restart logs ps pull update clean status hash

help:
	@echo "Artemis AI - Comandos disponiveis:"
	@echo ""
	@echo "  make up              Sobe todo o stack (Traefik + 4 perfis)"
	@echo "  make down            Derruba o stack (mantem volumes)"
	@echo "  make restart         Reinicia tudo"
	@echo "  make logs            Tail de todos os logs"
	@echo "  make logs-traefik    Logs do Traefik (TLS, routing)"
	@echo "  make logs-profile1   Logs do perfil 1"
	@echo "  make ps              Lista containers rodando"
	@echo "  make status          Status detalhado + uso de recursos"
	@echo "  make pull            Atualiza imagens (Neko + Traefik)"
	@echo "  make update          Pull + recreate"
	@echo "  make clean           Remove containers, redes e VOLUMES (zera perfis)"
	@echo "  make hash            Gera hash basic-auth para o Traefik dashboard"
	@echo ""

up:
	docker compose up -d
	@echo ""
	@echo "Stack no ar. Aguarde ~2min para o Let's Encrypt emitir o cert."
	@echo "Acompanhe: make logs-traefik"

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=100

logs-traefik:
	docker compose logs -f traefik

logs-profile1:
	docker compose logs -f neko-profile1

logs-profile2:
	docker compose logs -f neko-profile2

logs-profile3:
	docker compose logs -f neko-profile3

logs-profile4:
	docker compose logs -f neko-profile4

ps:
	docker compose ps

status:
	@echo "=== Containers ==="
	@docker compose ps
	@echo ""
	@echo "=== Uso de recursos ==="
	@docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

pull:
	docker compose pull

update: pull
	docker compose up -d
	docker image prune -f

clean:
	@echo "Isso vai apagar TODOS os perfis (cookies, bookmarks, downloads)."
	@read -p "Tem certeza? [s/N] " confirm; \
	if [ "$$confirm" = "s" ]; then \
		docker compose down -v; \
		sudo rm -rf data/*/; \
		mkdir -p data/profile1 data/profile2 data/profile3 data/profile4; \
		echo "Limpo."; \
	else \
		echo "Cancelado."; \
	fi

hash:
	@which htpasswd >/dev/null 2>&1 || { echo "Instale: sudo apt install apache2-utils"; exit 1; }
	@read -p "Usuario: " u; \
	read -s -p "Senha:   " p; echo; \
	echo ""; \
	echo "Cole no .env (TRAEFIK_BASIC_AUTH=...) com os \$$ duplicados ($$\$$):"; \
	htpasswd -nbB "$$u" "$$p" | sed 's/\$$/\$$\$$/g'
