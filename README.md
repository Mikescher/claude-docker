# Claude-Code-Container ( ./ccc )

A small helper script which allows me to quickly start a containerized claude code in a directory

## Args

- `--mount-parent`: Mount parent-dir into container (except current dir)
- `--net`: Run in docker network (instead of host network)
- `--shell`: Run a bash shell instead of claude-code

## Installed tools

- basics (fit, curl, ffmpeg, make, )
- golang development tools
- dotnet development tools
- java
- node (plus automatic nvm)
- python
- Docker (docker-in-docker)

## Mounted volumes (plus current work dir)

- `~/.claude`
- `~/go/pkg`
- `~/.cache/go-build`
- `~/.npm`
- `~/.cache/pip`

## Other features

- Forward `notify-send` to host
- Mounts directory at same path in container as it was outside
- Container user matches user who build image
- Container name matches directory
- Auto-check claude-code version on startup

## Closing Remarks

This is almost 100% only made for me and my setup.  
Don't know how useful that will be for anyone else.