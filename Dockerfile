FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive
# UTF-8 locale and 256-color terminal, so the powerlevel10k prompt shows icons and colors.
ENV LANG=C.UTF-8
ENV TERM=xterm-256color

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gh \
    openssh-client \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    ripgrep \
    less \
    fd-find \
    tmux \
    unzip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04+ ships a default "ubuntu" user at UID 1000; replace it with our own.
ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000
RUN (userdel -r ubuntu || true) \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/zsh ${USERNAME}

ENV HOME=/home/${USERNAME}
ENV NVM_DIR=${HOME}/.nvm
# ~/.nvm/current is a symlink to the installed LTS (created below), so node/npm
# and npm-global CLIs are on PATH for non-interactive shells too.
ENV PATH=${HOME}/.local/bin:${NVM_DIR}/current/bin:${PATH}
# Keep Claude's state (including ~/.claude.json) inside the mounted ~/.claude volume.
ENV CLAUDE_CONFIG_DIR=${HOME}/.claude

# Pre-create the mount points so named volumes inherit agent ownership.
RUN install -d -o ${USERNAME} -g ${USERNAME} /workspace \
        ${HOME}/.zsh_history.d ${HOME}/.claude ${HOME}/.codex ${HOME}/.gemini ${HOME}/.gemini/config ${HOME}/.dsh ${HOME}/.dsh ${HOME}/.pi ${HOME}/.pi/agent ${HOME}/.pi/agent/extensions \
        ${HOME}/.config ${HOME}/.config/opencode ${HOME}/.local ${HOME}/.local/share ${HOME}/.local/share/opencode

USER ${USERNAME}

# claude, agy: official installers (-> ~/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d "$HOME/.local/bin"

# herdr: terminal multiplexer with per-agent status (-> ~/.local/bin, checksum-verified by the installer)
RUN curl -fsSL https://herdr.dev/install.sh | sh
COPY --chown=${USERNAME}:${USERNAME} herdr/config.toml ${HOME}/.config/herdr/config.toml

# node: nvm, with the LTS release installed and set as default
ARG NVM_VERSION=v0.40.3
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | PROFILE=/dev/null bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm alias default 'lts/*' \
    && ln -s "$(dirname "$(dirname "$(nvm which default)")")" "$NVM_DIR/current" \
    && echo '. "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"

# codex, pi, opencode, dsh (DeepSeek Harness): npm (-> the LTS node's global bin)
RUN npm install -g @openai/codex @earendil-works/pi-coding-agent opencode-ai @deepseek-ai/dsh \
    && npm cache clean --force

# inodex: filesystem message exchange between agents (release binary, SHA256SUMS-verified)
ARG INODEX_VERSION=v0.1.0
RUN arch="$(dpkg --print-architecture)" \
    && f="inodex-${INODEX_VERSION}-linux-${arch}" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "https://github.com/udai-kiran/inodex/releases/download/${INODEX_VERSION}/${f}" \
    && curl -fsSLO "https://github.com/udai-kiran/inodex/releases/download/${INODEX_VERSION}/SHA256SUMS" \
    && grep " ${f}\$" SHA256SUMS | sha256sum -c - \
    && install -m 0755 "${f}" "$HOME/.local/bin/inodex" \
    && inodex version

# multi-agent-workflow: agent/hook/script template, kept at ~/multi-agent-workflow (pinned commit).
# Its check-binaries.sh wants `fd`; Ubuntu installs it as `fdfind`.
ARG WORKFLOW_REF=8881a432699c4f59f9789b21a97bbc74f088bc65
RUN git clone https://github.com/udai-kiran/multi-agent-workflow.git ~/multi-agent-workflow \
    && git -C ~/multi-agent-workflow checkout --quiet ${WORKFLOW_REF} \
    && ln -s "$(command -v fdfind)" ~/.local/bin/fd

# Install the workflow into each agent's config dir and register inodex as an MCP server
# for claude, codex, agy, opencode, pi and dsh. Volumes only inherit this when first created (see README).
# claude/: the host's status line and non-sensitive settings, merged over the workflow's settings.json.
COPY --chown=${USERNAME}:${USERNAME} claude/ ${HOME}/.claude-overlay/
RUN cp -r ~/multi-agent-workflow/.claude/. ~/.claude/ \
    && install -m 0755 ~/.claude-overlay/statusline.sh ~/.claude/statusline.sh \
    && jq -s '.[0] * .[1]' ~/.claude/settings.json ~/.claude-overlay/settings.json > ~/.claude/settings.merged \
    && mv ~/.claude/settings.merged ~/.claude/settings.json && rm -rf ~/.claude-overlay \
    && cp ~/multi-agent-workflow/.codex/AGENTS.md ~/.codex/AGENTS.md \
    && claude mcp add --scope user inodex -- inodex serve \
    && printf '\n[mcp_servers.inodex]\ncommand = "inodex"\nargs = ["serve"]\n' >> ~/.codex/config.toml \
    && agy mcp add inodex inodex serve \
    && pi mcp add inodex -- inodex serve \
    && printf '{"mcp":{"inodex":{"type":"local","command":["inodex","serve"]}}}\n' > ~/.config/opencode/opencode.json

COPY --chown=${USERNAME}:${USERNAME} dsh-cordis.patch.yml ${HOME}/.dsh/cordis.patch.yml

# herdr agent integrations: hooks/extensions that let herdr see each agent's state
RUN for agent in claude codex opencode pi antigravity-cli; do herdr integration install "$agent"; done \
    && herdr integration status

# zsh: powerlevel10k prompt + autosuggestions. Needs a Nerd Font in your host terminal.
ARG P10K_VERSION=v1.20.0
ARG AUTOSUGGEST_VERSION=v0.7.1
RUN git clone --depth 1 --branch ${P10K_VERSION} https://github.com/romkatv/powerlevel10k.git ~/.zsh/powerlevel10k \
    && git clone --depth 1 --branch ${AUTOSUGGEST_VERSION} https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
COPY --chown=${USERNAME}:${USERNAME} zsh/zshrc ${HOME}/.zshrc
COPY --chown=${USERNAME}:${USERNAME} zsh/p10k.zsh ${HOME}/.p10k.zsh

WORKDIR /workspace
CMD ["/bin/zsh"]
