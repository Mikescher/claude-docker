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
        git curl wget openssh \
        ripgrep fd jq tmux less vim nano \
        unzip zip tar which man-db bash-completion \
        shellcheck mkvtoolnix-cli \
        sudo ca-certificates gnupg \
        cmake pkgconf ninja clang gtk3 mesa-utils \
        docker docker-buildx docker-compose \
        ffmpeg wl-clipboard libpulse \
        restic \
        postgresql \
        jdk-openjdk jdk17-openjdk jdk11-openjdk ant maven \
        dotnet-sdk \
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
if [[ -f .nvmrc ]]; then
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    unset NPM_CONFIG_PREFIX
    . "$NVM_DIR/nvm.sh"
    nvm install || echo "ccc-entrypoint: nvm install failed; falling back to system node" >&2
  fi
fi

# .java-version (jenv/jabba/sdkman convention): switch the active JDK to match,
# like .nvmrc does for node. Content is a version such as "25", "21", "17",
# "1.8" or a full "25.0.3" — we match on the *major* version against the JDKs
# installed under /usr/lib/jvm (java-<major>-openjdk and the Temurin builds).
# A vendor may be named to force a specific build when a major has more than one
# (both java-25-openjdk and java-25-temurin exist): "temurin-25" / "25-temurin"
# / sdkman's "25-tem" pick Temurin, "openjdk-25" picks the pacman JDK. A bare
# version takes the first java-<major>-* match (openjdk sorts before temurin).
# On a bad or unmatched version it falls back to the system default, but
# loudly: an error is printed and the start pauses 2s so the message is seen
# before claude takes over the terminal.
if [[ -f .java-version ]]; then
  raw=$(tr -d '[:space:]' < .java-version)
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
    echo "ccc-entrypoint: no JDK matching .java-version ($raw) installed; keeping system default" >&2
    sleep 2
  fi
fi

# chrome-devtools-mcp ships configured to spawn its own Chrome, which can't
# work in this container (no display, no chrome binary). Re-point it at a
# host Chrome reachable on the shared host network — start one with:
#   google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-mcp
# Idempotent (skips when the flag is already present); re-applies after
# plugin updates wipe the marketplace cache.
mcp_cfg="$HOME/.claude/plugins/cache/claude-plugins-official/chrome-devtools-mcp/latest/.claude-plugin/plugin.json"
if [[ -f "$mcp_cfg" ]] && ! grep -q 'browser-url' "$mcp_cfg"; then
  tmp=$(mktemp) && jq '.mcpServers["chrome-devtools"].args += ["--browser-url=http://127.0.0.1:9222"]' "$mcp_cfg" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$mcp_cfg" \
    || { rm -f "$tmp"; echo "ccc-entrypoint: failed to patch chrome-devtools-mcp config" >&2; }
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

RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_VERSION}" \
 && /home/${USERNAME}/.local/bin/claude --version

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/ccc-entrypoint"]
CMD ["claude", "--dangerously-skip-permissions"]
