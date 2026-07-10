#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
dirname=$(basename "$cwd")
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# Your title here.
title="${dirname}"

COST=$(echo "$input" | jq -r '.cost.total_cost_usd // ""')
COST_FMT=$(printf '$%.2f' "$COST")
model=$(echo "$input" | jq -r '.model.display_name // ""')

CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CACHE_CREATION=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CACHE_TOTAL=$((CACHE_READ + CACHE_CREATION + INPUT_TOKENS))
CACHE_RATE=0
[ "$CACHE_TOTAL" -gt 0 ] && CACHE_RATE=$((CACHE_READ * 100 / CACHE_TOTAL))

used_context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
# Build progress bar: printf creates spaces, tr replaces with blocks
BAR_WIDTH=10
FILLED=$((used_context_pct * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '▓')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

# Your status line here.
statusline="${dirname} | ${branch} | 💰${COST_FMT} | ${model} | 🎯${CACHE_RATE}% | ${BAR}"

[ -n "$branch" ] && title="${title} | ${branch}"
printf "\033]0;%s\007" "$title" > /dev/tty 2>/dev/null

echo "${statusline}"
