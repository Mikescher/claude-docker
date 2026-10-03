# Claude-Code-Container ( ./ccc )

A small helper script which allows me to quickly start a containerized claude code in a directory

## Args

- `--mount-parent`: Mount parent-dir into container (except current dir)
- `--net`: Run in docker network (instead of host network)
- `--shell`: Run a bash shell instead of claude-code
- `--chrome`: Start the host chrome right away instead of on first use
- `--no-chrome`: Do not front `127.0.0.1:9222` with the lazy chrome broker
- `--no-android`: No android emulator relay and no mobile-mcp

## Installed tools

- basics (git, curl, ffmpeg, make, ...)
- golang development tools
- dotnet development tools
- java
- Android SDK + Flutter
- node (plus automatic nvm)
- python
- Docker (docker-in-docker)
- database clients (postgres/psql, mongodb tools)

## Mounted volumes (plus current work dir)

- `~/.claude`
- `~/go/pkg`
- `~/.cache/go-build`
- `~/.npm`
- `~/.cache/pip`

## Other features

- Forward `notify-send` to host
- Chrome for the chrome-devtools MCP starts on first use (needs `socat`)
- Android emulators run on the host and are started from inside via `ccc-emulator` / `emulator` / `flutter emulators --launch`; mobile-mcp drives them (needs `socat` and an Android SDK with the emulator on the host)
- Mounts directory at same path in container as it was outside
- Container user matches user who build image
- Container name matches directory
- Auto-check claude-code version on startup

## Closing Remarks

This is almost 100% only made for me and my setup.  
Don't know how useful that will be for anyone else.