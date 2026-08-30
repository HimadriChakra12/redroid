.PHONY: image up setup provision strip run stop shell logs clean

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
