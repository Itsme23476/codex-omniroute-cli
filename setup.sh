#!/usr/bin/env bash
# codex-omniroute-cli — point the OpenAI Codex CLI at OmniRoute models.
# Safe & idempotent: adds an OmniRoute *provider* + opt-in *profiles*.
# It never changes your default model, so your normal Codex (ChatGPT
# account) keeps working — you only get OmniRoute when you pass --profile.
#
# Usage:
#   ./setup.sh [OMNIROUTE_API_KEY]
#   curl -fsSL <raw-url>/setup.sh | bash -s -- YOUR_OMNIROUTE_API_KEY
set -euo pipefail

OMNIROUTE_URL="${OMNIROUTE_URL:-http://localhost:20128}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_HOME/config.toml"
KEY="${1:-${OMNIROUTE_API_KEY:-}}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Codex CLI present? (auto-install with npm if available)
if ! command -v codex >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    say "Codex CLI not found — installing with: npm install -g @openai/codex"
    npm install -g @openai/codex
  else
    die "Codex CLI not installed and npm not found. Install it first: https://developers.openai.com/codex/ (npm i -g @openai/codex)"
  fi
fi
say "Codex CLI: $(command -v codex) ($(codex --version 2>/dev/null || echo '?'))"

# 2. Is OmniRoute reachable?
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$OMNIROUTE_URL/v1/models" || echo 000)"
if [ "$code" = "000" ]; then
  warn "OmniRoute not reachable at $OMNIROUTE_URL — start OmniRoute before running codex. (Continuing to write config.)"
else
  say "OmniRoute is up at $OMNIROUTE_URL (HTTP $code on /v1/models — 401 is fine, it just means auth is required)."
fi

# 3. API key (arg > env > prompt). Get yours from OmniRoute's dashboard.
if [ -z "$KEY" ]; then
  printf 'Paste your OmniRoute API key (from %s/dashboard): ' "$OMNIROUTE_URL"
  read -r KEY
fi
[ -n "$KEY" ] || die "No API key provided."

mkdir -p "$CODEX_HOME"
touch "$CONFIG"

# 4. Write a managed [model_providers.omniroute] block (idempotent; replaces
#    any previous run's block, leaves the rest of your config untouched).
BEGIN="# >>> omniroute (managed by codex-omniroute-cli) >>>"
END="# <<< omniroute (managed by codex-omniroute-cli) <<<"
tmp="$(mktemp)"
awk -v b="$BEGIN" -v e="$END" '
  $0==b {skip=1}
  skip==0 {print}
  $0==e {skip=0}
' "$CONFIG" > "$tmp"
{
  cat "$tmp"
  printf '\n%s\n' "$BEGIN"
  cat <<'TOML'
[model_providers.omniroute]
name = "OmniRoute"
base_url = "http://localhost:20128/v1"
env_key = "OMNIROUTE_API_KEY"
wire_api = "responses"
TOML
  printf '%s\n' "$END"
} > "$CONFIG"
rm -f "$tmp"
say "Wrote [model_providers.omniroute] into $CONFIG"

# 5. Opt-in profile files (current Codex uses per-file profiles).
write_profile() { printf 'model = "%s"\nmodel_provider = "omniroute"\n' "$2" > "$CODEX_HOME/$1.config.toml"; }
write_profile omniroute-best-coding    "auto/best-coding"
write_profile omniroute-best-reasoning "auto/best-reasoning"
write_profile omniroute-fast           "auto/fast"
write_profile omniroute-cheap          "auto/cheap"
write_profile omniroute-free           "auto/best-free"
say "Wrote profiles: omniroute-best-coding, -best-reasoning, -fast, -cheap, -free"

# 6. Persist the key as an env var (Codex does NOT read .env — it needs a real
#    environment variable named by env_key above).
export OMNIROUTE_API_KEY="$KEY"
rc=""
case "${SHELL:-}" in
  *zsh)  rc="$HOME/.zshrc" ;;
  *bash) rc="$HOME/.bashrc" ;;
esac
if [ -n "$rc" ]; then
  if grep -q '^export OMNIROUTE_API_KEY=' "$rc" 2>/dev/null; then
    tmp="$(mktemp)"; grep -v '^export OMNIROUTE_API_KEY=' "$rc" > "$tmp"; mv "$tmp" "$rc"
  fi
  printf '\n# OmniRoute API key for the Codex CLI\nexport OMNIROUTE_API_KEY="%s"\n' "$KEY" >> "$rc"
  say "Saved OMNIROUTE_API_KEY to $rc"
  warn "Open a NEW terminal (or run: export OMNIROUTE_API_KEY=\"$KEY\") so the key is loaded."
fi

cat <<EOF

✅ Done. Use OmniRoute from the Codex CLI:

  codex --profile omniroute-best-coding
  codex --profile omniroute-best-coding exec "say CODEX_OMNIROUTE_OK"

Profiles:  omniroute-best-coding | -best-reasoning | -fast | -cheap | -free
Your normal Codex is untouched — omit --profile to use your ChatGPT account.
EOF
