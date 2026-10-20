# End-to-end test: orchestrator (claude) + reviewer + two workers (agy, dsh), 3 review rounds each.
# Run from the repo root:  docker compose run --rm -T agents zsh -c "$(cat e2e/run.sh)"
# REVIEWER=codex (default, the real architecture) or REVIEWER=pi when codex is unavailable.
# Watch it live at http://127.0.0.1:8000 (docker compose up -d traces).
set -u
REVIEWER=${REVIEWER:-codex}
rm -rf /workspace/e2e ~/.inodex/agents && mkdir -p /workspace/e2e/logs && cd /workspace/e2e
git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init

RULE='TEST RULE for the reviewer: round 1 - return changes_requested asking for type hints on every function. Round 2 - return changes_requested asking for a docstring with a usage example. Round 3 - approve if both are present in the files, otherwise changes_requested.'
TASK='TEST TASK. Two tasks in parallel with disjoint files: agy -> /workspace/e2e/agy_util.py with slugify(text) (lowercase, spaces to dashes), persona python-pro; dsh -> /workspace/e2e/dsh_util.py with is_palindrome(text), persona debugger. Correlation ids T-agy and T-dsh. Each goes through exactly 3 review rounds (kind correctness, round N in each review.requested). Put reviewer findings in notes when sending a task back. Nothing is committed. After both are approved at round 3, send team.stop and print a table: task, worker, rounds, final verdict.'
role() { echo "Read ~/roles/protocol.md and ~/roles/$1.md and follow them.${2:+ Your name is $2.}"; }

case $REVIEWER in
  codex) codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check "$(role reviewer) $RULE" < /dev/null > logs/reviewer.log 2>&1 & ;;
  pi) pi -p "$(role reviewer) $RULE" < /dev/null > logs/reviewer.log 2>&1 & ;;
  *) echo "REVIEWER must be codex or pi"; exit 2 ;;
esac
agy -p "$(role worker agy)" --dangerously-skip-permissions < /dev/null > logs/agy.log 2>&1 &
dsh headless "$(role worker dsh)" < /dev/null > logs/dsh.log 2>&1 &
sleep 25
timeout 2400 claude -p "$(role orchestrator) $TASK" --dangerously-skip-permissions < /dev/null > logs/orchestrator.log 2>&1
echo "orchestrator exit: $?"
sleep 30   # let the others see team.stop and exit on their own
echo "still running after team.stop: $(jobs -p | wc -l)"
jobs -p | xargs -r kill 2>/dev/null
echo "=== trace ==="
for f in ~/.inodex/agents/*/{inbox,processing,archive,deadletter}/*.json(N); do
  jq -r --arg box "${f:h:t}" '[.timestamp[11:23], .from, "->", .to, .type, .correlation_id, (.payload.round // "" | tostring), $box] | @tsv' $f
done | sort
echo "=== files ==="; head -50 /workspace/e2e/*_util.py
