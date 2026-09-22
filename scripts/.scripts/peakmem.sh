#!/bin/bash
# usage: peakmem.sh <label> <cmd...>  -- runs cmd, samples RSS of its whole process tree every 1s, prints peak (GB) + wall time
label=$1; shift
"$@" >"/tmp/peakmem-$label.log" 2>&1 &
root=$!
peak=0; start=$(date +%s)
descendants() { local p=$1; echo "$p"; for c in $(pgrep -P "$p"); do descendants "$c"; done; }
while kill -0 "$root" 2>/dev/null; do
  pids=$(descendants "$root" | tr '\n' ',' | sed 's/,$//')
  rss=$(ps -o rss= -p "$pids" 2>/dev/null | awk '{s+=$1} END{print s+0}')
  (( rss > peak )) && peak=$rss
  sleep 1
done
wait "$root"; rc=$?
printf "%s: peak_tree_rss=%.2fGB wall=%ss exit=%s\n" "$label" "$(echo "$peak/1048576" | bc -l)" "$(( $(date +%s) - start ))" "$rc"
