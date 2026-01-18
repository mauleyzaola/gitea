.PHONY: clean init-repo logs start stop

clean: stop
	@rm -rf gitea-data

init-repo:
	./init-gitea.sh

logs:
	@docker compose logs -f

start:
	@docker compose up -d

stop:
	@docker compose down --remove-orphans
