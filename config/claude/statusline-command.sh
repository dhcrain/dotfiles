#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
dirname=$(basename "$cwd")
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# Your title here.
title="${dirname}"

# Your status line here.
statusline="${dirname} | ${branch}"

[ -n "$branch" ] && title="${title} | ${branch}"
printf "\033]0;%s\007" "$title" > /dev/tty 2>/dev/null

echo "${statusline}"