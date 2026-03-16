PROJECT ?= dspace
ENV_FILE ?= .env
COMPOSE ?= docker compose

compose = $(COMPOSE) --project-name $(PROJECT) --env-file $(ENV_FILE)

.PHONY: build up down setup ingest logs logs-web-ui status shell cli clean config

build:
	$(compose) build --pull

up:
	$(compose) up -d

down:
	$(compose) down

setup:
	./scripts/setup.sh $(ENV_FILE)

ingest:
	./scripts/ingest.sh token=$(token) env_file=$(ENV_FILE)

logs:
	$(compose) logs -f

logs-web-ui:
	$(compose) logs -f web-ui

status:
	$(compose) ps

shell:
	$(compose) exec web-ui /bin/bash

cli:
	$(compose) exec web-api /dspace/bin/dspace $(cmd)

clean:
	$(compose) down -v

config:
	$(compose) config
