# codex-omniroute-cli

Point the **OpenAI Codex CLI** at **OmniRoute** models in one command.

Your normal Codex (signed in with your ChatGPT account) keeps working exactly as before — this only *adds* an OmniRoute provider plus a few opt-in profiles. You get OmniRoute models only when you pass `--profile`.

> **Why the CLI and not the Codex desktop app?** The Codex **desktop app**, when you're signed in with a ChatGPT account, only allows OpenAI's own models — custom providers like OmniRoute get rejected server-side (`"... not supported when using Codex with a ChatGPT account"`). The **CLI** has no such restriction, so this is the reliable way to use OmniRoute with Codex.

---

## Prerequisites

1. **OmniRoute installed and running** on `http://localhost:20128` (its default). Open `http://localhost:20128/dashboard` to confirm.
2. **Your OmniRoute API key** — copy it from the OmniRoute dashboard.
3. **Node.js** (only if you don't already have the Codex CLI — the script installs Codex with `npm i -g @openai/codex`).

---

## Quick start (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/Itsme23476/codex-omniroute-cli/main/setup.sh | bash -s -- YOUR_OMNIROUTE_API_KEY
```

Or clone and run:

```bash
git clone https://github.com/Itsme23476/codex-omniroute-cli.git
cd codex-omniroute-cli
./setup.sh                # it will prompt for your key
```

Then **open a new terminal** (so your key is loaded) and go:

```bash
codex --profile omniroute-best-coding
```

---

## What it sets up

- Adds a managed `[model_providers.omniroute]` block to `~/.codex/config.toml` (idempotent — re-running just refreshes it, the rest of your config is untouched):
  ```toml
  [model_providers.omniroute]
  name = "OmniRoute"
  base_url = "http://localhost:20128/v1"
  env_key = "OMNIROUTE_API_KEY"
  wire_api = "responses"
  ```
- Writes five opt-in profile files in `~/.codex/`:

  | Profile | Model | For |
  |---|---|---|
  | `omniroute-best-coding` | `auto/best-coding` | coding work |
  | `omniroute-best-reasoning` | `auto/best-reasoning` | deeper reasoning |
  | `omniroute-fast` | `auto/fast` | quick responses |
  | `omniroute-cheap` | `auto/cheap` | lower cost |
  | `omniroute-free` | `auto/best-free` | free models |

- Saves `OMNIROUTE_API_KEY` to your shell profile (`~/.zshrc` or `~/.bashrc`). Codex reads the key from this environment variable — it does **not** read `.env` files.

---

## Usage

```bash
# interactive
codex --profile omniroute-best-coding

# one-shot
codex --profile omniroute-best-coding exec "say CODEX_OMNIROUTE_OK"

# other tiers
codex --profile omniroute-fast
codex --profile omniroute-best-reasoning
```

Omit `--profile` to use your normal ChatGPT-account Codex as usual.

---

## Troubleshooting

- **`Model metadata for 'auto/best-coding' not found. Defaulting to fallback`** — harmless. Codex just doesn't have context-window metadata for OmniRoute's routed models; the call still works.
- **`401` / `invalid_api_key`** — your `OMNIROUTE_API_KEY` is wrong or not loaded. Open a new terminal, or run `export OMNIROUTE_API_KEY="<your key>"`, then retry.
- **Connection refused / can't reach OmniRoute** — OmniRoute isn't running. Start it and confirm `http://localhost:20128/dashboard` loads.
- **It fails only in the desktop app** — expected. Use the CLI (see the note at the top).

---

## Uninstall

```bash
./uninstall.sh
```

Removes the managed provider block and the five profile files. It leaves the rest of your Codex config and your `OMNIROUTE_API_KEY` line alone (delete that from your `~/.zshrc` / `~/.bashrc` by hand if you want it gone).

---

## Alternative: a prompt you can paste into the Codex CLI

A script is more reliable for a demo, but if you'd rather have Codex configure itself, run `codex` (normal ChatGPT-account mode) and paste this:

```
Set up the Codex CLI to use my local OmniRoute gateway as a custom model provider. Do exactly this, nothing else:

1. In ~/.codex/config.toml, add (or replace) this exact block, without touching anything else in the file:

[model_providers.omniroute]
name = "OmniRoute"
base_url = "http://localhost:20128/v1"
env_key = "OMNIROUTE_API_KEY"
wire_api = "responses"

2. Create these profile files in ~/.codex/, each with the two lines shown:
   - omniroute-best-coding.config.toml   -> model = "auto/best-coding"    and model_provider = "omniroute"
   - omniroute-best-reasoning.config.toml-> model = "auto/best-reasoning" and model_provider = "omniroute"
   - omniroute-fast.config.toml          -> model = "auto/fast"           and model_provider = "omniroute"
   - omniroute-cheap.config.toml         -> model = "auto/cheap"          and model_provider = "omniroute"
   - omniroute-free.config.toml          -> model = "auto/best-free"      and model_provider = "omniroute"

3. Add `export OMNIROUTE_API_KEY="<I will paste my key>"` to my ~/.zshrc (replace any existing line for it).

Do NOT change my default model or model_provider. When done, tell me to run: codex --profile omniroute-best-coding
```

---

Tested with `codex-cli 0.153.3` against OmniRoute on `localhost:20128`. MIT-style: do whatever you want with it.
