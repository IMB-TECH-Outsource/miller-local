-include .env
export

COMPOSE = docker compose

.PHONY: init pull build up down restart logs ps dump restore superuser shell release

init:
	@test -f .env || cp .env.example .env
	@$(MAKE) pull

pull:
	@./scripts/sync-repo.sh src/backend "$(BACKEND_REPO)" "$(BACKEND_BRANCH)"
	@./scripts/sync-repo.sh src/frontend "$(FRONTEND_REPO)" "$(FRONTEND_BRANCH)"
	$(COMPOSE) pull postgres redis

build: pull
	$(COMPOSE) build

up: build
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart backend frontend

logs:
	$(COMPOSE) logs -f --tail=100

ps:
	$(COMPOSE) ps

dump:
	$(COMPOSE) exec dumper /dump.sh

restore:
	@test -n "$(FILE)" || (echo "Usage: make restore FILE=backups/xxx.sql.gz" && exit 1)
	gunzip -c "$(FILE)" | $(COMPOSE) exec -T postgres psql -U $(POSTGRES_USER) $(POSTGRES_DB)

superuser:
	$(COMPOSE) exec backend python manage.py createsuperuser

shell:
	$(COMPOSE) exec backend python manage.py shell

release:
	./scripts/release.sh
