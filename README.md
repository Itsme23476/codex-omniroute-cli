# codex-omniroute-cli

Make the **OpenAI Codex CLI** use **OmniRoute** models — with one command.
Undo it anytime with one command. Your normal Codex keeps working the whole time.

Follow the steps in order. Each step tells you exactly what to type and what you should see.

---

## ⚠️ Read this first (30 seconds)

- This is built for the **Codex CLI** (the terminal). That is the supported path.
  The Codex desktop app behaves differently across versions: some builds route
  through the provider you configure, others ignore it and force OpenAI models
  while you're signed in with a ChatGPT account. Don't judge the setup by the app.
- You need **two things ready** before you start (Step 0).

---

## Step 0 — Get the two things you need

**A) OmniRoute must be running.**
Open a browser and go to: **http://localhost:20128/dashboard**
- If a dashboard loads → good, OmniRoute is running. ✅
- If nothing loads → open OmniRoute and start it first, then come back.

**B) Get your OmniRoute API key.**
On that same dashboard, find your **API key** and copy it. You'll paste it in Step 1.
(It's a long string. Keep it handy.)

---

## Step 1 — Install (choose ONE option)

### Option 1 — One command (recommended, easiest) ⭐

Copy this line, **replace `YOUR_KEY`** with the key from Step 0, paste it into your terminal, press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/Itsme23476/codex-omniroute-cli/main/setup.sh | bash -s -- YOUR_KEY
```

**What you should see at the end:**
```
✅ Done. Use OmniRoute from the Codex CLI:
  codex --profile omniroute-best-coding
```
If you see that, you're set. Go to Step 2.

---

### Option 2 — Let the Codex CLI do it (nice for a video)

1. In your terminal, type `codex` and press Enter (this uses your normal ChatGPT account).
2. Paste the **Setup prompt** (see "Copy-paste prompts" near the bottom), with your key filled in.
3. Approve the command when Codex asks. When it finishes, go to Step 2.

---

### Option 3 — Do it by hand (if you don't want to run a script)

1. Open the file `~/.codex/config.toml` in any text editor (if it doesn't exist, create it).
2. Add these **exact** lines at the bottom and save:
   ```toml
   [model_providers.omniroute]
   name = "OmniRoute"
   base_url = "http://localhost:20128/v1"
   env_key = "OMNIROUTE_API_KEY"
   wire_api = "responses"
   ```
3. Create a file named `~/.codex/omniroute-best-coding.config.toml` with these two lines and save:
   ```toml
   model = "auto/best-coding"
   model_provider = "omniroute"
   ```
4. Tell your terminal your key (replace `YOUR_KEY`), then press Enter:
   ```bash
   echo 'export OMNIROUTE_API_KEY="YOUR_KEY"' >> ~/.zshrc && export OMNIROUTE_API_KEY="YOUR_KEY"
   ```
5. Go to Step 2.

---

## Step 2 — Use it

Open a **new terminal window** (important — this loads your key), then type:

```bash
codex --profile omniroute-best-coding
```

Codex now runs on OmniRoute. Test it — ask it anything, e.g. type: `say CODEX_OMNIROUTE_OK`.
- You'll see a header line: `provider: omniroute` and a `model:` line naming the
  profile's model. That means it's working. ✅
- (You may see a small yellow warning `Model metadata ... not found`. Ignore it — it's harmless, the answer still comes back.)
- One-shot test from your shell (note the flag — without it Codex refuses to
  start outside a git repository):
  ```bash
  codex --profile omniroute-best-coding exec --skip-git-repo-check "say CODEX_OMNIROUTE_OK"
  ```

**Other speeds/models** — same command, different profile:
```bash
codex --profile omniroute-fast            # quick + cheap
codex --profile omniroute-best-reasoning  # deeper thinking
codex --profile omniroute-cheap           # lowest cost
codex --profile omniroute-free            # free models
```

**To use your normal Codex again**, just leave off `--profile`:
```bash
codex
```

---

## Step 3 — Revert to normal (undo everything)

One command puts you completely back to a plain Codex:

```bash
curl -fsSL https://raw.githubusercontent.com/Itsme23476/codex-omniroute-cli/main/uninstall.sh | bash
```

**What you should see:**
```
Done — Codex is back to normal.
```
This removes the OmniRoute provider, the profiles, and the key line. Open a new terminal and `codex` is exactly as it was before.

(Or, from inside `codex`, paste the **Revert prompt** below.)

---

## Copy-paste prompts (for a video)

Two short prompts you can paste **into the `codex` terminal**. Fill in your key in the first one.

**▶ Setup prompt** — makes Codex route itself through OmniRoute:
```
I have OmniRoute (an OpenAI-compatible model gateway) running locally at http://localhost:20128, and I want you — the Codex CLI — to start using its models. Run this one command exactly as written, then tell me to run `codex --profile omniroute-best-coding`:

curl -fsSL https://raw.githubusercontent.com/Itsme23476/codex-omniroute-cli/main/setup.sh | bash -s -- YOUR_KEY
```

**◀ Revert prompt** — puts Codex back to normal:
```
Undo the OmniRoute setup and put me back to my normal Codex. Run this one command exactly as written and confirm when it's done:

curl -fsSL https://raw.githubusercontent.com/Itsme23476/codex-omniroute-cli/main/uninstall.sh | bash
```

---

## If something goes wrong

| You see… | It means… | Fix |
|---|---|---|
| `command not found: codex` | Codex CLI isn't installed | The one-command setup installs it automatically. Or install Node.js, then `npm i -g @openai/codex`. |
| `Error loading config.toml: ... Cannot declare ... twice` | two `[model_providers.omniroute]` tables in `config.toml` | Re-run `setup.sh` (it now de-duplicates), or delete the extra block by hand. |
| `Error loading config.toml: invalid type ... AgentRoleToml` | your Codex CLI is older than the config it's reading | `npm i -g @openai/codex@latest` (config schema changes between versions). |
| `503 Maximum combo retry limit reached` | the `auto/*` combo found no usable upstream (deposit/quota) | Use a concrete model, e.g. `OMNIROUTE_MODEL_CODING=antigravity/gemini-3.8-flash-tiered ./setup.sh KEY`. |
| `401` / `invalid_api_key` | key is wrong or not loaded | Open a **new terminal**, or run `export OMNIROUTE_API_KEY="YOUR_KEY"`, then retry. |
| `Connection refused` | OmniRoute isn't running | Start OmniRoute; check http://localhost:20128/dashboard loads. |
| yellow `Model metadata ... not found` | cosmetic warning only | Ignore it — answers still work. |
| works in terminal, fails in the **desktop app** | expected on some app versions | Use the CLI. The app may force OpenAI models on a ChatGPT account. |

---

Tested with `codex-cli 0.153.3` against OmniRoute on `localhost:20128`. Do whatever you want with it.
