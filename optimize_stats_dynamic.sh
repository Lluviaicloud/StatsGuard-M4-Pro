#!/usr/bin/env bash
set -euo pipefail
DIR="/Users/luispelaez/Desktop/stats sh"
BIN="/Users/luispelaez/bin"
STATE="/Users/luispelaez/Library/Logs/.stats_pause_state"
CMD="${1:-auto}"
now=$(date +%s)
pids=$(pgrep -x Stats || true)

case "$CMD" in
  force_pause)
    for pid in $pids; do renice 20 -p "$pid" >/dev/null 2>&1 || true; kill -STOP "$pid" 2>/dev/null || true; done
    echo $((now+600)) > "$STATE"
    exit 0
    ;;
  force_resume)
    for pid in $pids; do kill -CONT "$pid" 2>/dev/null || true; renice 0 -p "$pid" >/dev/null 2>&1 || true; done
    rm -f "$STATE"
    exit 0
    ;;
  status)
    s="running"; [ -f "$STATE" ] && s="paused_until_$(cat "$STATE" 2>/dev/null || echo 0)"
    echo "$s"
    [ -n "$pids" ] && ps -o pid,stat,ni,comm -p $pids
    exit 0
    ;;
esac

pwr=$(pmset -g batt | grep -qi "AC Power" && echo AC || echo BATT)
mem=$(memory_pressure | awk '/System-wide memory free percentage:/ {gsub("%","",$NF); print $NF}')
[ -z "$mem" ] && mem=100
load1=$(sysctl -n vm.loadavg | awk -F'[{} ]+' '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+$/){print $i; exit}}')
[ -z "$load1" ] && load1=0

if [ "$pwr" = AC ]; then dur=60; cmem=$([ "${mem%.*}" -lt 10 ] && echo 1 || echo 0); cload=$(awk "BEGIN{print ($load1>6)?1:0}"); else dur=90; cmem=$([ "${mem%.*}" -lt 15 ] && echo 1 || echo 0); cload=$(awk "BEGIN{print ($load1>4)?1:0}"); fi

if [ "$cmem" = 1 ] || [ "$cload" = 1 ]; then 
  echo $((now+dur)) > "$STATE"
  for pid in $pids; do renice 20 -p "$pid" >/dev/null 2>&1 || true; kill -STOP "$pid" 2>/dev/null || true; done
fi

if [ -f "$STATE" ] && [ "$now" -ge "$(cat "$STATE" 2>/dev/null || echo 0)" ]; then 
  for pid in $pids; do kill -CONT "$pid" 2>/dev/null || true; renice 0 -p "$pid" >/dev/null 2>&1 || true; done
  rm -f "$STATE"
fi

[ -z "$pids" ] && open -ga Stats

# LOG FINAL
s="running"; [ -f "$STATE" ] && s="paused_until_$(cat "$STATE" 2>/dev/null || echo 0)"
echo "$(date '+%Y-%m-%d %H:%M:%S') Stats:$s pids:"$(pgrep -x Stats || echo none)" pwr:$pwr mem:${mem}% load:$load1" >> ~/Library/Logs/stats-dynamic.log
