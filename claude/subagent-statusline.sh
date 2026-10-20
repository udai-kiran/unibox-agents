#!/usr/bin/env bash
# Subagent status line for Claude Code.
# Overrides each agent-panel row to surface the resolved model, plus name,
# effort, status and per-row context-usage %.
#
# Input : one JSON object on stdin with a .tasks[] array.
# Output: one compact JSON line per row to override -> {"id":..,"content":..}.

input=$(cat)

R=$'\033[0m'; B=$'\033[1m'; DIM=$'\033[2m'
MAG=$'\033[38;5;177m'; BLU=$'\033[38;5;75m'; ORG=$'\033[38;5;215m'
GRY=$'\033[38;5;245m'

printf '%s' "$input" | jq -c \
  --arg R "$R" --arg B "$B" --arg DIM "$DIM" \
  --arg MAG "$MAG" --arg BLU "$BLU" --arg ORG "$ORG" --arg GRY "$GRY" '
  .tasks[]?
  | select(.id != null and .id != "")
  | ( .name // .label // .description // .type // "task" )                    as $nm
  | ( .model // "" )                                                          as $m
  | ( if $m == "" then "\($GRY)…\($R)"
      else "\($BLU)\($m | sub("^claude-"; "") | sub("-latest$"; ""))\($R)"
      end )                                                                   as $model
  | ( if (.effort == null) then "" else (.effort | tostring) end )           as $ef
  | ( .status // "" )                                                         as $st
  | ( if (.tokenCount != null and (.contextWindowSize // 0) > 0)
        then (.tokenCount / .contextWindowSize * 100 | floor)
        else null end )                                                      as $pct
  | { id: .id,
      content: (
        "\($MAG)◆\($R) \($B)\($nm)\($R)  \($DIM)·\($R) \($model)"
        + (if $ef  != "" then "  \($DIM)·\($R) \($ORG)⚡\($ef)\($R)" else "" end)
        + (if $st  != "" then "  \($DIM)\($st)\($R)" else "" end)
        + (if $pct != null then "  \($GRY)\($pct)% ctx\($R)" else "" end)
      )
    }
'
