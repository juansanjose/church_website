# Parroquia San Pablo de la Cruz — Static Site Makefile
# ======================================================

HUGO_VERSION := 0.159.2
SITE_DIR := site
HUGO_CACHEDIR := $(CURDIR)/.hugo_cache
DEPLOY_HOST := moneymachine
DEPLOY_USER := root
DEPLOY_PATH := /var/www/sanpablodelacruz.com

.PHONY: help build serve clean deploy migrate archive rollback

help:
	@echo "Available targets:"
	@echo "  make build      Build the static site with Hugo"
	@echo "  make serve      Run local Hugo dev server"
	@echo "  make clean      Remove generated files"
	@echo "  make migrate    Convert WordPress SQL to Hugo Markdown"
	@echo "  make archive    Archive legacy WordPress code"
	@echo "  make deploy     Deploy to VPS via rsync (requires SSH access)"
	@echo "  make rollback   Rollback to previous deploy on VPS"

build:
	cd $(SITE_DIR) && HUGO_CACHEDIR=$(HUGO_CACHEDIR) hugo --minify --gc

serve:
	cd $(SITE_DIR) && HUGO_CACHEDIR=$(HUGO_CACHEDIR) hugo server --bind 0.0.0.0 --port 8080 --buildDrafts

clean:
	rm -rf $(SITE_DIR)/public $(HUGO_CACHEDIR)

migrate:
	python3 migration/scripts/wordpress_to_hugo.py

archive:
	bash scripts/archive-wordpress.sh

deploy: build
	rsync -avz --delete $(SITE_DIR)/public/ $(DEPLOY_USER)@$(DEPLOY_HOST):$(DEPLOY_PATH)/

rollback:
	bash scripts/rollback.sh previous

# Legacy WordPress targets (preserved for reference)
wp-up:
	@echo "WordPress environment removed. Use 'make serve' for Hugo dev server."
