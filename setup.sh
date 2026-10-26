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
  # When the script itself arrives over stdin (`curl | bash`), stdin is the
  # script body — reading from it would silently get EOF, so prompt on the tty.
  if [ -r /dev/tty ]; then
    printf 'Paste your OmniRoute API key (from %s/dashboard): ' "$OMNIROUTE_URL"
    read -r KEY < /dev/tty
  else
    die "No API key provided. Pass it as an argument: bash setup.sh YOUR_OMNIROUTE_API_KEY"
  fi
fi
[ -n "$KEY" ] || die "No API key provided."

# Check the key before writing it anywhere: a wrong key is otherwise only
# discovered later, inside codex, as a confusing 401.
auth_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
  -H "Authorization: Bearer $KEY" "$OMNIROUTE_URL/v1/models" || echo 000)"
case "$auth_code" in
  200)     say "API key accepted by OmniRoute." ;;
  000)     warn "Could not verify the key — OmniRoute unreachable at $OMNIROUTE_URL." ;;
  401|403) warn "OmniRoute rejected this API key (HTTP $auth_code) — check it in the dashboard." ;;
  *)       warn "Unexpected HTTP $auth_code while verifying the key." ;;
esac

mkdir -p "$CODEX_HOME"
touch "$CONFIG"

# 4. Write a managed [model_providers.omniroute] block.
#    Idempotent AND conflict-safe: also removes any pre-existing omniroute
#    table, hand-written or from an older tool. TOML forbids declaring the
#    same table twice, and a duplicate makes Codex die with
#    "Error loading config.toml" — which breaks *every* codex command.
BEGIN="# >>> omniroute (managed by codex-omniroute-cli) >>>"
END="# <<< omniroute (managed by codex-omniroute-cli) <<<"
backup="$CONFIG.omniroute-backup"
[ -f "$CONFIG" ] && cp -p "$CONFIG" "$backup"
tmp="$(mktemp)"
awk -v b="$BEGIN" -v e="$END" '
  $0==b {in_managed=1; next}
  $0==e {in_managed=0; next}
  in_managed {next}
  /^\[/ {
    if ($0 ~ /^\[model_providers\.omniroute[.\]]/) { in_omni=1; next }
    in_omni=0
  }
  in_omni {next}
  {print}
' "$CONFIG" > "$tmp"
{
  cat "$tmp"
  printf '\n%s\n' "$BEGIN"
  cat <<TOML
[model_providers.omniroute]
name = "OmniRoute"
base_url = "$OMNIROUTE_URL/v1"
env_key = "OMNIROUTE_API_KEY"
wire_api = "responses"
TOML
  printf '%s\n' "$END"
} > "$CONFIG"
rm -f "$tmp"

# Never leave behind a config Codex cannot parse.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$CONFIG" 2>/dev/null; then
    [ -f "$backup" ] && cp -p "$backup" "$CONFIG"
    die "The result would be invalid TOML — restored the backup and aborted (nothing changed)."
  fi
  say "Verified: $CONFIG parses as valid TOML."
else
  warn "python3 not found — skipped the TOML validation step."
fi
say "Wrote [model_providers.omniroute] into $CONFIG (backup: $backup)"

# 5. Opt-in profile files (current Codex uses per-file profiles).
#    Models are overridable so a re-run does not clobber custom choices, e.g.
#    OMNIROUTE_MODEL_CODING=antigravity/gemini-3.8-flash-tiered ./setup.sh KEY
write_profile() { printf 'model = "%s"\nmodel_provider = "omniroute"\n' "$2" > "$CODEX_HOME/$1.config.toml"; }
write_profile omniroute-best-coding    "${OMNIROUTE_MODEL_CODING:-auto/best-coding}"
write_profile omniroute-best-reasoning "${OMNIROUTE_MODEL_REASONING:-auto/best-reasoning}"
write_profile omniroute-fast           "${OMNIROUTE_MODEL_FAST:-auto/fast}"
write_profile omniroute-cheap          "${OMNIROUTE_MODEL_CHEAP:-auto/cheap}"
write_profile omniroute-free           "${OMNIROUTE_MODEL_FREE:-auto/best-free}"
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
  chmod 600 "$rc" 2>/dev/null || true   # the file now holds a secret
  say "Saved OMNIROUTE_API_KEY to $rc (chmod 600)"
  warn "Open a NEW terminal (or run: export OMNIROUTE_API_KEY=... ) so the key is loaded."
fi

cat <<EOF

✅ Done. Use OmniRoute from the Codex CLI:

  codex --profile omniroute-best-coding

Quick check (add --skip-git-repo-check when you are not inside a git repo):

  codex --profile omniroute-best-coding exec --skip-git-repo-check "say CODEX_OMNIROUTE_OK"

Profiles:  omniroute-best-coding | -best-reasoning | -fast | -cheap | -free
Your normal Codex is untouched — omit --profile to use your ChatGPT account.
Revert anytime: uninstall.sh (config backup: $backup)
EOF
