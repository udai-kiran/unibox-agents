# unibox-agents

An isolated container for running coding agents: **claude**, **codex**, **agy**, **pi**, **opencode**.

## Usage

```bash
docker compose build
docker compose run --rm agents            # shell in the container
docker compose run --rm agents claude     # or codex / agy / pi / opencode
```

The shell is zsh with the powerlevel10k prompt (config in `zsh/p10k.zsh`, copied from the host's `~/.p10k.zsh`) and autosuggestions. Shell history is kept in the `zsh-history` volume. Use a Nerd Font in your terminal for the icons. The host's `zshrc` is not copied, because it holds machine-specific paths and tools; edit `zsh/zshrc` to change the container's.

To run several agents side by side, start `herdr` in the shell. It gives each agent its own pane and shows whether it is working, blocked or done. Sessions keep running after you detach. The herdr prefix key is `ctrl+a` (set in `herdr/config.toml`).

First run: log in once per agent inside the container. Logins are stored in Docker named volumes and survive `--rm`.

For API-key auth, export `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` or `GEMINI_API_KEY` before `docker compose run`. agy also needs `"modelProvider": "gemini"` in `~/.gemini/antigravity-cli/settings.json`.

## What is isolated

- Runs as non-root `agent` (UID/GID default 1000; override with `USER_UID` / `USER_GID` at build time).
- `cap_drop: ALL`, `no-new-privileges`, PID limit.
- **No host mounts.** Work lives in the `workspace` volume at `/workspace`. Get code in with `cd /workspace && git clone <repo>` (use `gh auth login` inside), and out with `git push` or `docker cp`.
- Each agent's config and credentials sit in their own volume, separate from your host `~/.claude`, `~/.codex`, etc.
- Network: full outbound access (no egress filtering).

## Reset

```bash
docker compose down -v    # deletes workspace AND all agent logins
```
