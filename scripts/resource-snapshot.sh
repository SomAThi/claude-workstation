#!/bin/bash
set -eu
printf 'time=%s\n' "$(date -u +%FT%TZ)"
free -m
awk '/oom_kill|pswpin|pswpout/ {print}' /proc/vmstat
cat /proc/pressure/memory
