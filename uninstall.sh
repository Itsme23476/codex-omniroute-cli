#!/usr/bin/env bash
# Remove what setup.sh added: the managed OmniRoute provider block and the
# five profile files. Leaves the rest of your Codex config and your
# OMNIROUTE_API_KEY shell line untouched.
set -euo pipefail
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_HOME/config.toml"
BEGIN="# >>> omniroute (managed by codex-omniroute-cli) >>>"
END="# <<< omniroute (managed by codex-omniroute-cli) <<<"

if [ -f "$CONFIG" ]; then
  tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1}
    skip==0 {print}
    $0==e {skip=0}
  ' "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
  echo "==> Removed the OmniRoute provider block from $CONFIG"
fi

for p in best-coding best-reasoning fast cheap free; do
  rm -f "$CODEX_HOME/omniroute-$p.config.toml"
done
echo "==> Removed omniroute-* profile files"

# Remove the OMNIROUTE_API_KEY line (and its comment) that setup.sh added.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -q '^export OMNIROUTE_API_KEY=' "$rc" 2>/dev/null; then
    tmp="$(mktemp)"
    grep -v '^export OMNIROUTE_API_KEY=' "$rc" \
      | grep -v '^# OmniRoute API key for the Codex CLI$' > "$tmp"
    mv "$tmp" "$rc"
    echo "==> Removed OMNIROUTE_API_KEY from $rc"
  fi
done

echo "Done — Codex is back to normal. Open a new terminal so the removed key clears."
