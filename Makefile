# Makefile for Homebrew Tap
#
# Provides standard entry points for local validation, matching the CI checks
# that run on every PR. The actual `brew` commands require macOS, so these
# targets gracefully degrade on Linux.
#
# Targets:
# - test:      Run brew audit --strict --online on all formulas
# - lint:      Run brew style on all formulas and casks
# - test-bump: Offline fixture tests for the release-bump script
# - bump-dry:  Show what the release-bump automation would do right now
# - check:     Run test, lint and test-bump

FORMULAS := $(wildcard Formula/*.rb)
CASKS := $(wildcard Casks/*.rb)

.PHONY: test lint check syntax test-bump bump-dry

check: test lint test-bump

syntax:
	@echo "Checking Formula syntax..."
	@for f in $(FORMULAS); do ruby -c "$$f" || exit 1; done
	@echo "Checking Cask syntax..."
	@for f in $(CASKS); do ruby -c "$$f" || exit 1; done

test: syntax
	@echo "Running brew audit on formulas..."
	@for f in $(FORMULAS); do \
		formula=$$(basename "$$f" .rb); \
		brew audit --strict --online "$$formula" || exit 1; \
	done

lint: syntax
	@echo "Running brew style..."
	@brew style Formula Casks

test-bump:
	@echo "Running tap-bump fixture tests..."
	@sh scripts/ruby.sh scripts/test-tap-bump.rb

bump-dry:
	@sh scripts/ruby.sh scripts/tap-bump.rb --dry-run
