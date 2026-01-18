.PHONY: clean init-gitea create-user create-token create-repo delete-repo init-repo logs start stop

clean: stop
	@rm -rf gitea-data

init-gitea:
	@./init-gitea.sh

create-user:
	@./create-user.sh

create-token:
	@./create-token.sh

create-repo:
	@./create-repo.sh $(NAME)

delete-repo:
	@./delete-repo.sh $(NAME)

logs:
	@docker compose logs -f

start:
	@docker compose up -d

stop:
	@docker compose down --remove-orphans
