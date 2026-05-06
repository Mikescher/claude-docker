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

RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_VERSION}" \
 && /home/dev/.local/bin/claude --version

WORKDIR /workspace
CMD ["claude", "--dangerously-skip-permissions"]
