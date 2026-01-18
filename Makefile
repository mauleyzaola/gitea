.PHONY: clean init-gitea create-user create-repo init-repo logs start stop

clean: stop
	@rm -rf gitea-data

init-gitea:
	@./init-gitea.sh

create-user:
	@./create-user.sh

create-repo:
	@./create-repo.sh

init-repo: init-gitea create-user create-repo

logs:
	@docker compose logs -f

start:
	@docker compose up -d

stop:
	@docker compose down --remove-orphans
