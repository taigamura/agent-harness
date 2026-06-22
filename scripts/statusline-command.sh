#!/usr/bin/env bash
input=$(cat)

extract() {
  echo "$input" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"?[^,\"}]+\"?" | head -1 | sed -E "s/.*:[[:space:]]*\"?([^\"]*)\"?$/\1/"
}

model=$(extract "display_name")
[ -z "$model" ] && model="Claude"
used_pct=$(extract "used_percentage")
total_in=$(extract "total_input_tokens")
total_out=$(extract "total_output_tokens")
ctx_size=$(extract "context_window_size")

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
DIM=$'\033[2m'

parts="$model"

if [ -n "$total_in" ] && [ -n "$ctx_size" ]; then
  DUMB_THRESHOLD=100000
  total_in_int=$(printf '%.0f' "$total_in" 2>/dev/null)
  [ -z "$total_in_int" ] && total_in_int=0

  fill=$(( total_in_int * 10 / DUMB_THRESHOLD ))
  [ $fill -gt 10 ] && fill=10
  [ $fill -lt 0 ] && fill=0

  bar=""
  i=0
  while [ $i -lt 10 ]; do
    if [ $i -lt $fill ]; then
      bar="${bar}█"
    else
      bar="${bar}░"
    fi
    i=$(($i+1))
  done

  if [ $total_in_int -lt 50000 ]; then
    color="$GREEN"
    label="SMART"
  elif [ $total_in_int -lt 100000 ]; then
    color="$YELLOW"
    label="OK"
  else
    color="$RED"
    label="DUMB"
  fi

  in_k=$(( total_in_int / 1000 ))
  size_int=$(printf '%.0f' "$ctx_size" 2>/dev/null)
  size_k=$(( size_int / 1000 ))

  used_int=""
  if [ -n "$used_pct" ]; then
    used_int=$(printf '%.0f' "$used_pct" 2>/dev/null)
  fi

  if [ -n "$used_int" ]; then
    parts="$parts | ${color}${BOLD}[${bar}] ${label}${RESET} ${color}${in_k}k/${size_k}k (${used_int}%)${RESET}"
  else
    parts="$parts | ${color}${BOLD}[${bar}] ${label}${RESET} ${color}${in_k}k/${size_k}k${RESET}"
  fi
fi

if [ -n "$total_out" ] && [ "$total_out" -gt 0 ] 2>/dev/null; then
  parts="$parts ${DIM}| out: ${total_out}${RESET}"
fi

printf "%s" "$parts"
