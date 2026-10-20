# unibox-agents

An isolated container for running coding agents: **claude**, **codex**, **agy**, **pi**, **opencode**, **dsh** (DeepSeek Harness).

## Usage

```bash
docker compose build
docker compose run --rm agents            # shell in the container
docker compose run --rm agents claude     # or codex / agy / pi / opencode / dsh
```

The shell is zsh with the powerlevel10k prompt (config in `zsh/p10k.zsh`, copied from the host's `~/.p10k.zsh`) and autosuggestions. Shell history is kept in the `zsh-history` volume. Use a Nerd Font in your terminal for the icons. The host's `zshrc` is not copied, because it holds machine-specific paths and tools; edit `zsh/zshrc` to change the container's.

To run several agents side by side, start `herdr` in the shell. It gives each agent its own pane and shows whether it is working, blocked or done. Sessions keep running after you detach. The herdr prefix key is `ctrl+a` and its panes open zsh (both set in `herdr/config.toml`). The herdr integrations for claude, codex, opencode, pi and agy are installed at build time so herdr can see each agent's state. If a volume was created before an integration existed, run `herdr integration install <agent>` once (`antigravity-cli` for agy).

**Multi-agent team (work in progress).** [inodex](https://github.com/udai-kiran/inodex) is installed and registered as an MCP server for claude, codex, agy, opencode, pi and dsh (dsh via `dsh-cordis.patch.yml`, its home-level patch), so agents message each other through the `inodex` volume (`~/.inodex`). Agent guidance adapted from [multi-agent-workflow](https://github.com/udai-kiran/multi-agent-workflow) now lives in this repo: `claude/` (settings, hooks, status line, `CLAUDE.md`, merged into `~/.claude`), `codex/AGENTS.md` (reviewer guidance), `personas/` (-> `~/personas/`; the orchestrator names one in `task.assigned`). Volumes only pick up the image's files when first created, so for an existing one run `docker compose down -v` or copy them in by hand.

**Team (claude orchestrates, codex reviews, agy/pi/dsh work).** Role prompts are in `~/roles/` (source: `roles/`). Open one herdr pane per agent, start the tool, and paste one line:

| Pane | Command | First message |
| --- | --- | --- |
| orchestrator | `claude` | `Read ~/roles/orchestrator.md and follow it.` |
| reviewer | `codex` | `Read ~/roles/reviewer.md and follow it.` |
| workers | `agy`, `pi`, `dsh` | `Read ~/roles/worker.md and follow it. Your name is <agy\|pi\|dsh>.` |

Start the workers and the reviewer first, then give the orchestrator a task. The message types and rules are in `roles/protocol.md`; when everything is approved the orchestrator sends `team.stop` and each agent ends its turn.

**Traces.** `docker compose up -d traces` serves a read-only page of every inodex message, grouped by task, at http://127.0.0.1:8000 (code in `traces/`; `/api/threads` and `/api/messages` return JSON). `e2e/run.sh` is an end-to-end test of the whole team (see its header; `REVIEWER=pi` when codex is unavailable). inodex has no sender authentication, so a message's `from` is only what the sender claimed.

**dsh** ([DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), developer preview) needs a profile: `dsh headless "task"` answers one task and exits. Its state lives in the `dsh` volume (`~/.dsh`). `dsh web` serves a browser UI, but the compose file does not publish a port for it yet. There is no terminal UI profile in the npm package.

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
