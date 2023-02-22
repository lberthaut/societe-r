include .env
ifneq ("$(wildcard .env.local)","")
	include .env.local
endif

.DEFAULT_GOAL 		= help
isContainerRunning 	:= $(shell docker info > /dev/null 2>&1 && docker ps | grep $(PROJECT_NAME)-app > /dev/null 2>&1 && echo 1)

DOCKER-COMPOSE 	:= @docker compose
DOCKER 			:=
DOCKER_TEST 	:= APP_ENV=test

ifeq ($(isContainerRunning), 1)
	user 		:= $(shell id -u)
	group 		:= $(shell id -g)
	DOCKER 		:= @docker exec -t -u $(user):$(group) $(PROJECT_NAME)-app
	DOCKER_TEST := @docker exec -e APP_ENV=test -t -u $(user):$(group) $(PROJECT_NAME)-app
endif

CONSOLE 		:= $(DOCKER) symfony console
CONSOLE_TEST 	:= $(DOCKER_TEST) symfony console
COMPOSER 		:= $(DOCKER) composer


## —— 🐝 The Symfony Makefile 🐝 ———————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9_-]+:.*?## .*$$)|(^## )' Makefile | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Composer 🧙‍♂️ ————————————————————————————————————————————————————————————
install: composer.lock ## Install vendors according to the current composer.lock file
	$(COMPOSER) install -n

update: composer.json ## Update vendors according to the composer.json file
	$(COMPOSER) update -w

## —— Symfony ✅ —————————————————————————————————————————————————————————————————
cc: ## symfony cache clear
	$(CONSOLE) c:c

doctrine-validate:
	$(CONSOLE) doctrine:schema:validate --skip-sync -vvv -n $c

create-database: ## create database if not exists
	$(CONSOLE) d:d:c --if-not-exists

drop-database: ## force drop database
	$(CONSOLE) d:d:d -n --force

migration: ## Make doctrine migration file
	$(CONSOLE) make:migration -n

migrate: ## Apply migrations generated
	$(CONSOLE) d:m:m -n --allow-no-migration --all-or-nothing

load-fixtures: ## Load fixtures doctrine
	$(CONSOLE) d:f:l -n --purge-with-truncate

reset: drop-database create-database migrate load-fixtures ##

## —— Tests ✅ —————————————————————————————————————————————————————————————————
test-database: ### load database schema
	$(CONSOLE_TEST) doctrine:database:drop --if-exists --force
	$(CONSOLE_TEST) doctrine:database:create --if-not-exists
	$(CONSOLE_TEST) doctrine:migration:migrate -n --all-or-nothing --allow-no-migration

test-load-fixtures: phpunit.xml* test-database ## load database schema & fixtures
	$(CONSOLE_TEST) d:f:l -n --purge-with-truncate

test: phpunit.xml* ## Launch main functional and unit tests
	$(DOCKER_TEST) ./vendor/bin/simple-phpunit tests/ --stop-on-failure $(c)

test-report: phpunit.xml* test-load-fixtures ## Launch main functional and unit tests
	$(DOCKER_TEST)  ./vendor/bin/simple-phpunit tests/ --coverage-text --colors=never --log-junit report.xml $(c)

## —— Coding standards ✨ ——————————————————————————————————————————————————————
stan: ## Run PHPStan only
	$(DOCKER) ./vendor/bin/phpstan analyse

cs-fix: ## Run php-cs-fixer and fix the code.
	$(DOCKER) ./vendor/bin/php-cs-fixer fix --allow-risky=yes

cs-dry: ## Run php-cs-fixer and fix the code.
	$(DOCKER) ./vendor/bin/php-cs-fixer fix --dry-run --allow-risky=yes

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
ps: docker-compose.yaml ## docker display ps containers
	$(DOCKER-COMPOSE) ps

up: docker-compose.yaml ## up services for running containers
	$(DOCKER-COMPOSE) up -d $(c)
	$(DOCKER-COMPOSE) ps

build: docker-compose.yaml ## up services for running containers
	$(DOCKER-COMPOSE) build $(c)

pull: docker-compose.yaml ## up services for running containers
	$(DOCKER-COMPOSE) pull $(c)

build-up: build up ## build and up services for running containers

pull-up: login build up ## pull and up services for running containers

app: docker-compose.yaml ## exec bash command for containers app
	$(DOCKER-COMPOSE) exec app zsh $(c)

logs: docker-compose.yaml ## exec bash command for containers app
	$(DOCKER-COMPOSE) logs -f $(c)

restart: docker-compose.yaml ## restart containers
	$(DOCKER-COMPOSE) restart $(c)

down: docker-compose.yaml ## down containers
	$(DOCKER-COMPOSE) down --remove-orphans $(c)
	$(DOCKER-COMPOSE) rm $(c)

login: ## login registry gitlab
	@docker login $(REGISTRY) -u $(USER) -p $(TOKEN)
## —— Deployments ————————————————————————————————————————————————————————————————

pipeline-build: login
	@docker build --target php -t $(REGISTRY_IMAGE):pipeline ./
	@docker push $(REGISTRY_IMAGE):pipeline