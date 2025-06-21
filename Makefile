.PHONY: help migrate-up migrate-down

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help                  Show this help message"
	@echo "  migrate-up            Apply all up migrations"
	@echo "  migrate-down          Roll back the last migration"
	@echo "  migrate-create NAME=  Create a new migration"
	@echo "  migrate-force VERSION= Force a specific migration version"


GOPATH=$(shell go env GOPATH)
# Set GOBIN to GOBIN environment variable or default to GOPATH/bin
GOBIN?=$(GOPATH)/bin
MIGRATE=$(GOBIN)/migrate
DB_URL=postgres://postgres:yourpassword@localhost:5434/global_remit?sslmode=disable

migrate-up:
	@if ! [ -x "$(MIGRATE)" ]; then \
		echo "migrate not found. Run 'make install-migrate'"; \
		exit 1; \
	fi
	$(MIGRATE) -database "$(DB_URL)" -path backend/db/migrations up

migrate-down:
	@if ! [ -x "$(MIGRATE)" ]; then \
		echo "migrate not found. Run 'make install-migrate'"; \
		exit 1; \
	fi
	$(MIGRATE) -database "$(DB_URL)" -path backend/db/migrations down 1

migrate-create:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make migrate-create NAME=<migration_name>"; \
		exit 1; \
	fi
	@if ! [ -x "$(MIGRATE)" ]; then \
		echo "migrate not found. Run 'make install-migrate'"; \
		exit 1; \
	fi
	$(MIGRATE) create -ext sql -dir backend/db/migrations -seq $(NAME)

migrate-force:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make migrate-force VERSION=<version_number>"; \
		exit 1; \
	fi
	$(MIGRATE) -database "$(DB_URL)" -path backend/db/migrations force $(VERSION)

reset-db:
	set -e; docker-compose exec -T postgres psql -U postgres -d global_remit -c "DROP SCHEMA IF EXISTS auth CASCADE; DROP SCHEMA IF EXISTS core CASCADE; DROP SCHEMA IF EXISTS compliance CASCADE; DROP SCHEMA IF EXISTS config CASCADE; DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; DROP TYPE IF EXISTS transaction_status; DROP TYPE IF EXISTS transaction_direction; DROP TYPE IF EXISTS participant_type;"

seed:
	docker-compose exec postgres mkdir -p /seeds
	@for file in backend/db/seeds/reference/*.sql; do \
		echo "Seeding $$file..."; \
		docker-compose cp $$file postgres:/seeds/$$(basename $$file); \
		docker-compose exec -T postgres psql -U postgres -d global_remit -f /seeds/$$(basename $$file); \
	done

install-migrate:
	go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest 