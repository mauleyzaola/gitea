.PHONY: clean init-gitea create-user create-repo init-repo logs start stop

clean: stop
	@rm -rf gitea-data

init-gitea:
	@./init-gitea.sh

create-user:
	@./create-user.sh

create-repo:
	@./create-repo.sh $(NAME)

init-repo: init-gitea create-user
	@$(MAKE) create-repo NAME=$(NAME)

logs:
	@docker compose logs -f

start:
	@docker compose up -d

stop:
	@docker compose down --remove-orphans
