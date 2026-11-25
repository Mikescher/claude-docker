FROM archlinux:base-devel

ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
ARG CLAUDE_VERSION=latest

LABEL claude_version="${CLAUDE_VERSION}"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    EDITOR=vim \
    DISABLE_AUTOUPDATER=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global \
    GOPATH=/home/${USERNAME}/go \
    ANDROID_HOME=/home/${USERNAME}/Android/Sdk \
    ANDROID_SDK_ROOT=/home/${USERNAME}/Android/Sdk \
    PATH=/home/${USERNAME}/.npm-global/bin:/home/${USERNAME}/.local/bin:/home/${USERNAME}/go/bin:/home/${USERNAME}/.cargo/bin:/home/${USERNAME}/flutter/bin:/home/${USERNAME}/.pub-cache/bin:/home/${USERNAME}/Android/Sdk/cmdline-tools/latest/bin:/home/${USERNAME}/Android/Sdk/platform-tools:/usr/local/bin:/usr/bin:/bin

RUN pacman -Syu --noconfirm --needed \
        git gitea-cli curl wget openssh \
        ripgrep fd jq tmux less vim nano \
        unzip zip tar which man-db bash-completion \
        shellcheck mkvtoolnix-cli \
        sudo ca-certificates gnupg \
        cmake pkgconf ninja clang gtk3 mesa-utils \
        docker docker-buildx docker-compose \
        ffmpeg wl-clipboard libpulse \
        sway xorg-xwayland grim wayvnc xdotool python-pywayland wlr-protocols \
        restic \
        postgresql \
        jdk-openjdk jdk17-openjdk jdk11-openjdk ant maven \
        dotnet-sdk \
        aspnet-targeting-pack \
        godot \
        go gopls delve golangci-lint \
        rust rust-analyzer \
        nodejs npm bun \
        python python-pip python-pipx \
        php composer \
 && pacman -Scc --noconfirm

ARG MONGO_TOOLS_VERSION=100.16.1
RUN curl -fsSL "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-rhel88-x86_64-${MONGO_TOOLS_VERSION}.tgz" \
    | tar xz -C /usr/local/bin --strip-components=2 --wildcards '*/bin/*'

# Eclipse Temurin 21 & 25 (Adoptium). Not in Arch's official repos — only the
# AUR, which this image has no helper for — so each is fetched as the upstream
# tarball (same pattern as MongoDB tools / Android cmdline-tools) into the
# standard /usr/lib/jvm tree so they sit alongside the pacman JDKs. Two majors
# are kept: 21 fills a gap (no jdk21-openjdk in Arch's repos), and 25 pins that
# release so it survives pacman's jdk-openjdk advancing to a newer default. The
# system default (archlinux-java) is left on jdk-openjdk; reach these builds via
# JAVA_21_HOME/JAVA_25_HOME, or select one per-project with a .java-version file
# (see ccc-entrypoint). Bump TEMURIN_<major>_VERSION/SHA256 from api.adoptium.net
# (feature_releases/<major>/ga).
ARG TEMURIN_21_VERSION=21.0.11+10
ARG TEMURIN_21_SHA256=4b2220e232a97997b436ca6ab15cbf70171ecff52958a46159dfa5a8c44ca4de
ENV JAVA_21_HOME=/usr/lib/jvm/java-21-temurin
RUN ver="${TEMURIN_21_VERSION%+*}" build="${TEMURIN_21_VERSION#*+}" \
 && url="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${TEMURIN_21_VERSION//+/%2B}/OpenJDK21U-jdk_x64_linux_hotspot_${ver}_${build}.tar.gz" \
 && curl -fsSL "$url" -o /tmp/temurin21.tar.gz \
 && echo "${TEMURIN_21_SHA256}  /tmp/temurin21.tar.gz" | sha256sum -c - \
 && mkdir -p "$JAVA_21_HOME" \
 && tar xz -C "$JAVA_21_HOME" --strip-components=1 -f /tmp/temurin21.tar.gz \
 && rm -f /tmp/temurin21.tar.gz

ARG TEMURIN_25_VERSION=25.0.3+9
ARG TEMURIN_25_SHA256=69264a7a211bf5029830d07bc3370f879769d62ebc5b5488e90c9343a2da0e1f
ENV JAVA_25_HOME=/usr/lib/jvm/java-25-temurin
RUN ver="${TEMURIN_25_VERSION%+*}" build="${TEMURIN_25_VERSION#*+}" \
 && url="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-${TEMURIN_25_VERSION//+/%2B}/OpenJDK25U-jdk_x64_linux_hotspot_${ver}_${build}.tar.gz" \
 && curl -fsSL "$url" -o /tmp/temurin25.tar.gz \
 && echo "${TEMURIN_25_SHA256}  /tmp/temurin25.tar.gz" | sha256sum -c - \
 && mkdir -p "$JAVA_25_HOME" \
 && tar xz -C "$JAVA_25_HOME" --strip-components=1 -f /tmp/temurin25.tar.gz \
 && rm -f /tmp/temurin25.tar.gz

# Apache Ivy — not in Arch's official repos, and the AUR package is unmaintained
# and no longer builds. Fetched as the upstream binary tarball (same pattern as
# MongoDB tools / Temurin above) and dropped in as a plain jar; a wrapper on PATH
# launches it. The prebuilt jar is Java 8 bytecode so it runs on any JDK, but it
# still bundles Pack200 (dropped from the JDK in 14) and reaches Thread.stop()
# (dropped in 23), so the wrapper pins it to jdk11-openjdk to keep every code
# path working — the system default JDK is left untouched (see the Temurin note).
# Bump IVY_VERSION/SHA512 from https://dlcdn.apache.org/ant/ivy/.
ARG IVY_VERSION=2.6.0
ARG IVY_SHA512=120f6ab52fcced55dea59dcd3f2ad8f80143922a919b20e625593b8ef02314f092c00d7ec28ddc75c9df01d63c684cdfb4e2799c8324eff928503cc1e470a526
RUN curl -fsSL "https://dlcdn.apache.org/ant/ivy/${IVY_VERSION}/apache-ivy-${IVY_VERSION}-bin.tar.gz" -o /tmp/ivy.tar.gz \
 && echo "${IVY_SHA512}  /tmp/ivy.tar.gz" | sha512sum -c - \
 && mkdir -p /opt/apache-ivy \
 && tar xz -C /opt/apache-ivy --strip-components=1 -f /tmp/ivy.tar.gz "apache-ivy-${IVY_VERSION}/ivy-${IVY_VERSION}.jar" \
 && mv "/opt/apache-ivy/ivy-${IVY_VERSION}.jar" /opt/apache-ivy/ivy.jar \
 && printf '%s\n' '#!/bin/sh' 'exec /usr/lib/jvm/java-11-openjdk/bin/java -jar /opt/apache-ivy/ivy.jar "$@"' > /usr/local/bin/ivy \
 && chmod +x /usr/local/bin/ivy \
 && rm -f /tmp/ivy.tar.gz

# pdftk — Arch dropped the original (GCJ-only) pdftk long ago; what's packaged
# today is pdftk-java, and only in the AUR, which this image has no helper for.
# Fetched as the upstream fat jar from the project's GitLab generic package
# registry (same pattern as Ivy above) with a wrapper on PATH that runs it on
# the system default JDK — pdftk-java is plain Java 8+ bytecode with no JDK
# internals, so it needs no pinned runtime. Bump PDFTK_VERSION/SHA256 from
# https://gitlab.com/pdftk-java/pdftk/-/releases.
ARG PDFTK_VERSION=3.3.2
ARG PDFTK_SHA256=497a3c5ab1c0b3882f372d40c1c04ab0e0a7a3317067b55a794669ea6a91bedd
RUN curl -fsSL "https://gitlab.com/api/v4/projects/5024297/packages/generic/pdftk-java/v${PDFTK_VERSION}/pdftk-all.jar" -o /bin/pdftk.jar \
 && echo "${PDFTK_SHA256}  /bin/pdftk.jar" | sha256sum -c - \
 && printf '%s\n' '#!/usr/bin/env sh' 'exec java -jar /bin/pdftk.jar "$@"' > /bin/pdftk \
 && chmod +x /bin/pdftk

RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# Entrypoint lives at a stable system path so ENTRYPOINT (JSON exec form) does
# not need build-arg substitution. Written as root before the USER switch.
RUN cat > /usr/local/bin/ccc-entrypoint <<'EOF' && chmod +x /usr/local/bin/ccc-entrypoint
#!/usr/bin/env bash
# .claude-docker's "node-version" / "java-version" outrank .nvmrc / .java-version.
cfg_node="" cfg_java=""
if [[ -f .claude-docker ]]; then
  cfg_node=$(jq -r '."node-version" // empty' .claude-docker 2>/dev/null)
  cfg_java=$(jq -r '."java-version" // empty' .claude-docker 2>/dev/null)
fi

if [[ -n $cfg_node || -f .nvmrc ]]; then
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    unset NPM_CONFIG_PREFIX
    . "$NVM_DIR/nvm.sh"
    nvm install ${cfg_node:+"$cfg_node"} || echo "ccc-entrypoint: nvm install failed; falling back to system node" >&2
  fi
fi

# .java-version (jenv/jabba/sdkman convention) or .claude-docker's
# "java-version": switch the active JDK to match, like .nvmrc does for node.
# Content is a version such as "25", "21", "17",
# "1.8" or a full "25.0.3" — we match on the *major* version against the JDKs
# installed under /usr/lib/jvm (java-<major>-openjdk and the Temurin builds).
# A vendor may be named to force a specific build when a major has more than one
# (both java-25-openjdk and java-25-temurin exist): "temurin-25" / "25-temurin"
# / sdkman's "25-tem" pick Temurin, "openjdk-25" picks the pacman JDK. A bare
# version takes the first java-<major>-* match (openjdk sorts before temurin).
# On a bad or unmatched version it falls back to the system default, but
# loudly: an error is printed and the start pauses 2s so the message is seen
# before claude takes over the terminal.
java_src=""
if [[ -n $cfg_java ]]; then
  java_src=.claude-docker raw=${cfg_java//[[:space:]]/}
elif [[ -f .java-version ]]; then
  java_src=.java-version raw=$(tr -d '[:space:]' < .java-version)
fi
if [[ -n $java_src ]]; then
  vendor='*'                          # bare version -> first java-<major>-* wins
  case ${raw,,} in
    *temurin*|*-tem) vendor=temurin ;;
    *openjdk*|*-open) vendor=openjdk ;;
  esac
  jv=${raw//[!0-9.]/}                 # strip any vendor tag down to the number
  jv=${jv#.}; jv=${jv%.}             # drop stray dots a tag may have left
  [[ $jv == 1.* ]] && jv=${jv#1.}    # legacy "1.8" -> "8"
  major=${jv%%.*}
  jdk=""
  if [[ -n $major ]]; then
    for d in /usr/lib/jvm/java-"$major"-$vendor; do
      [[ -d $d ]] && jdk=$d && break
    done
  fi
  if [[ -n $jdk ]]; then
    export JAVA_HOME="$jdk"
    export PATH="$jdk/bin:$PATH"
  else
    echo "ccc-entrypoint: no JDK matching $java_src ($raw) installed; keeping system default" >&2
    sleep 2
  fi
fi

# chrome-devtools-mcp ships configured to spawn its own Chrome, which can't
# work in this container (no display, no chrome binary). Re-point it at
# 127.0.0.1:9222 on the shared host network, where `ccc` keeps a lazy broker
# that starts a host Chrome on the first connection. The port is a contract
# with the wrapper's chrome_broker_port — change both or neither.
# Idempotent (skips when the flag is already present); re-applies after
# plugin updates wipe the marketplace cache.
mcp_cfg="$HOME/.claude/plugins/cache/claude-plugins-official/chrome-devtools-mcp/latest/.claude-plugin/plugin.json"
if [[ -f "$mcp_cfg" ]] && ! grep -q 'browser-url' "$mcp_cfg"; then
  tmp=$(mktemp) && jq '.mcpServers["chrome-devtools"].args += ["--browser-url=http://127.0.0.1:9222"]' "$mcp_cfg" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$mcp_cfg" \
    || { rm -f "$tmp"; echo "ccc-entrypoint: failed to patch chrome-devtools-mcp config" >&2; }
fi

# mobile-mcp drives the host's Android emulators, so it is only registered
# when ccc mounted its emulator relay. --mcp-config is variadic: it must be
# followed by an option, or it would swallow a prompt as a second config.
mobile_mcp_cfg=/etc/ccc/mobile-mcp.json
if [[ "${1:-}" == claude && "${2:-}" == -* && -d /run/ccc-android && -f "$mobile_mcp_cfg" ]]; then
  set -- "$1" --mcp-config "$mobile_mcp_cfg" "${@:2}"
fi

exec "$@"
EOF

# playwright
RUN npx playwright install chromium

# notify-send shim: forwards args (NUL-separated) to a FIFO bind-mounted from
# the host. The host side of ccc runs a tiny bash reader that pipes them into
# the host's real notify-send. This avoids exposing the dbus session bus to
# the container — only desktop notifications round-trip, nothing else.
# If the FIFO is missing (host has no notify-send, or run outside ccc), the
# shim silently no-ops so callers don't see errors.
RUN cat > /usr/local/bin/notify-send <<'EOF' && chmod +x /usr/local/bin/notify-send
#!/usr/bin/env bash
fifo=/run/ccc-notify.fifo
[[ -p "$fifo" ]] || exit 0
[[ $# -eq 0 ]] && exit 0
printf '%s\0' "$@" > "$fifo" 2>/dev/null || true
EOF

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# .NET SDK 9.0 from AUR — pulls Microsoft's official tarball and installs
# side-by-side under /usr/share/dotnet/sdk/<version>/, coexisting with the
# latest `dotnet-sdk` from the official repo. The git repo is the *pkgbase*
# (`dotnet-core-9.0-bin`), not the per-package name; one PKGBUILD produces
# runtime, aspnet-runtime, both targeting-packs, and sdk as split outputs,
# all installed together by `makepkg -i`. `dotnet-host` and `netstandard-
# targeting-pack` come in transitively from the official `dotnet-sdk` above.
RUN git clone --depth 1 https://aur.archlinux.org/dotnet-core-9.0-bin.git /tmp/dotnet-core-9.0-bin \
 && cd /tmp/dotnet-core-9.0-bin \
 && makepkg -si --noconfirm \
 && rm -rf /tmp/dotnet-core-9.0-bin

# makepkg -si shelled out to `sudo pacman -U` for the dotnet packages,
# repopulating the pacman cache with root-owned files; this RUN executes as
# ${USERNAME}, so the cleanup needs sudo (NOPASSWD).
RUN sudo rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

RUN mkdir -p \
      /home/${USERNAME}/.npm-global \
      /home/${USERNAME}/.npm \
      /home/${USERNAME}/.local/bin \
      /home/${USERNAME}/.cache/go-build \
      /home/${USERNAME}/.cache/pip \
      /home/${USERNAME}/.cache/uv \
      /home/${USERNAME}/go/bin \
      /home/${USERNAME}/go/pkg \
      /home/${USERNAME}/.cargo/bin

RUN npm install -g typescript ts-node yarn pnpm eslint prettier @angular/cli mongosh

RUN go install honnef.co/go/tools/cmd/staticcheck@latest \
 && go install mvdan.cc/gofumpt@latest

RUN pipx install black \
 && pipx install ruff \
 && pipx install mypy \
 && pipx install pytest \
 && pipx install httpie

# Android SDK. Google ships the command-line tools as a bare zip that must be
# relocated to $ANDROID_HOME/cmdline-tools/latest/ for sdkmanager to resolve
# the rest of the SDK. Licenses are accepted non-interactively at build time
# so gradle builds don't stall on a prompt. sdkmanager is a Java app and the
# image's default JDK is newer than it expects, so it's run under JDK 17 (the
# version the Android Gradle Plugin also wants). The build-number in the
# cmdline-tools URL is exact — bump it from the newest entry in
# https://dl.google.com/android/repository/repository2-3.xml when updating.
# Package names carry a literal `;` (e.g. "platforms;android-36"), a shell
# metacharacter, so they're quoted here rather than passed through an ARG.
ARG ANDROID_CMDLINE_TOOLS_VERSION=13114758
ENV JAVA_17_HOME=/usr/lib/jvm/java-17-openjdk
RUN curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/cmdline-tools.zip \
 && mkdir -p "$ANDROID_HOME/cmdline-tools" \
 && unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools" \
 && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
 && rm /tmp/cmdline-tools.zip \
 && yes | JAVA_HOME="$JAVA_17_HOME" sdkmanager --licenses >/dev/null \
 && JAVA_HOME="$JAVA_17_HOME" sdkmanager \
      "platform-tools" \
      "platforms;android-36" "platforms;android-35" \
      "build-tools;36.0.0" "build-tools;35.0.0" >/dev/null

# Flutter SDK (stable channel). The bundled Dart SDK and the Android build
# engine are fetched into the SDK's own cache via precache so the first real
# build is offline-ready — only `--android`, not `--universal`, since the
# iOS/macOS/Windows/web/Fuchsia engines are dead weight in a Linux/Android
# container. Flutter is configured to use the JDK 17 install for Android (its
# Gradle invocations don't support the image's newer default JDK) and the SDK
# above. It lives under $HOME because flutter writes into its own tree at
# runtime (bin/cache), which a root-owned /opt install would forbid.
#
# precache downloads have no client-side timeout, so a stalled CDN connection
# would hang the build forever; it's wrapped in timeout+retry and is
# best-effort (a failed precache just means the first real build re-fetches
# online), so the loop never fails the layer. `flutter doctor` is the
# build-time sanity check that the toolchain actually resolves.
ARG FLUTTER_CHANNEL=stable
RUN git clone --depth 1 -b ${FLUTTER_CHANNEL} https://github.com/flutter/flutter.git /home/${USERNAME}/flutter \
 && flutter config --jdk-dir="$JAVA_17_HOME" \
 && flutter config --android-sdk "$ANDROID_HOME" \
 && for i in 1 2 3; do timeout 900 flutter precache --android && break || echo "ccc-build: flutter precache attempt $i failed/timed out, retrying"; done \
 && (timeout 240 flutter doctor || true)

ARG NVM_VERSION=v0.40.4
ENV NVM_DIR=/home/${USERNAME}/.nvm
RUN git clone --depth 1 -b ${NVM_VERSION} https://github.com/nvm-sh/nvm.git ${NVM_DIR}

RUN cat >> /home/${USERNAME}/.bashrc <<'EOF'

# nvm: load the function so it's usable interactively. No version is auto-
# selected here; activation from .nvmrc happens once at container start
# (see ccc-entrypoint). NPM_CONFIG_PREFIX is unset because nvm refuses to
# load when it's set; the pre-installed globals at $NPM_CONFIG_PREFIX/bin
# stay reachable via PATH regardless.
unset NPM_CONFIG_PREFIX
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

# Visual marker so it's obvious which terminal is inside the claude-docker container.
PS1='[\u@\[\e[91m\]\h\[\e[0m\] \W | \[\e[96m\]\[\e[0m\]  ] '
EOF

# Android emulators on demand — the image side of ccc's emulator relay (see
# the top of ccc). Kept late so that changing it doesn't rebuild the
# toolchain; the root-owned files are written in a USER root block.
RUN npm install -g @mobilenext/mobile-mcp

USER root

RUN cat > /usr/local/bin/ccc-emulator <<'EOF' && chmod +x /usr/local/bin/ccc-emulator && ln -s ccc-emulator /usr/local/bin/emulator
#!/usr/bin/env bash
# Container side of ccc's emulator relay: emulators run on the host and are
# started through /run/ccc-android/sock; everything else is plain adb against
# the host's adb server. Installed as `emulator` too, where it speaks the part
# of the real emulator CLI that flutter uses.
set -euo pipefail

sock=/run/ccc-android/sock
me=ccc-emulator
export ADB_SERVER_SOCKET="${ADB_SERVER_SOCKET:-tcp:127.0.0.1:5037}"

die() {
  echo "$me: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
ccc-emulator - Android emulators on the host, driven from this container

  ccc-emulator list                    AVDs installed on the host
  ccc-emulator start [AVD] [options]   start AVD on the host, wait for it to
                                       boot, print its adb serial
      --headless   no window on the host's desktop (-no-window)
      --cold       cold boot, skip the snapshot (-no-snapshot-load)
      --wipe       factory-reset the AVD's data first (-wipe-data)
      --no-wait    return as soon as adb sees the device
      -- FLAGS     more emulator flags, from the host's allow-list
  ccc-emulator stop [SERIAL|AVD|--all] shut an emulator down
  ccc-emulator status                  devices known to the host's adb server
  ccc-emulator adb-server              start the host's adb server (USB devices)

adb, flutter and mobile-mcp here use the host's adb server. `emulator
-list-avds`, `emulator -avd AVD` and `flutter emulators --launch AVD` go
through the same relay.
USAGE
}

relay() {
  local a
  [[ -S "$sock" ]] || die "no emulator relay in this session (needs ccc with host networking, socat and an Android SDK on the host, and no --no-android)"
  for a in "$@"; do
    [[ "$a" =~ ^[A-Za-z0-9._@:-]+$ ]] || die "invalid argument '$a'"
  done
  /usr/bin/python3 - "$sock" "$*" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.connect(sys.argv[1])
except OSError as e:
    sys.exit(f"ccc-emulator: emulator relay not reachable: {e}")
s.sendall(sys.argv[2].encode() + b"\n")
rc = 1
for raw in s.makefile("rb"):
    tag, _, text = raw.decode(errors="replace").rstrip("\n").partition(" ")
    if tag == "o":
        print(text, flush=True)
    elif tag == "e":
        print(text, file=sys.stderr, flush=True)
    elif tag == "x":
        rc = int(text)
sys.exit(rc)
PY
}

require_adb_server() {
  adb devices >/dev/null 2>&1 \
    || die "no adb server on the host — 'ccc-emulator start' or 'ccc-emulator adb-server' starts one"
}

emulator_serials() {
  adb devices | awk 'NR > 1 && $1 ~ /^emulator-/ { print $1 }'
}

# The console answers with the AVD name; without its auth token the props are
# the fallback (ro.boot.qemu.* since API 31, ro.kernel.qemu.* before).
avd_name() {
  local n
  n="$(adb -s "$1" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')" || true
  if [[ -z "$n" || "$n" == KO* ]]; then
    n="$(adb -s "$1" shell 'getprop ro.boot.qemu.avd_name; getprop ro.kernel.qemu.avd_name' 2>/dev/null \
      | tr -d '\r' | grep -m 1 .)" || true
  fi
  printf '%s\n' "$n"
}

cmd_start() {
  local avd="" wait=1 out serial
  local -a flags=() avds=()
  while (($#)); do
    case "$1" in
      --headless) flags+=(-no-window) ;;
      --cold)     flags+=(-no-snapshot-load) ;;
      --wipe)     flags+=(-wipe-data) ;;
      --no-wait)  wait=0 ;;
      --)         shift; flags+=("$@"); break ;;
      -*)         die "unknown option '$1' (emulator flags go after --)" ;;
      *)
        [[ -z "$avd" ]] || die "only one AVD at a time"
        avd="$1" ;;
    esac
    shift
  done
  if [[ -z "$avd" ]]; then
    out="$(relay list)"
    [[ -n "$out" ]] || die "no AVDs on the host"
    mapfile -t avds <<<"$out"
    ((${#avds[@]} == 1)) || die "several AVDs on the host, name one: ${avds[*]}"
    avd="${avds[0]}"
  fi
  out="$(relay start "$avd" ${flags[@]+"${flags[@]}"})"
  serial="$(tail -n 1 <<<"$out")"
  if [[ "$wait" -eq 1 ]]; then
    echo "$me: waiting for $serial to finish booting" >&2
    timeout 300 adb -s "$serial" wait-for-device shell \
      'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done' \
      || die "$serial did not finish booting within 300s"
  fi
  printf '%s\n' "$serial"
}

cmd_stop() {
  local target="${1:-}" s
  local -a running=() serials=()
  require_adb_server
  mapfile -t running < <(emulator_serials)
  case "$target" in
    "")
      ((${#running[@]} == 1)) || die "${#running[@]} emulators running — name a serial or AVD, or use --all"
      serials=("${running[0]}") ;;
    --all)
      serials=(${running[@]+"${running[@]}"}) ;;
    emulator-*)
      serials=("$target") ;;
    *)
      for s in ${running[@]+"${running[@]}"}; do
        if [[ "$(avd_name "$s")" == "$target" ]]; then
          serials+=("$s")
        fi
      done
      ((${#serials[@]})) || die "no running emulator for AVD '$target'" ;;
  esac
  for s in ${serials[@]+"${serials[@]}"}; do
    if adb -s "$s" emu kill 2>&1 | grep -q 'OK: killing'; then
      echo "stopped $s"
    elif adb -s "$s" shell reboot -p >/dev/null 2>&1; then
      echo "powering off $s"
    else
      echo "$me: could not stop $s" >&2
    fi
  done
}

cmd_status() {
  local devs serial state name booted
  devs="$(adb devices 2>/dev/null)" \
    || die "no adb server on the host — 'ccc-emulator start' or 'ccc-emulator adb-server' starts one"
  printf '%-16s %-12s %-24s %s\n' SERIAL STATE AVD BOOTED
  while read -r serial state _; do
    [[ -n "$serial" ]] || continue
    name=- booted=-
    if [[ "$serial" == emulator-* ]]; then
      name="$(avd_name "$serial")"
    fi
    if [[ "$state" == device ]]; then
      booted="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" || true
      if [[ "$booted" == 1 ]]; then booted=yes; else booted=no; fi
    fi
    printf '%-16s %-12s %-24s %s\n' "$serial" "$state" "${name:--}" "$booted"
  done < <(tail -n +2 <<<"$devs")
}

# Flutter runs `emulator -list-avds` (one name per line on stdout),
# `emulator -version` for doctor, and `emulator -avd ID [-no-snapshot-load]`,
# where exit 0 at any time means launched and non-zero within 3s means failed.
emulator_cli() {
  local avd="" serial
  local -a flags=()
  (($#)) || die "usage: emulator -list-avds | -version | -avd NAME [flags] (ccc shim, see ccc-emulator -h)"
  while (($#)); do
    case "$1" in
      -list-avds) relay list; return ;;
      -version)   relay version; return ;;
      -help|-h|--help)
        echo "ccc shim for the host's emulator: -list-avds | -version | -avd NAME [flags]; see ccc-emulator -h"
        return ;;
      -avd)
        (($# >= 2)) || die "-avd needs a name"
        avd="$2"
        shift ;;
      @*) avd="${1#@}" ;;
      -gpu|-memory|-cores|-port)
        (($# >= 2)) || die "$1 needs a value"
        flags+=("$1" "$2")
        shift ;;
      *) flags+=("$1") ;;
    esac
    shift
  done
  [[ -n "$avd" ]] || die "no AVD given (-avd NAME)"
  serial="$(relay start "$avd" ${flags[@]+"${flags[@]}"})"
  echo "INFO    | ccc: $avd is running on the host as $serial"
}

if [[ "$(basename -- "$0")" == emulator ]]; then
  me=emulator
  emulator_cli "$@"
  exit
fi

case "${1:-help}" in
  list)            relay list ;;
  start)           shift; cmd_start "$@" ;;
  stop)            shift; cmd_stop "$@" ;;
  status)          cmd_status ;;
  adb-server)      relay adb-server ;;
  help|-h|--help)  usage ;;
  *)               usage >&2; exit 1 ;;
esac
EOF

# Registered by ccc-entrypoint, only in sessions with the emulator relay. It
# runs on the system node because a project's .nvmrc may select one older than
# the node >= 20 it needs.
RUN mkdir -p /etc/ccc \
 && js="$(readlink -f /home/${USERNAME}/.npm-global/bin/mcp-server-mobile)" \
 && test -f "$js" \
 && jq -n --arg js "$js" \
      '{mcpServers: {"mobile-mcp": {type: "stdio", command: "/usr/bin/node", args: [$js], env: {MOBILEMCP_DISABLE_TELEMETRY: "1"}}}}' \
      > /etc/ccc/mobile-mcp.json

# Headless desktop for GUI apps (see ccc-display). sway ships with a file
# capability (cap_sys_nice) outside docker's bounding set, which makes every exec
# of it fail with EPERM, so it is dropped. inputd drives the wlr virtual-pointer
# and virtual-keyboard protocols through pywayland; Arch ships no bindings for
# either and no XML for the keyboard one, so its wire format is spelled out
# here and both are generated. The `wayland` shim makes the generated modules
# use pywayland's own core classes.
RUN cat > /tmp/virtual-keyboard-unstable-v1.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<protocol name="virtual_keyboard_unstable_v1">
  <interface name="zwp_virtual_keyboard_v1" version="1">
    <request name="keymap">
      <arg name="format" type="uint"/>
      <arg name="fd" type="fd"/>
      <arg name="size" type="uint"/>
    </request>
    <enum name="error">
      <entry name="no_keymap" value="0"/>
    </enum>
    <request name="key">
      <arg name="time" type="uint"/>
      <arg name="key" type="uint"/>
      <arg name="state" type="uint"/>
    </request>
    <request name="modifiers">
      <arg name="mods_depressed" type="uint"/>
      <arg name="mods_latched" type="uint"/>
      <arg name="mods_locked" type="uint"/>
      <arg name="group" type="uint"/>
    </request>
    <request name="destroy" type="destructor" since="1"/>
  </interface>
  <interface name="zwp_virtual_keyboard_manager_v1" version="1">
    <enum name="error">
      <entry name="unauthorized" value="0"/>
    </enum>
    <request name="create_virtual_keyboard">
      <arg name="seat" type="object" interface="wl_seat"/>
      <arg name="id" type="new_id" interface="zwp_virtual_keyboard_v1"/>
    </request>
  </interface>
</protocol>
EOF

RUN setcap -r /usr/bin/sway \
 && mkdir -p /usr/local/lib/ccc-display/cccproto \
 && python3 -m pywayland.scanner -o /tmp/wlproto -i /usr/share/wayland/wayland.xml \
      /usr/share/wlr-protocols/unstable/wlr-virtual-pointer-unstable-v1.xml \
      /tmp/virtual-keyboard-unstable-v1.xml \
 && mv /tmp/wlproto/wlr_virtual_pointer_unstable_v1.py /tmp/wlproto/virtual_keyboard_unstable_v1.py \
      /usr/local/lib/ccc-display/cccproto/ \
 && rm -rf /tmp/wlproto /tmp/virtual-keyboard-unstable-v1.xml \
 && touch /usr/local/lib/ccc-display/cccproto/__init__.py \
 && echo 'from pywayland.protocol.wayland import *  # noqa: F401,F403' > /usr/local/lib/ccc-display/cccproto/wayland.py

RUN cat > /usr/local/lib/ccc-display/inputd.py <<'EOF'
#!/usr/bin/env python3
# Holds one virtual pointer and one virtual keyboard open for the life of the
# display. A headless sway has no input devices, and clients only bind
# wl_pointer/wl_keyboard while the seat advertises them. Takes one command per
# line on a unix socket and answers "ok" or "err <reason>":
#   move X Y W H | down BTN | up BTN | scroll N | sleep MS
#   type JSON-STRING | key COMBO          (COMBO like ctrl+shift+Tab, Return, a)
# W H is the output size, which absolute motion is scaled against.
import json
import os
import re
import socket
import sys
import time

sys.path.insert(0, "/usr/local/lib/ccc-display")

from pywayland.client import Display
from pywayland.protocol.wayland import WlSeat
from cccproto.wlr_virtual_pointer_unstable_v1 import ZwlrVirtualPointerManagerV1
from cccproto.virtual_keyboard_unstable_v1 import ZwpVirtualKeyboardManagerV1

BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}  # linux/input-event-codes.h
AXIS_VERTICAL = 0
SOURCE_WHEEL = 0

# Real keyboards put ASCII at fixed evdev codes, and clients act on those codes:
# Chromium/Electron drop characters sent on codes they don't know and treat
# KEY_ESC/KEY_BACKSPACE as those keys whatever the keysym, and shortcuts match
# on the code. So this is a US layout at the real codes, plus a few spare codes
# (F13-F24) whose keysyms are swapped in for any other character.
NAMED = {
    "Escape": 1, "BackSpace": 14, "Tab": 15, "Return": 28, "space": 57,
    "F1": 59, "F2": 60, "F3": 61, "F4": 62, "F5": 63, "F6": 64, "F7": 65,
    "F8": 66, "F9": 67, "F10": 68, "F11": 87, "F12": 88, "KP_Enter": 96,
    "Print": 99, "Home": 102, "Up": 103, "Page_Up": 104, "Left": 105,
    "Right": 106, "End": 107, "Down": 108, "Page_Down": 109, "Insert": 110,
    "Delete": 111, "Menu": 127,
}
ALIASES = {"Prior": "Page_Up", "Next": "Page_Down", "Enter": "Return", "Esc": "Escape"}
CHAR_NAMES = {"\n": "Return", "\t": "Tab", " ": "space"}
US_ROWS = [
    (2, "1234567890-=", "!@#$%^&*()_+"),
    (16, "qwertyuiop[]", "QWERTYUIOP{}"),
    (30, "asdfghjkl;'`", 'ASDFGHJKL:"~'),
    (43, "\\zxcvbnm,./", "|ZXCVBNM<>?"),
]
US = {}  # char -> (code, shifted)
for base, lower, upper in US_ROWS:
    for i, (lo, up) in enumerate(zip(lower, upper)):
        US[lo] = (base + i, False)
        US[up] = (base + i, True)
DYN_CODES = list(range(183, 195))  # KEY_F13..KEY_F24
SHIFT = 1
MODS = {"shift": 1, "ctrl": 4, "control": 4, "alt": 8, "super": 64, "logo": 64, "win": 64, "meta": 64}

display = Display()
display.connect()
globals_ = {}
registry = display.get_registry()
registry.dispatcher["global"] = lambda _r, name, iface, _v: globals_.setdefault(iface, name)
display.roundtrip()
for iface in ("zwlr_virtual_pointer_manager_v1", "zwp_virtual_keyboard_manager_v1"):
    if iface not in globals_:
        sys.exit(f"ccc-display-inputd: compositor has no {iface}")
seat = registry.bind(globals_["wl_seat"], WlSeat, 1)
pointer = registry.bind(globals_["zwlr_virtual_pointer_manager_v1"], ZwlrVirtualPointerManagerV1, 1) \
    .create_virtual_pointer(seat)
keyboard = registry.bind(globals_["zwp_virtual_keyboard_manager_v1"], ZwpVirtualKeyboardManagerV1, 1) \
    .create_virtual_keyboard(seat)

dynamic = []  # keysym names, on DYN_CODES in order


def ks(ch):
    return f"U{ord(ch):04X}"


def upload_keymap():
    keys = [(code, name) for name, code in NAMED.items()]
    keys += [(base + i, f"{ks(lo)}, {ks(up)}") for base, lower, upper in US_ROWS
             for i, (lo, up) in enumerate(zip(lower, upper))]
    keys += [(DYN_CODES[i], sym) for i, sym in enumerate(dynamic)]
    keycodes = "".join(f"  <K{code}> = {code + 8};\n" for code, _ in keys)
    symbols = "".join(f"  key <K{code}> {{ [ {syms} ] }};\n" for code, syms in keys)
    keymap = (
        "xkb_keymap {\n"
        f'xkb_keycodes "ccc" {{\n  minimum = 8;\n  maximum = 255;\n{keycodes}}};\n'
        'xkb_types "ccc" { include "complete" };\n'
        'xkb_compat "ccc" { include "complete" };\n'
        f'xkb_symbols "ccc" {{\n{symbols}}};\n'
        "};\n"
    ).encode() + b"\0"
    fd = os.memfd_create("ccc-keymap")
    try:
        os.write(fd, keymap)
        keyboard.keymap(1, fd, len(keymap))  # 1 = WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1
        display.roundtrip()
    finally:
        os.close(fd)


def resolve(key):
    """(code, extra modifier mask) for a character or keysym name; keysyms
    that have no fixed code must have been placed with place() first."""
    key = ALIASES.get(key, key)
    if key in NAMED:
        return NAMED[key], 0
    if len(key) == 1:
        if key in CHAR_NAMES:
            return NAMED[CHAR_NAMES[key]], 0
        if key in US:
            code, shifted = US[key]
            return code, SHIFT if shifted else 0
        key = ks(key)
    return DYN_CODES[dynamic.index(key)], 0


def spare_sym(key):
    """The keysym a key needs on a spare code, or None if it has a fixed one."""
    key = ALIASES.get(key, key)
    if key in NAMED or key in CHAR_NAMES or key in US:
        return None
    if len(key) == 1:
        return ks(key)
    if not re.fullmatch(r"[A-Za-z0-9_]+", key):
        raise ValueError(f"bad key {key!r}")
    return key


def place(syms):
    missing = [s for s in dict.fromkeys(syms) if s not in dynamic]
    if not missing:
        return
    if len(dynamic) + len(missing) > len(DYN_CODES):
        dynamic[:] = list(dict.fromkeys(syms))
    else:
        dynamic.extend(missing)
    upload_keymap()


def now():
    return int(time.monotonic() * 1000) & 0xFFFFFFFF


def tap(key, mods=0):
    code, extra = resolve(key)
    mods |= extra
    if mods:
        keyboard.modifiers(mods, 0, 0, 0)
    keyboard.key(now(), code, 1)
    display.roundtrip()
    time.sleep(0.008)
    keyboard.key(now(), code, 0)
    if mods:
        keyboard.modifiers(0, 0, 0, 0)
    display.roundtrip()
    time.sleep(0.008)


def type_text(text):
    # Chunks that fit the spare codes, so each needs at most one keymap swap.
    chunk, spare = [], set()
    for ch in text + "\0":
        sym = spare_sym(ch) if ch != "\0" else None
        if ch == "\0" or (sym and sym not in spare and len(spare) == len(DYN_CODES)):
            place(spare)
            for c in chunk:
                tap(c)
            chunk, spare = [], set()
        if ch != "\0":
            chunk.append(ch)
            if sym:
                spare.add(sym)


def press_combo(combo):
    if combo == "+":
        mods, key = [], "+"
    elif combo.endswith("++"):
        mods, key = combo[:-2].split("+"), "+"
    else:
        *mods, key = combo.split("+")
    mask = 0
    for m in mods:
        if m.lower() not in MODS:
            raise ValueError(f"unknown modifier {m!r}")
        mask |= MODS[m.lower()]
    sym = spare_sym(key)
    if sym:
        place([sym])
    tap(key, mask)


def run(line):
    cmd, _, rest = line.strip().partition(" ")
    args = rest.split()
    if cmd == "move":
        x, y, w, h = map(int, args[:4])
        pointer.motion_absolute(now(), x, y, w, h)
    elif cmd in ("down", "up"):
        pointer.button(now(), BUTTONS[args[0]], 1 if cmd == "down" else 0)
    elif cmd == "scroll":
        steps = int(args[0])
        pointer.axis_source(SOURCE_WHEEL)
        pointer.axis_discrete(now(), AXIS_VERTICAL, 15.0 * steps, steps)
    elif cmd == "sleep":
        time.sleep(int(args[0]) / 1000)
        return
    elif cmd == "type":
        type_text(json.loads(rest))
        return
    elif cmd == "key":
        press_combo(rest.strip())
        return
    else:
        raise ValueError(f"unknown command {cmd!r}")
    pointer.frame()
    display.roundtrip()


upload_keymap()
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sys.argv[1])
server.listen(4)
while True:
    conn, _ = server.accept()
    with conn, conn.makefile("rw") as f:
        for line in f:
            try:
                run(line)
                f.write("ok\n")
            except (ValueError, KeyError, IndexError, json.JSONDecodeError) as e:
                f.write(f"err {e}\n")
            f.flush()
EOF

RUN cat > /usr/local/bin/ccc-display <<'EOF' && chmod +x /usr/local/bin/ccc-display
#!/usr/bin/env bash
# A headless Wayland desktop in the container: sway on the headless backend
# with XWayland, so native Wayland and X11 apps (Swing, …) both run here
# without a window on the host, plus the means to see and drive them.
set -euo pipefail

me=ccc-display
dir=/tmp/ccc-display
lib=/usr/local/lib/ccc-display
default_size=1440x900

die() {
  echo "$me: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
ccc-display - headless desktop (sway + XWayland) for GUI apps in this container

  ccc-display start [WxH]              start it (default 1440x900), idempotent
  ccc-display stop | status
  ccc-display env                      export lines for the display, for eval
  ccc-display run CMD...               run CMD on the display, in the foreground
  ccc-display launch CMD...            start CMD detached, print its pid and log
  ccc-display wait-window REGEX [SEC]  wait (default 60s) for a matching window

  ccc-display windows                  id, shell, app, focus, geometry, title
  ccc-display focus ID|REGEX
  ccc-display close ID|REGEX           ask the window to close (like its X button)
  ccc-display screenshot [FILE] [--window ID|REGEX]   print the PNG's path

  ccc-display click X Y [left|right|middle] [--double]
  ccc-display move X Y
  ccc-display drag X1 Y1 X2 Y2
  ccc-display scroll X Y N             N wheel steps, negative scrolls up
  ccc-display type TEXT                into the focused window
  ccc-display key COMBO...             e.g. Return, ctrl+s, alt+F4, shift+Tab

  ccc-display vnc                      serve the screen on 127.0.0.1 over VNC

Coordinates are screen pixels, the same as in a full screenshot. REGEX
matches window titles. Keys go through xdotool to XWayland windows and through
a virtual keyboard to Wayland ones.
USAGE
}

running() {
  [[ -f "$dir/sway.pid" ]] && kill -0 "$(<"$dir/sway.pid")" 2>/dev/null
}

require() {
  running || die "the display is not running — 'ccc-display start' first"
}

load_env() {
  export XDG_RUNTIME_DIR="$dir"
  WAYLAND_DISPLAY="$(<"$dir/wayland-display")"
  DISPLAY="$(<"$dir/x-display")"
  SWAYSOCK="$(<"$dir/swaysock")"
  export WAYLAND_DISPLAY DISPLAY SWAYSOCK
  # Java's AWT draws empty grey windows under a non-reparenting window manager.
  export _JAVA_AWT_WM_NONREPARENTING=1
}

wait_for() {
  local what="$1" i
  shift
  for ((i = 0; i < 100; i++)); do
    "$@" && return 0
    running || die "sway exited while waiting for $what, see $dir/sway.log"
    sleep 0.1
  done
  die "timed out waiting for $what, see $dir/sway.log"
}

has_file() {
  compgen -G "$1" >/dev/null
}

cmd_start() {
  local size="${1:-$default_size}" sock
  [[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || die "size must be WIDTHxHEIGHT, e.g. 1440x900"
  if running; then
    cmd_env
    return
  fi
  rm -rf "$dir"
  mkdir -m 700 "$dir"
  cat >"$dir/sway.conf" <<CONF
output HEADLESS-1 resolution $size position 0 0
swaybg_command -
xwayland force
for_window [all] floating enable
exec sh -c 'printf "%s\\n" "\$DISPLAY" > $dir/x-display'
CONF
  # Without WAYLAND_DISPLAY/DISPLAY from the host session sway cannot mistake
  # itself for a nested compositor; the backend is pinned anyway.
  env -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$dir" \
    WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    setsid sway -c "$dir/sway.conf" </dev/null >"$dir/sway.log" 2>&1 &
  echo $! >"$dir/sway.pid"

  wait_for "the sway IPC socket" has_file "$dir/sway-ipc.*.sock"
  sock="$(compgen -G "$dir/sway-ipc.*.sock" | head -n 1)"
  echo "$sock" >"$dir/swaysock"
  wait_for "the Wayland socket" has_file "$dir/wayland-[0-9]*.lock"
  basename "$(compgen -G "$dir/wayland-[0-9]*.lock" | head -n 1)" .lock >"$dir/wayland-display"
  wait_for "XWayland" test -s "$dir/x-display"

  load_env
  setsid /usr/bin/python3 "$lib/inputd.py" "$dir/input.sock" </dev/null >"$dir/inputd.log" 2>&1 &
  echo $! >"$dir/inputd.pid"
  wait_for "the virtual input devices" test -S "$dir/input.sock"
  # XWayland drops the modifiers of the first XTEST key it ever gets.
  xdotool key shift >/dev/null 2>&1 || true
  cmd_env
}

cmd_stop() {
  local f
  for f in vnc inputd sway; do
    [[ -f "$dir/$f.pid" ]] && kill "$(<"$dir/$f.pid")" 2>/dev/null || true
  done
  rm -f "$dir"/*.pid
  echo "stopped"
}

cmd_env() {
  require
  load_env
  printf 'export XDG_RUNTIME_DIR=%q\n' "$XDG_RUNTIME_DIR"
  printf 'export WAYLAND_DISPLAY=%q\n' "$WAYLAND_DISPLAY"
  printf 'export DISPLAY=%q\n' "$DISPLAY"
  printf 'export SWAYSOCK=%q\n' "$SWAYSOCK"
  printf 'export _JAVA_AWT_WM_NONREPARENTING=1\n'
}

output_size() {
  swaymsg -r -t get_outputs | jq -r '.[0].current_mode | "\(.width) \(.height)"'
}

cmd_status() {
  if ! running; then
    echo "not running"
    return
  fi
  load_env
  echo "running: $(output_size | tr ' ' x), WAYLAND_DISPLAY=$WAYLAND_DISPLAY DISPLAY=$DISPLAY"
  if [[ -f "$dir/vnc.port" ]] && kill -0 "$(<"$dir/vnc.pid")" 2>/dev/null; then
    echo "vnc: 127.0.0.1:$(<"$dir/vnc.port")"
  fi
  cmd_windows
}

tree_windows() {
  swaymsg -r -t get_tree | jq -c '
    recurse(.nodes[]?, .floating_nodes[]?)
    | select((.type == "con" or .type == "floating_con") and .pid != null)
    | {id, shell, focused, rect, title: (.name // ""),
       app: (.app_id // .window_properties.class // "")}'
}

cmd_windows() {
  require
  load_env
  {
    printf 'ID\tSHELL\tAPP\tFOCUS\tX,Y WxH\tTITLE\n'
    tree_windows | jq -r '[.id, .shell, .app, (if .focused then "*" else "" end),
      "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)", .title] | @tsv'
  } | column -t -s $'\t'
}

# One window as JSON, by con id or title regex; the focused one wins a tie.
find_window() {
  local sel="$1" w
  if [[ "$sel" =~ ^[0-9]+$ ]]; then
    w="$(tree_windows | jq -c --argjson id "$sel" 'select(.id == $id)')"
  else
    w="$(tree_windows | jq -sc --arg re "$sel" \
      '[.[] | select(.title | test($re))] | sort_by(.focused | not) | .[0] // empty')"
  fi
  [[ -n "$w" ]] || return 1
  printf '%s\n' "$w"
}

cmd_focus() {
  local w
  (($# == 1)) || die "usage: focus ID|REGEX"
  require
  load_env
  w="$(find_window "$1")" || die "no window matches '$1'"
  swaymsg -q "[con_id=$(jq .id <<<"$w")] focus"
}

# Closing through sway reaches the app wherever its process runs: a Gradle
# daemon shared through ~/.gradle may have started it in a sibling container,
# out of reach of kill/pkill here.
cmd_close() {
  local w
  (($# == 1)) || die "usage: close ID|REGEX"
  require
  load_env
  w="$(find_window "$1")" || die "no window matches '$1'"
  swaymsg -q "[con_id=$(jq .id <<<"$w")] kill"
}

cmd_wait_window() {
  local re="${1:-}" secs="${2:-60}" i w
  [[ -n "$re" ]] || die "usage: wait-window REGEX [SECONDS]"
  require
  load_env
  for ((i = 0; i < secs * 4; i++)); do
    if w="$(find_window "$re")"; then
      # A new window is often resized and re-centred right after it maps.
      local prev="" next n
      for ((n = 0; n < 12; n++)); do
        [[ "$(jq -c .rect <<<"$w")" == "$prev" ]] && break
        prev="$(jq -c .rect <<<"$w")"
        sleep 0.25
        next="$(find_window "$re")" || break
        w="$next"
      done
      jq -r '"\(.id)\t\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)\t\(.title)"' <<<"$w"
      return 0
    fi
    sleep 0.25
  done
  die "no window matching '$re' within ${secs}s"
}

cmd_screenshot() {
  local file="" win="" w geom
  while (($#)); do
    case "$1" in
      --window) (($# >= 2)) || die "--window needs an ID or REGEX"; win="$2"; shift ;;
      -*) die "unknown option '$1'" ;;
      *) file="$1" ;;
    esac
    shift
  done
  require
  load_env
  if [[ -z "$file" ]]; then
    mkdir -p "$dir/shots"
    file="$dir/shots/$(date +%Y%m%d-%H%M%S-%N | cut -c1-19).png"
  fi
  if [[ -n "$win" ]]; then
    w="$(find_window "$win")" || die "no window matches '$win'"
    geom="$(jq -r '.rect | "\(.x),\(.y) \(.width)x\(.height)"' <<<"$w")"
    grim -g "$geom" "$file"
    echo "$file (window at ${geom% *}: add that offset to coordinates in this image)"
  else
    grim "$file"
    echo "$file"
  fi
}

# Sends commands to inputd; "move" gets the output size appended, "type" its
# text JSON-encoded so that any character survives the line protocol.
send_input() {
  local size
  require
  load_env
  size="$(output_size)"
  /usr/bin/python3 - "$dir/input.sock" "$size" "$@" <<'PY'
import json, socket, sys
path, size, cmds = sys.argv[1], sys.argv[2], sys.argv[3:]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(path)
f = s.makefile("rw")
for c in cmds:
    if c.startswith("move "):
        c += " " + size
    elif c.startswith("type "):
        c = "type " + json.dumps(c[5:])
    f.write(c + "\n")
    f.flush()
    r = f.readline().strip()
    if r != "ok":
        sys.exit(f"ccc-display: {c}: {r or 'no answer'}")
PY
}

need_int() {
  [[ "$1" =~ ^-?[0-9]+$ ]] || die "'$1' is not an integer"
}

cmd_click() {
  local x="${1:-}" y="${2:-}" button=left double=0
  (($# >= 2)) || die "usage: click X Y [left|right|middle] [--double]"
  need_int "$x"; need_int "$y"
  shift 2
  while (($#)); do
    case "$1" in
      left|right|middle) button="$1" ;;
      --double) double=1 ;;
      *) die "unknown click argument '$1'" ;;
    esac
    shift
  done
  local -a seq=("move $x $y" "sleep 60" "down $button" "sleep 40" "up $button")
  if ((double)); then
    seq+=("sleep 80" "down $button" "sleep 40" "up $button")
  fi
  send_input "${seq[@]}"
}

cmd_move() {
  (($# == 2)) || die "usage: move X Y"
  need_int "$1"; need_int "$2"
  send_input "move $1 $2"
}

cmd_drag() {
  local i x y
  (($# == 4)) || die "usage: drag X1 Y1 X2 Y2"
  for i in "$@"; do need_int "$i"; done
  local -a seq=("move $1 $2" "sleep 60" "down left")
  for ((i = 1; i <= 10; i++)); do
    x=$(($1 + ($3 - $1) * i / 10))
    y=$(($2 + ($4 - $2) * i / 10))
    seq+=("sleep 20" "move $x $y")
  done
  seq+=("sleep 60" "up left")
  send_input "${seq[@]}"
}

cmd_scroll() {
  (($# == 3)) || die "usage: scroll X Y N"
  need_int "$1"; need_int "$2"; need_int "$3"
  send_input "move $1 $2" "sleep 60" "scroll $3"
}

focused_shell() {
  swaymsg -r -t get_tree | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused) | .shell // empty'
}

cmd_type() {
  (($# >= 1)) || die "usage: type TEXT"
  require
  load_env
  # XWayland clients mis-read keys from a keymap that changes under them, so
  # X11 windows get XTEST through xdotool instead of the virtual keyboard.
  if [[ "$(focused_shell)" == xwayland ]]; then
    xdotool type --delay 12 -- "$*"
  else
    send_input "type $*"
  fi
}

cmd_key() {
  local combo
  local -a cmds=()
  (($# >= 1)) || die "usage: key COMBO..."
  require
  load_env
  if [[ "$(focused_shell)" == xwayland ]]; then
    xdotool key --delay 30 -- "$@"
    return
  fi
  for combo in "$@"; do cmds+=("key $combo"); done
  send_input "${cmds[@]}"
}

cmd_run() {
  (($# >= 1)) || die "usage: run CMD..."
  require
  load_env
  exec "$@"
}

cmd_launch() {
  local log
  (($# >= 1)) || die "usage: launch CMD..."
  require
  load_env
  mkdir -p "$dir/logs"
  log="$dir/logs/$(basename -- "$1")-$(date +%H%M%S).log"
  setsid "$@" </dev/null >"$log" 2>&1 &
  echo "pid $! log $log"
}

port_busy() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

cmd_vnc() {
  local port
  require
  load_env
  if [[ -f "$dir/vnc.pid" ]] && kill -0 "$(<"$dir/vnc.pid")" 2>/dev/null; then
    echo "vnc: 127.0.0.1:$(<"$dir/vnc.port")"
    return
  fi
  # Host networking: other sessions and the host itself share these ports.
  for ((port = 5900; port < 5950; port++)); do
    port_busy "$port" || break
  done
  ((port < 5950)) || die "no free port in 5900-5949"
  setsid wayvnc 127.0.0.1 "$port" </dev/null >"$dir/vnc.log" 2>&1 &
  echo $! >"$dir/vnc.pid"
  echo "$port" >"$dir/vnc.port"
  wait_for "wayvnc" port_busy "$port"
  echo "vnc: 127.0.0.1:$port"
}

case "${1:-help}" in
  start)        shift; cmd_start "$@" ;;
  stop)         cmd_stop ;;
  status)       cmd_status ;;
  env)          cmd_env ;;
  run)          shift; cmd_run "$@" ;;
  launch)       shift; cmd_launch "$@" ;;
  wait-window)  shift; cmd_wait_window "$@" ;;
  windows)      cmd_windows ;;
  focus)        shift; cmd_focus "$@" ;;
  close)        shift; cmd_close "$@" ;;
  screenshot)   shift; cmd_screenshot "$@" ;;
  click)        shift; cmd_click "$@" ;;
  move)         shift; cmd_move "$@" ;;
  drag)         shift; cmd_drag "$@" ;;
  scroll)       shift; cmd_scroll "$@" ;;
  type)         shift; cmd_type "$@" ;;
  key)          shift; cmd_key "$@" ;;
  vnc)          cmd_vnc ;;
  help|-h|--help) usage ;;
  *)            usage >&2; exit 1 ;;
esac
EOF

# Managed-policy memory: loaded into every claude session in the container,
# alongside the user's and the project's CLAUDE.md.
RUN mkdir -p /etc/claude-code && cat > /etc/claude-code/CLAUDE.md <<'EOF'
# Container environment (ccc)

This session runs inside the ccc Docker container; the workspace is mounted at the same absolute path as on the host.

- `docker` talks to the host's daemon: containers you start are siblings, and bind-mount sources are host paths (the same as the workspace paths here).
- Host networking: services on the host's 127.0.0.1 are reachable as localhost.
- The chrome-devtools MCP drives a Chrome window on the host; it opens on the first browser tool call.

## Android
Emulators run on the host, not in this container. `adb`, flutter and the mobile-mcp tools talk to the host's adb server, so `adb install`, `adb exec-out screencap -p > shot.png`, `flutter run` and mobile-mcp (screenshots, element list, tap/type/swipe, app install/launch) work against them as usual.
- `ccc-emulator list` shows the host's AVDs; `ccc-emulator start [AVD]` starts one, waits until it has booted and prints its serial; `ccc-emulator stop` / `ccc-emulator status`. `emulator -list-avds`, `emulator -avd AVD` and `flutter emulators --launch AVD` take the same path.
- The emulator window opens on the user's desktop; use `--headless` only when asked to.
- If adb cannot reach its daemon, run `ccc-emulator adb-server`. adb here never starts a server of its own.

## GUI apps
`ccc-display` runs a headless desktop (sway + XWayland) inside the container, so desktop apps (Swing/X11 and native Wayland) can be started, seen and driven here; nothing opens on the user's screen.
- `ccc-display start`, then `ccc-display launch CMD…` (detached; prints pid and log) and `ccc-display wait-window REGEX`. `ccc-display run CMD…` runs in the foreground; `eval "$(ccc-display env)"` sets up any other shell.
- `ccc-display screenshot [--window ID|REGEX]` prints a PNG path: Read it to see the screen. The default 1440x900 screen is not downscaled, so image pixels are screen coordinates.
- `click X Y [right] [--double]`, `drag`, `scroll X Y N`, `type TEXT`, `key ctrl+s Return …`, `windows`, `focus`. `ccc-display -h` for the rest.
- `ccc-display vnc` serves the screen on 127.0.0.1 if the user wants to watch.
- Gradle daemons are shared with sibling ccc containers through `~/.gradle` and host networking, so an app started by `./gradlew run` may run in another container yet still show here. kill/pkill here cannot reach it: end it with `ccc-display close`, and check `windows` afterwards.
EOF

USER ${USERNAME}

# Where flutter looks for the emulator binary.
RUN mkdir -p "$ANDROID_HOME/emulator" \
 && ln -s /usr/local/bin/ccc-emulator "$ANDROID_HOME/emulator/emulator"

RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_VERSION}" \
 && /home/${USERNAME}/.local/bin/claude --version

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/ccc-entrypoint"]
CMD ["claude", "--dangerously-skip-permissions"]
