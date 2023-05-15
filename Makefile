#!/usr/bin/make -f
.SILENT:
.PHONY: help build up uplog down ssh clean freespace

## Colors
COLOR_RESET   = \033[0m
COLOR_INFO    = \033[32m
COLOR_COMMENT = \033[33m

## Exibe as instruções de uso.
help:
	printf "${COLOR_COMMENT}Uso:${COLOR_RESET}\n"
	printf " make [comando]\n\n"
	printf "${COLOR_COMMENT}Comandos disponíveis:${COLOR_RESET}\n"
	awk '/^[a-zA-Z\-\_0-9\.@]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf " ${COLOR_INFO}%-16s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Prepara o ambiente para subit os containers.
prepare:
	make clean
	sudo rm -rf data && \
	mkdir -p data/zookeeper/log/version-2 && \
	mkdir -p data/zookeeper/data/version-2 && \
	sudo chown -R 1000 data/zookeeper && \
	mkdir -p data/kafka/secrets && \
	mkdir -p data/kafka/data && \
	sudo chown -R 1000 data/kafka

## Inicia a aplicação.
up:
	docker-compose up -d
	DB_USER=root DB_PASSWORD=root DB_SERVER=0.0.0.0 DB_PORT=3331 ./wait-for-mysql.sh
	@echo ✅ comando UP finalizado.

## Inicia a aplicação sem deligar o log do container
uplog:
	docker-compose up
	@echo ✅ comando UPLOG finalizado.

## Cria os conectors
connectors: SHELL:=/bin/bash
connectors:
	for i in {1..1000}; do curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d "$$(cat connector.json | sed "s/INDEX/$$i/g")" ; done;

## Cria os bancos de dados
databases: SHELL:=/bin/bash
databases:
	for i in {1..1000}; do mysql -h0.0.0.0 --port 3331 -uroot -proot -e "CREATE DATABASE mydatabase$$i ;" ; done ;

## Cria as tabelas no banco de dados
tables: SHELL:=/bin/bash
tables:
	for i in {1..1000}; do mysql -h0.0.0.0 --port 3331 -uroot -proot mydatabase$$i < auditoria.sql ; done;

## Insere registro no banco de dados
populate: SHELL:=/bin/bash
populate:
	for i in {1..1000}; do mysql -h0.0.0.0 --port 3331 -uroot -proot -e "CALL generate_data();" mydatabase$$i & done;

## Executa a POC
poc:
	make stop
	make down
	make prepare
	make up	
	make databases
	make tables
	make connectors
	make populate

## Para a aplicação.
stop:
	@echo 🔴 Parando os serviços.
	docker-compose stop

## Desliga a aplicação.
down:
	@echo 🔴 Desligando os serviços.
	docker-compose down

## Exibe os logs da aplicação.
logs: 
	docker-compose logs -f

## Apaga arquivos gerados dinâmicamente pelo projeto (containers docker, modules, etc)
clean:
	@echo 🗑️ Removendo arquivos gerados automaticamente pelo projeto.
	sudo rm -rf data
	docker-compose rm --force
	docker-compose down --rmi local --remove-orphans --volumes

## Libera espaço em disco (apaga dados do docker em desuso)
freespace:
	@echo 🗑️ Apagando arquivos do Docker que não estão sendo utilizados
	docker system prune --all --volumes --force