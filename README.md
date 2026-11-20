# Claude-Code-Container ( ./ccc )

A small helper script which allows me to quickly start a containerized claude code in a directory

## Args

- `--mount DIR` / `--mount-ro DIR`: Additionally mount DIR (read-write / read-only) at the same path; repeatable
- `--mount-parent`: Mount the parent dir instead of only the current dir (automatic for git worktrees whose gitdir lives in the parent)
- `--net`: Run in docker network (instead of host network)
- `--shell`: Run a bash shell instead of claude-code
- `--chrome`: Start the host chrome right away instead of on first use
- `--no-chrome`: Do not front `127.0.0.1:9222` with the lazy chrome broker
- `--no-android`: No android emulator relay and no mobile-mcp
- `--no-docker`: Do not forward the host's docker socket
- `--no-cache`: Do not mount the language caches
- `--no-claude-temp`: Do not mount claude's per-project temp dir
- `--no-cpu-limit` / `--no-memory-limit` / `--no-limit`: Drop the default limits (host CPUs - 2, host RAM - 8 GiB)
- `--no-version-check`: Skip the claude-code version check

Everything else is passed on to `claude` (which always runs with `--dangerously-skip-permissions`); `--` ends ccc's own flags.

## Installed tools

- basics (git, gitea-cli, curl, ffmpeg, make, restic, pdftk, ...)
- golang development tools
- rust
- dotnet development tools (latest + 9.0)
- java (OpenJDK 11/17/latest, Temurin 21/25, ant, maven, ivy; per project via `.java-version`)
- Android SDK + Flutter
- node + bun (plus automatic nvm via `.nvmrc`)
- python
- php + composer
- godot
- Docker CLI (talks to the host's daemon)
- database clients (postgres/psql, mongodb tools)

## Mounted from the host (plus current work dir)

- `~/.claude`, `~/.claude.json`
- `~/.gitconfig` (read-only; `~/.gitconfig-ccc` wins if it exists)
- `~/.config/gitea-cli`
- `/var/run/docker.sock`
- claude's per-project temp dir (`/tmp/claude-<uid>/<cwd-slug>`)
- language caches: `~/go/pkg`, `~/.cache/go-build`, `~/.npm`, `~/.nvm`, `~/.cache/pip`, `~/.cache/uv`, `~/.cargo`, `~/.nuget`, `~/.gradle`, `~/.pub-cache`, `~/.ant`, `~/.ivy2`
- read-only: `~/.jdks`, `~/.android/debug.keystore`, vim config, `/opt/google/chrome`

Paths that don't exist on the host are skipped.

## Other features

- Forward `notify-send` to host
- Wayland clipboard (image paste in claude-code)
- Chrome for the chrome-devtools MCP starts on first use (needs `socat`)
- Android emulators run on the host and are started from inside via `ccc-emulator` / `emulator` / `flutter emulators --launch`; mobile-mcp drives them (needs `socat` and an Android SDK with the emulator on the host)
- Mounts directory at same path in container as it was outside
- Host network by default, so services on the host's `127.0.0.1` are reachable as `localhost`
- Container user matches user who build image
- Container name matches directory
- Auto-check claude-code version on startup

## Project config (`.claude-docker`)

An optional JSON file in the directory `ccc` is started from:

```json
{
  "automount": ["../clubscale-adminpanel", "../clubscale-app"],
  "automount-ro": ["../shared-docs"],
  "java-version": "21",
  "node-version": "20"
}
```

- `automount` / `automount-ro`: extra directories to mount read-write / read-only (relative to the project dir). `ccc` lists them and asks once `Mount them? [Y/n]` before starting.
- `java-version` / `node-version`: like `.java-version` / `.nvmrc`, and take precedence over them.

## Closing Remarks

This is almost 100% only made for me and my setup.  
Don't know how useful that will be for anyone else.
