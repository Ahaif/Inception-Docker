SRC=srcs

.PHONY: all build up down clean secrets dirs

all: build up

dirs:
	@mkdir -p ~/data/db ~/data/www
	@if [ "$$(stat -c '%U' ~/data/db)" != "$$USER" ]; then \
		echo "Fixing ownership of ~/data/db and ~/data/www..."; \
		sudo chown -R "$$USER:$$USER" ~/data/db ~/data/www; \
	fi
	@echo "Data directories: OK (owner: $$USER)"

secrets:
	@echo "Creating secrets directory at ~/secrets ..."
	@mkdir -p ~/secrets && chmod 700 ~/secrets
	@if [ ! -f ~/secrets/mysql_root_password ]; then \
		printf "Enter MariaDB root password: "; \
		read -r p; \
		printf '%s' "$$p" > ~/secrets/mysql_root_password; \
		chmod 600 ~/secrets/mysql_root_password; \
		echo "  -> mysql_root_password saved."; \
	else \
		echo "  mysql_root_password already exists, skipping."; \
	fi
	@if [ ! -f ~/secrets/mysql_password ]; then \
		printf "Enter MariaDB wp_user password: "; \
		read -r p; \
		printf '%s' "$$p" > ~/secrets/mysql_password; \
		chmod 600 ~/secrets/mysql_password; \
		echo "  -> mysql_password saved."; \
	else \
		echo "  mysql_password already exists, skipping."; \
	fi
	@if [ ! -f ~/secrets/wp_admin_password ]; then \
		printf "Enter WordPress admin password: "; \
		read -r p; \
		printf '%s' "$$p" > ~/secrets/wp_admin_password; \
		chmod 600 ~/secrets/wp_admin_password; \
		echo "  -> wp_admin_password saved."; \
	else \
		echo "  wp_admin_password already exists, skipping."; \
	fi
	@echo "Secrets ready."

build:
	@echo "Building images..."
	cd $(SRC) && docker compose -f docker-compose.yml build

up:
	@echo "Starting services..."
	cd $(SRC) && docker compose -f docker-compose.yml up -d

down:
	@echo "Stopping services..."
	cd $(SRC) && docker compose -f docker-compose.yml down

clean:
	@echo "Removing images (local)"
	cd $(SRC) && docker compose -f docker-compose.yml down --rmi local --volumes --remove-orphans
