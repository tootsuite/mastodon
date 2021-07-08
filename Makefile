DOCKER_IMAGE_DEV ?= "tootsuite/mastodon:development"
DOCKER_IMAGE_PROD ?= "tootsuite/mastodon:production"
DOCKER_PROJECT = $(shell basename "$$PWD")
UNAME_S := $(shell uname -s)
UID ?= "991"
GID ?= "991"
NPROC = 1

# Hide the annoying docker snyk ad
export DOCKER_SCAN_SUGGEST=false

ifeq ($(UNAME_S),Linux)
	NPROC = $(shell nproc)
	UID=`id -u ${USER}`
	GID=`id -g ${USER}`
endif
ifeq ($(UNAME_S),Darwin)
	NPROC = $(shell sysctl -n hw.ncpu)
endif

up:
ifeq (,$(wildcard .docker-db-initialized))
	@echo "Database has not been initialized, running init script..."
	make init
else
	make install
endif
	docker-compose -f docker-compose.local.yml up

init: install
	docker-compose -f docker-compose.local.yml run --rm sidekiq bash -c "\
		bundle exec rails db:environment:set RAILS_ENV=development &&\
		bundle exec rails db:setup RAILS_ENV=development &&\
		bundle exec rails db:migrate RAILS_ENV=development"
	docker-compose -f docker-compose.local.yml down
	touch .docker-db-initialized
	@echo "\nMastodon initialization finished! You can now start all containers using: $ make up"

down:
	docker-compose -f docker-compose.local.yml down

clean:
	docker-compose -f docker-compose.local.yml down
	docker volume rm -f $(DOCKER_PROJECT)_db $(DOCKER_PROJECT)_redis
	rm .docker-db-initialized


install: build-development
	docker-compose -f docker-compose.local.yml down
	docker-compose -f docker-compose.local.yml up -d db
	docker-compose -f docker-compose.local.yml run --rm webpack bash -c "\
		bundle install -j$(NPROC) && \
		yarn install --pure-lockfile"

build-development:
	DOCKER_BUILDKIT=1 \
	docker build --target development \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--tag $(DOCKER_IMAGE_DEV) .

build-production:
	DOCKER_BUILDKIT=1 \
	docker build --target production \
		--tag $(DOCKER_IMAGE_PROD) .
