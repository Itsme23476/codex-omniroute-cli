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

# If the *default* provider was omniroute (common when the setup was used as
# the main provider, not just opt-in profiles), removing the block would leave
# a dangling `model_provider = 'omniroute'` and Codex fails to start. Comment
# it out instead of deleting it, so the change is visible and reversible.
if grep -qE "^[[:space:]]*model_provider[[:space:]]*=[[:space:]]*['\"]omniroute['\"]" "$CONFIG"; then
  tmp="$(mktemp)"
  awk -v q="'\"" '
    /^\[/ { in_table = 1 }
    !in_table && $0 ~ ("^[[:space:]]*model_provider[[:space:]]*=[[:space:]]*[" q "]omniroute[" q "]") {
      print "# " $0 "   # disabled by uninstall.sh: the omniroute provider was removed"
      next
    }
    { print }
  ' "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
  echo "==> Commented out the default 'model_provider = \"omniroute\"' (provider no longer exists)"
fi

# Remove the OMNIROUTE_API_KEY line (and its comment) that setup.sh added.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -q '^export OMNIROUTE_API_KEY=' "$rc" 2>/dev/null; then
    tmp="$(mktemp)"
    # `|| true`: grep exits 1 when a pattern has no matches, which under
    # `set -euo pipefail` would abort the whole uninstall mid-way.
    { grep -v '^export OMNIROUTE_API_KEY=' "$rc" \
      | grep -v '^# OmniRoute API key for the Codex CLI$' || true; } > "$tmp"
    mv "$tmp" "$rc"
    echo "==> Removed OMNIROUTE_API_KEY from $rc"
  fi
done

echo "Done — Codex is back to normal. Open a new terminal so the removed key clears."
