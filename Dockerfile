FROM debian:bookworm-slim

ARG CLAUDE_VERSION=2.1.92

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

RUN mkdir -p /etc/claude-code
RUN chown -R root:root /etc/claude-code && chmod 0755 /etc/claude-code
RUN groupadd -g ${GID} dev && useradd -m -s /bin/bash -u ${UID} -g ${GID} dev

RUN apt-get update && apt-get install -y \
    git curl \
    openssh-client \
    ripgrep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv \
    build-essential ripgrep jq tmux less \
 && rm -rf /var/lib/apt/lists/*

USER dev
WORKDIR /home/dev/work

ENV PATH="/home/dev/.local/bin:$PATH"

RUN curl -fsSL -o /tmp/claude-install.sh https://claude.ai/install.sh 
RUN bash /tmp/claude-install.sh ${CLAUDE_VERSION}

WORKDIR /home/dev/work
