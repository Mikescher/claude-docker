FROM archlinux:base-devel

ARG UID=1000
ARG GID=1000
ARG CLAUDE_VERSION=latest

LABEL claude_version="${CLAUDE_VERSION}"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISABLE_AUTOUPDATER=1 \
    NPM_CONFIG_PREFIX=/home/dev/.npm-global \
    GOPATH=/home/dev/go \
    PATH=/home/dev/.npm-global/bin:/home/dev/.local/bin:/home/dev/go/bin:/usr/local/bin:/usr/bin:/bin

RUN pacman -Syu --noconfirm --needed \
        git curl wget openssh \
        ripgrep fd jq tmux less vim nano \
        unzip zip tar which man-db bash-completion \
        sudo ca-certificates gnupg \
        cmake pkgconf \
        ffmpeg \
        jdk-openjdk \
        go gopls delve golangci-lint \
        nodejs npm bun \
        python python-pip python-pipx \
 && pacman -Scc --noconfirm \
 && rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

ARG MONGO_TOOLS_VERSION=100.16.1
RUN curl -fsSL "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-rhel88-x86_64-${MONGO_TOOLS_VERSION}.tgz" \
    | tar xz -C /usr/local/bin --strip-components=2 --wildcards '*/bin/*'

RUN groupadd -g ${GID} dev \
 && useradd -m -s /bin/bash -u ${UID} -g ${GID} dev \
 && echo 'dev ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/dev \
 && chmod 0440 /etc/sudoers.d/dev

USER dev
WORKDIR /home/dev

RUN mkdir -p \
      /home/dev/.npm-global \
      /home/dev/.npm \
      /home/dev/.local/bin \
      /home/dev/.cache/go-build \
      /home/dev/.cache/pip \
      /home/dev/.cache/uv \
      /home/dev/go/bin \
      /home/dev/go/pkg

RUN npm install -g typescript ts-node yarn pnpm eslint prettier @angular/cli mongosh

RUN go install honnef.co/go/tools/cmd/staticcheck@latest \
 && go install mvdan.cc/gofumpt@latest

RUN pipx install black \
 && pipx install ruff \
 && pipx install mypy \
 && pipx install pytest \
 && pipx install httpie

ARG NVM_VERSION=v0.40.4
ENV NVM_DIR=/home/dev/.nvm
RUN git clone --depth 1 -b ${NVM_VERSION} https://github.com/nvm-sh/nvm.git ${NVM_DIR}

RUN cat >> /home/dev/.bashrc <<'EOF'

# nvm: load the function so it's usable interactively. No version is auto-
# selected here; activation from .nvmrc happens once at container start
# (see ccc-entrypoint). NPM_CONFIG_PREFIX is unset because nvm refuses to
# load when it's set; the pre-installed globals at $NPM_CONFIG_PREFIX/bin
# stay reachable via PATH regardless.
unset NPM_CONFIG_PREFIX
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
EOF

RUN cat > /home/dev/.local/bin/ccc-entrypoint <<'EOF' && chmod +x /home/dev/.local/bin/ccc-entrypoint
#!/usr/bin/env bash
if [[ -f .nvmrc ]]; then
  export NVM_DIR="${NVM_DIR:-/home/dev/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    unset NPM_CONFIG_PREFIX
    . "$NVM_DIR/nvm.sh"
    nvm install || echo "ccc-entrypoint: nvm install failed; falling back to system node" >&2
  fi
fi
exec "$@"
EOF

RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_VERSION}" \
 && /home/dev/.local/bin/claude --version

WORKDIR /workspace
ENTRYPOINT ["/home/dev/.local/bin/ccc-entrypoint"]
CMD ["claude", "--dangerously-skip-permissions"]
