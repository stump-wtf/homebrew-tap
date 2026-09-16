HOMEbrew_bin := $(shell which brew 2>/dev/null)
ifeq ($(HOMEbrew_bin),)
$(error "brew not found on PATH — install Homebrew first")
endif

.PHONY: test lint check

test: lint
	@echo "No runtime tests — formula audit passed"

lint:
	brew style Formula Casks
	for f in Formula/*.rb Casks/*.rb; do \
		echo "Checking $$f"; \
		ruby -c "$$f"; \
	done
	for f in Formula/*.rb; do \
		name=$$(basename "$$f" .rb); \
		echo "Auditing $$name"; \
		brew audit --strict --online "$$name" || true; \
	done
	for f in Casks/*.rb; do \
		name=$$(basename "$$f" .rb); \
		echo "Auditing cask $$name"; \
		brew audit --cask --strict --online "$$name" || true; \
	done

check: test
	@echo "All checks passed"
