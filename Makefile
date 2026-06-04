SRC=srcs

.PHONY: all build up down clean

all: build up

build:
	@echo "Building images..."
	cd $(SRC) && docker-compose -f docker-compose.yml build

up:
	@echo "Starting services..."
	cd $(SRC) && docker-compose -f docker-compose.yml up -d

down:
	@echo "Stopping services..."
	cd $(SRC) && docker-compose -f docker-compose.yml down

clean:
	@echo "Removing images (local)"
	cd $(SRC) && docker-compose -f docker-compose.yml down --rmi local --volumes --remove-orphans
