.PHONY: image up setup provision strip run stop shell logs clean push install-push launch install-launch

REPO_DIR := $(CURDIR)
PREFIX   ?= /usr/local
DESKTOP_DIR := $(HOME)/.local/share/applications

image:    ## Build the local redroid+MindTheGapps image (slow, run once / on updates)
	@bash scripts/build-image.sh

up:       ## Start the container against ~/.droid
	@bash scripts/up.sh

provision: ## Sideload Aurora Store, Fennec, Bare Browser
	@bash scripts/provision.sh

strip:    ## Remove the default apps listed in config/apps-remove.list
	@bash scripts/strip.sh

setup: up provision strip  ## Full first-run: boot + install curated apps + strip defaults

run: up   ## Launch the scrcpy display window (freeform enabled)
	@bash scripts/run-display.sh

push: ## Build the standalone droid-push binary (src/droid-push.c)
	@$(CC) -Wall -Wextra -O2 -o push src/push.c

install-push: push ## Build + install droid-push to ~/.local/bin (must be on PATH)
	@sudo install -Dm755 push $(PREFIX)/bin/push
	@echo "installed push"

launch: ## Build the droid-launch binary (src/launch.c), repo path baked in
	@$(CC) -Wall -Wextra -O2 -DREPO_DIR=\"$(REPO_DIR)\" -o droid-launch src/launch.c

install-launch: launch ## Build + install droid-launch and a .desktop entry
	@sudo install -Dm755 droid-launch $(PREFIX)/bin/droid-launch
	@install -Dm644 droid.desktop $(DESKTOP_DIR)/droid.desktop
	@sed -i "s|^Exec=.*|Exec=$(PREFIX)/bin/droid-launch|" $(DESKTOP_DIR)/droid.desktop
	@update-desktop-database $(DESKTOP_DIR) 2>/dev/null || true
	@echo "installed droid-launch to $(PREFIX)/bin, droid.desktop to $(DESKTOP_DIR)"

install: install-launch install-push

stop:     ## Stop the container (keeps ~/.droid and the image)
	@bash scripts/down.sh

shell: up ## Drop into an adb shell inside the container
	@adb -s 127.0.0.1:5555 shell

logs:     ## Follow the container's docker logs
	@docker logs -f droid

clean: stop ## Stop and remove the container (keeps ~/.droid and the image)
	@docker rm droid >/dev/null 2>&1 || true

help:
	@grep -E '^[a-zA-Z_-]+:.*##' Makefile | sed 's/:.*##/ - /'
