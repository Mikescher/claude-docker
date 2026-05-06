# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker-based wrapper around Claude Code itself. The image bundles a developer toolchain (Go, Node/TS, Python, MongoDB tools, ffmpeg, JDK, …) plus the Claude Code native binary. The `ccc` script in the repo root is the user-facing entry point: it runs `claude --dangerously-skip-permissions` inside the container with the host's CWD bind-mounted as `/workspace`. The script is meant to be symlinked onto `PATH` so `cd <project> && ccc` "just works".

## Build / run

| Command                                | Purpose                                                       |
|----------------------------------------|---------------------------------------------------------------|
| `make build`                           | Build the `claude-docker` image at the current `latest` Claude Code version |
| `make rebuild`                         | Same with `--no-cache`                                        |
| `make build CLAUDE_VERSION=2.1.131`    | Pin a specific Claude Code version                            |
| `make build CLAUDE_VERSION=stable`     | Track the stable channel                                      |
| `bash -n ccc`                          | Syntax-check the wrapper                                      |
| `./ccc -h`                             | Show wrapper flags                                            |
| `./ccc --shell`                        | Drop into bash inside the container (skips the claude binary) |

There is no test suite. The smoke-test pattern is `cd /tmp/somewhere && /path/to/ccc --shell <<<'<command>'`.

## Architecture (the parts that span files)

The three files form a small system held together by three contracts:

1. **`claude_version` image LABEL.** Set from the `CLAUDE_VERSION` build-arg. Drives the startup version check in `ccc` (`docker image inspect` vs. `https://downloads.claude.ai/claude-code-releases/latest`). Channel names like `latest`/`stable` are resolved to a concrete `X.Y.Z` **in the Makefile** before being passed to `docker build`, so the LABEL always names a real release.

2. **Host UID/GID build-args.** Passed in by the Makefile from `id -u`/`id -g`. The `dev` user inside the container is created with these IDs so files written into the bind-mounted workspace and caches end up owned correctly on the host — no chown dance needed.

3. **State mounts.** `~/.claude` (sessions, plugins, settings) and `~/.claude.json` (per-project state) are the two pieces of Claude Code state shared host↔container. The wrapper also forwards `~/.gitconfig` and `~/.ssh` (read-only) and the language caches (Go modules/build, npm, pip, optional `uv`/`cargo`). Hosts paths that don't exist are silently skipped — Docker is not allowed to auto-create them as root.

**`ccc-entrypoint` runs before every command.** The image sets `ENTRYPOINT ["/home/dev/.local/bin/ccc-entrypoint"]`, so both `claude` (the CMD) and `bash -l` (shell mode) are wrapped. The script is the single bootstrap point: if a `.nvmrc` is present in the workdir at startup it sources nvm and runs `nvm install`, otherwise it just `exec "$@"`s. Anything that needs to happen on every container start regardless of mode belongs here.

**Default network is `--network host`.** Host services bound to `127.0.0.1` (e.g. MongoDB on 27017) are reachable as `localhost` from inside the container without further config. `--net` switches to bridge networking and adds `host.docker.internal:host-gateway`.

**Update model is rebuild, not self-update.** The image sets `DISABLE_AUTOUPDATER=1`. Upgrading Claude Code means rerunning `make build`; the version-check prompt in `ccc` is the nudge.

## Things to know when editing

- **Dockerfile layer order is load-bearing** for cache reuse: pacman → mongo tools (still root) → `useradd` → `USER dev` → npm / go / pipx → claude install. Pacman is the heaviest layer; do not move language-tool installs above it. Anything that depends on the `dev` user's `$HOME` must come after the `USER dev` switch.
- **`PATH` precedence in the image** is `~/.npm-global/bin` → `~/.local/bin` → `~/go/bin` → system. So `npm i -g`, `pipx install`, and `go install` all land on `PATH` automatically; pacman packages need no extra setup.
- **MongoDB tools** are fetched as a tarball from `fastdl.mongodb.org` because Arch's repos don't carry them. The `rhel88-x86_64` build is the one that works on Arch; the older `rhel80` URLs now 404. Bump `MONGO_TOOLS_VERSION` in the Dockerfile to update.
- **Version-check timeout in `ccc` is intentionally 1 s.** The endpoint typically responds in ~230 ms; raising the timeout regresses cold-start. The check also no-ops on a non-TTY stdin so piped invocations stay clean.
- **Empty-array expansion in `ccc`** uses `${forwarded_args[@]+"${forwarded_args[@]}"}`. The `+` form is required because of `set -u` — don't simplify it.
- **`~/.claude/settings.json` overlay.** The host's settings file is mounted on top of the container's empty `~/.claude`, so any env vars set there take effect inside. The Dockerfile's `ENV DISABLE_AUTOUPDATER=1` is a belt-and-suspenders default for users without that key.
- **nvm is installed but inert by default.** The toolchain ships system Node from pacman; `node`/`npm` resolve to that. nvm is sourced only by `ccc-entrypoint` when the workdir has a `.nvmrc` (and by `.bashrc` so the `nvm` function is reachable interactively in shell mode). Both call sites `unset NPM_CONFIG_PREFIX` first because nvm refuses to load otherwise — the pre-installed npm globals stay reachable because `~/.npm-global/bin` is hard-coded into `PATH`, independent of the prefix var.
