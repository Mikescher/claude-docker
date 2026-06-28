IMAGE          ?= claude-docker
CLAUDE_VERSION ?= latest
UID            := $(shell id -u)
GID            := $(shell id -g)
USERNAME       ?= $(shell id -un)

define resolve_and_build
	VERSION=$$( \
	  case "$(CLAUDE_VERSION)" in \
	    latest|stable) curl -fsSL --max-time 5 "https://downloads.claude.ai/claude-code-releases/$(CLAUDE_VERSION)" ;; \
	    *) printf '%s' "$(CLAUDE_VERSION)" ;; \
	  esac); \
	if [ -z "$$VERSION" ]; then echo "failed to resolve CLAUDE_VERSION=$(CLAUDE_VERSION)" >&2; exit 1; fi; \
	echo ">> building $(IMAGE) with Claude Code $$VERSION (USERNAME=$(USERNAME), UID=$(UID), GID=$(GID))"; \
	docker build $(1) \
	  --build-arg USERNAME=$(USERNAME) \
	  --build-arg UID=$(UID) \
	  --build-arg GID=$(GID) \
	  --build-arg CLAUDE_VERSION=$$VERSION \
	  --tag "autoprune-keep" \
	  -t $(IMAGE) .
endef

build:
	@$(call resolve_and_build,)

rebuild:
	@$(call resolve_and_build,--no-cache)

.PHONY: build rebuild
