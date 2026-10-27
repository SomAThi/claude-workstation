#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
while IFS= read -r script; do bash -n "$script"; done < <(find . -name '*.sh' -not -path './node/*' -not -path './browser/*')
python3 -m unittest discover -s tests
if command -v shellcheck >/dev/null; then shellcheck -S warning bootstrap.sh install.sh scripts/*.sh; else echo 'ShellCheck unavailable on this host'; fi
