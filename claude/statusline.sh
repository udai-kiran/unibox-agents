#!/usr/bin/env bash
# GOAT status line for Claude Code.
# Reads one JSON session blob on stdin and prints two colored rows.
# Dependency-light: jq + git only. Runs on every render, so keep it fast.

input=$(cat)

# --- ANSI palette ---------------------------------------------------------
R=$'\033[0m'; B=$'\033[1m'; DIM=$'\033[2m'
GRN=$'\033[38;5;42m'; YEL=$'\033[38;5;220m'; RED=$'\033[38;5;203m'
CYN=$'\033[38;5;44m'; MAG=$'\033[38;5;177m'; BLU=$'\033[38;5;75m'
GRY=$'\033[38;5;245m'; ORG=$'\033[38;5;215m'

# --- one jq pass: newline-delimited scalars (empty lines preserved) -------
# NOTE: newline-delimited into mapfile, NOT tab into read: tab is IFS
# whitespace so read collapses adjacent tabs and drops empty fields,
# shifting every later column. mapfile -t keeps empty lines positional.
mapfile -t F < <(printf '%s' "$input" | jq -r '
  [ .model.display_name // "?",
    .workspace.current_dir // .cwd // ".",
    (.context_window.used_percentage // "" | tostring),
    (.cost.total_cost_usd // 0 | tostring),
    (.cost.total_duration_ms // 0 | tostring),
    (.rate_limits.five_hour.used_percentage // "" | tostring),
    (.effort.level // ""),
    (.thinking.enabled // false | tostring),
    (.pr.number // "" | tostring),
    (.pr.review_state // "")
  ] | .[]')
model=${F[0]}; cur_dir=${F[1]}; ctx=${F[2]}; cost=${F[3]}; dur_ms=${F[4]}
rl5=${F[5]}; effort=${F[6]}; thinking=${F[7]}; pr_num=${F[8]}; pr_state=${F[9]}

dir_name=$(basename "$cur_dir")

# --- account identity (from ~/.claude.json, NOT the session blob) ---------
# The stdin session JSON carries no account info, so read the logged-in
# account out-of-band. Same value for every session on this machine.
acct=""; org=""
acct_file="$HOME/.claude.json"
if [ -f "$acct_file" ]; then
  mapfile -t A < <(jq -r '.oauthAccount // {} | [ .emailAddress // "", .organizationName // "" ] | .[]' "$acct_file" 2>/dev/null)
  acct=${A[0]}; org=${A[1]}
fi

# --- git branch + dirty count --------------------------------------------
branch=""; dirty=""
if git -C "$cur_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cur_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  n=$(git -C "$cur_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] 2>/dev/null && dirty="±${n}"
fi

# --- LINE 1: identity -----------------------------------------------------
line1="${MAG}🐐 ${B}${model}${R}   ${CYN}📁 ${dir_name}${R}"
if [ -n "$branch" ]; then
  line1+="   ${GRN} ${branch}${R}"
  [ -n "$dirty" ] && line1+="${YEL}${dirty}${R}"
fi
if [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved)          ps="${GRN}✔${R}";;
    changes_requested) ps="${RED}✗${R}";;
    pending)           ps="${YEL}◌${R}";;
    draft)             ps="${GRY}◑${R}";;
    *)                 ps="";;
  esac
  line1+="   ${BLU}PR#${pr_num}${R} ${ps}"
fi
[ -n "$acct" ] && line1+="   ${GRY}👤 ${acct}${R}"
[ -n "$org" ]  && line1+="   ${DIM}🏢 ${org}${R}"

# --- LINE 2: telemetry ----------------------------------------------------
# context-usage bar (8 cells), colored by fill level
bar=""; pct_str=""
if [ -n "$ctx" ] && [ "$ctx" != "null" ]; then
  pct=${ctx%.*}; [ -z "$pct" ] && pct=0
  filled=$(( (pct * 8 + 50) / 100 )); [ "$filled" -gt 8 ] && filled=8
  if   [ "$pct" -ge 85 ]; then c=$RED
  elif [ "$pct" -ge 60 ]; then c=$YEL
  else c=$GRN; fi
  cells=""
  for i in $(seq 1 8); do
    [ "$i" -le "$filled" ] && cells+="█" || cells+="░"
  done
  bar="${c}${cells}${R}"
  pct_str="${c}${pct}%${R} ${DIM}ctx${R}"
fi

# cost
cost_fmt=$(printf '$%.2f' "$cost" 2>/dev/null)
# duration ms -> Xm Ys
secs=$(( ${dur_ms%.*} / 1000 )); mins=$(( secs / 60 )); rem=$(( secs % 60 ))
if [ "$mins" -gt 0 ]; then dur_fmt="${mins}m ${rem}s"; else dur_fmt="${rem}s"; fi

line2="$bar"
[ -n "$pct_str" ] && line2+="  $pct_str"
# separator only when something precedes it (avoids a dangling leading "·")
sep() { [ -n "$line2" ] && printf '  %s·%s ' "$GRY" "$R"; }
line2+="$(sep)${GRN}${cost_fmt}${R}"
line2+="$(sep)${GRY}${dur_fmt}${R}"
if [ -n "$rl5" ] && [ "$rl5" != "null" ]; then
  r=${rl5%.*}
  if   [ "$r" -ge 85 ]; then rc=$RED
  elif [ "$r" -ge 60 ]; then rc=$YEL
  else rc=$GRY; fi
  line2+="  ${GRY}·${R} ${DIM}5h${R} ${rc}${r}%${R}"
fi
if [ -n "$effort" ]; then
  line2+="  ${GRY}·${R} ${ORG}⚡${effort}${R}"
fi
[ "$thinking" = "true" ] && line2+=" ${MAG}✦${R}"

printf '%s\n%s\n' "$line1" "$line2"
