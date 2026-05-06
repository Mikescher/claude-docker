FROM archlinux:base-devel

ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
ARG CLAUDE_VERSION=latest

LABEL claude_version="${CLAUDE_VERSION}"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISABLE_AUTOUPDATER=1 \
    NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global \
    GOPATH=/home/${USERNAME}/go \
    PATH=/home/${USERNAME}/.npm-global/bin:/home/${USERNAME}/.local/bin:/home/${USERNAME}/go/bin:/usr/local/bin:/usr/bin:/bin

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
exec "$@"
EOF

USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN mkdir -p \
      /home/${USERNAME}/.npm-global \
      /home/${USERNAME}/.npm \
      /home/${USERNAME}/.local/bin \
      /home/${USERNAME}/.cache/go-build \
      /home/${USERNAME}/.cache/pip \
      /home/${USERNAME}/.cache/uv \
      /home/${USERNAME}/go/bin \
      /home/${USERNAME}/go/pkg

RUN npm install -g typescript ts-node yarn pnpm eslint prettier @angular/cli mongosh

RUN go install honnef.co/go/tools/cmd/staticcheck@latest \
 && go install mvdan.cc/gofumpt@latest

RUN pipx install black \
 && pipx install ruff \
 && pipx install mypy \
 && pipx install pytest \
 && pipx install httpie

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
