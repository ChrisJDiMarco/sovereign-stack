# The Sovereign Stack Blueprint
### Build Your Own Autonomous AI Agent OS — Complete Implementation Guide
**Free & open source (MIT) · v1.1 · Last updated June 2026**

> **This is a living document.** The tools below move fast. Each chapter notes the version it was last verified against — if a command has drifted, [open an issue or PR](https://github.com/ChrisJDiMarco/sovereign-stack/issues) and the fix gets folded back in for everyone. Always sanity-check install commands against each project's current docs.
>
> **What's new in v1.1:** this revision adds the operational depth that separates a working demo from a system you'd trust to run autonomously with your budget and credentials — a dedicated **security chapter** (zero public ports, sandboxing, prompt-injection defense), **cost controls that actually hold** (circuit breakers, not just monthly caps), **reliability** (liveness supervision, safe backups), **observability + evals**, and a **second-brain** layer. These changes come from studying how the best builders (and the cautionary failures, like OpenClaw's security incidents) actually run these stacks.

---

## Table of Contents

**Build it**
1. What You're Building (and how it compares to OpenClaw / managed tools)
2. VPS Selection + Bare-Metal Setup (Tailscale-first networking)
3. Hermes Agent — Install + Configuration
4. Paperclip Control Plane — Install + First Run
5. Telegram Gateway — Your Phone Interface
6. Day 1 Org Chart: 3 Agents That Work
7. Scheduled Routines + Event-Driven Wakeups

**Harden it**
8. Securing Your Sovereign Stack
9. Cost Control That Actually Holds
10. Reliability & Supervision
11. Backups & Recovery
12. Observability & Evals

**Extend it**
13. Voice Layer (Mac, optional)
14. Your Second Brain — a Markdown vault the agents maintain

**Reference**
15. Architecture Diagram + Honest Cost Model
16. Troubleshooting
17. Keeping It Current
18. What to Build Next

---

## 1. What You're Building

By the end of this guide you will have:

- **3 AI agents running 24/7** on a ~$5/month VPS, with persistent memory across every session
- **Telegram DM access from your phone** — message your CEO agent like a person, get real work done
- **Paperclip control plane** — visual org chart, per-agent cost caps, governance approvals
- **Event-driven wakeups + scheduled routines** — briefings, journaling, and inbox triage that run themselves
- **A hardened, sandboxed, observable stack** — zero public ports, code execution in a sandbox, traces you can actually read
- **Optional voice interface and a self-maintaining second brain**

### Own it instead of renting it

Managed agent products (Perplexity Computer and the like) are genuinely good. If you'd rather pay a subscription and let someone else run everything, that's a perfectly reasonable choice — and their traction proves the market is real.

The Sovereign Stack is for the opposite instinct: **the memory, the data, and the cost ceiling all live on hardware you control.** Your VPS, your SQLite memory file, your API keys with hard caps. Nothing leaves a box you own.

### "Why not just run OpenClaw for free?"

Fair question — and worth answering honestly. [OpenClaw](https://github.com/openclaw/openclaw) is a real, hugely popular open-source personal-agent project, and its architecture is strikingly similar to this one (file-backed Markdown memory, on-demand skills, a gateway daemon, chat-app control). The convergence is a good sign: **this is the design pattern the field settled on.**

But OpenClaw's explosive growth came with a security reputation that's instructive: a one-click remote-code-execution CVE, tens of thousands of instances accidentally left exposed to the public internet, and a community skill marketplace that shipped hundreds of malicious skills. Its own creator warned that *"most non-techies should not install this."*

That's exactly the gap this guide fills. The software underneath is free — what's scarce is a **curated, secured, opinionated path** through it: how to wire the pieces together *and* not get owned doing it. That's why Chapter 8 (Security) is a first-class part of the build, not an afterthought. If you take one thing from this guide, take the security posture.

**Realistic monthly cost**: ~$69/month all-in (a ~$5 VPS + your own metered API usage, which you cap).
**Setup time**: one focused weekend for Chapters 1–7; another half-day for the hardening chapters (8–12), which are where the real value is.

---

## 2. VPS Selection + Bare-Metal Setup

*Verified against Ubuntu 24.04 LTS, Node 22, Tailscale, June 2026.*

### Recommended: Hetzner CX22

- **Provider**: hetzner.com — **Plan**: CX22 (2 vCPU, 4 GB RAM, 40 GB SSD) — **~$5/month**
- **OS**: Ubuntu 24.04 LTS — **Region**: closest to you

> Any 2 vCPU / 4 GB VPS works. **Sizing note:** 4 GB is enough for Hermes + Paperclip + Caddy. If you also run n8n *and* Paperclip's embedded PostgreSQL *and* an observability stack (Ch.12) on the same box, go up a tier (CX32, 8 GB) or move n8n/observability to a second instance — otherwise you'll hit OOM.

### Initial server setup

```bash
ssh root@YOUR_SERVER_IP
apt update && apt upgrade -y
apt install -y curl git wget unzip build-essential sqlite3

# Node via NVM (check nvm-sh/nvm for the current tag)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 22 && nvm use 22 && nvm alias default 22

npm install -g pnpm pm2          # Paperclip needs pnpm 9.15+
apt install -y python3 python3-pip python3-venv

# PM2 survives reboots
pm2 startup systemd -u root --hp /root   # run the line it prints, then:
pm2 save
```

### Networking: Tailscale-first, zero public ports (do this before anything else)

**This is the single most important setup decision, and it's where most self-hosted agent disasters start.** The default instinct — bind the control-plane UI to `0.0.0.0` and reverse-proxy it publicly — is exactly what got tens of thousands of OpenClaw instances scanned and attacked within minutes of going online. Don't expose the control plane to the internet at all.

Instead, put the box on a private [Tailscale](https://tailscale.com) network and bind every app to `localhost`. You reach the Paperclip UI and n8n from your laptop/phone over the tailnet — **no public port required.** The Telegram gateway needs no inbound port either (it uses an outbound long-poll connection), so your agents are reachable from your phone with nothing exposed.

```bash
# Install Tailscale and join your tailnet
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
tailscale set --shields-up        # block inbound connections from other tailnet devices by default

# Firewall: deny inbound on the public interface; allow the tailnet
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0        # full access over the private network
ufw allow 22/tcp                  # keep public SSH until you've confirmed SSH-over-tailnet works (then remove it)
ufw enable
ufw status
```

> Once you've confirmed you can `ssh root@<tailscale-ip>`, you can `ufw delete allow 22/tcp` to remove public SSH entirely. **Do that only after** the tailnet path works, or you'll lock yourself out.

### Optional: a public landing page via Caddy

You only need this if you want a genuinely public URL (e.g. a marketing page). **Do not** put the Paperclip control plane or n8n behind a public Caddy route — keep those on the tailnet. If you do run Caddy for a public site, allow 80/443 (`ufw allow 80,443/tcp`) and let Caddy handle TLS automatically. For everything operational, Tailscale is the front door.

---

## 3. Hermes Agent — Install + Configuration

*Hermes is Nous Research's open-source persistent-memory agent. Verified against the published docs, June 2026 — confirm the current install command and config keys at hermes-agent.nousresearch.com/docs.*

### Install

Use the **documented installer** (more stable than a raw GitHub file path), and **pin to a release tag** rather than tracking upstream master (Hermes moves fast — see Ch.17):

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
hermes --version
```

### What you actually get (stated precisely)

This matters because the technical reader will notice if it's overstated — and the honest version is still the lab-endorsed pattern:

- **Always-loaded memory is two small, bounded Markdown files** (`MEMORY.md` and a user-profile file), kept intentionally tiny (low-thousands of characters each) and **frozen at session start** to preserve prompt caching. This is *exactly* the "bounded memory blocks" pattern Letta/MemGPT and Anthropic endorse — small, curated, durable facts, not a dumping ground.
- **Cross-session recall is a separate SQLite + FTS5 layer** you query with a search tool. Be clear-eyed: **FTS5 is keyword search, not semantic** — a query phrased differently than the stored text can miss. If you want semantic recall, add **one** external memory provider; prefer a **local/on-box** one to stay on-VPS and on-budget rather than a paid cloud service in a $5/mo narrative.
- **60+ built-in tools** out of the box, plus user-authored skills loaded on demand (progressive disclosure keeps token cost flat).
- **Claude-native**, with OpenAI, OpenRouter, and any OpenAI-compatible endpoint.

> **Memory tradeoff to decide deliberately (don't inherit it by accident):** Hermes *freezes* memory at session start (cheap, cache-stable long sessions — but a preference you state mid-session isn't reflected until the next one). OpenClaw-style agents *re-read* memory every turn (immediately live, but pricier and cache-breaking). For bursty phone-DM usage, fresh-read feels more responsive; for long sessions, frozen is cheaper. Just **document the choice** so you're not surprised when a mid-session "remember that I prefer X" doesn't stick until tomorrow.

### Configure providers (and the two settings that prevent the most pain)

Configure via Hermes' config file (confirm exact keys in the current docs):

```yaml
default_provider: anthropic
providers:
  anthropic:
    api_key: ${ANTHROPIC_API_KEY}     # env var, never a literal key in a file you might commit
fallback_providers: [openrouter]       # so a provider outage doesn't take the stack down

# THE single biggest cost lever: route cheap auxiliary work to a cheap model.
# Titling, vision, and context compression can be ~85% of background spend.
auxiliary:
  title:       { provider: openrouter, model: <a cheap fast model> }
  vision:      { provider: openrouter, model: <a cheap vision model> }
  compression: { provider: openrouter, model: <a cheap fast model> }

memory:
  backend: sqlite
  path: ~/.hermes/memory.db
```

```bash
chmod 600 ~/.hermes/config.yaml
```

> **Enforce a 64k+ context window.** The #1 "my agent has no memory!" bug is an undersized context (a local model defaulting to ~4096 tokens silently truncates everything). Hermes refuses contexts below 64k for good reason — if you use a local model, set its context to 64k+ explicitly (e.g. an Ollama `Modelfile` with `num_ctx 65536`).

### Bounded-memory discipline

Keep `MEMORY.md` and the user-profile file **tiny and curated** — durable preferences and conventions, never raw transcripts. Let episodic detail live in the searchable session store. Mutating the bounded files constantly defeats prompt caching (it can multiply your bill). Treat them like a config file you occasionally edit, not a scratchpad.

### Test

```bash
hermes run --prompt "Hello. Tell me your name and what tools you have."
ls -la ~/.hermes/            # config + memory.db + sessions/ + skills/
hermes sessions search "hello"
```

---

## 4. Paperclip Control Plane

*Paperclip is the open-source "AI company OS." Verified against github.com/paperclipai/paperclip, June 2026. Requires Node 20+ / pnpm 9.15+.*

Paperclip gives your agents a governance layer — visual org chart, per-agent cost caps, a wakeup queue with budget checks, and approval flows. **Treat the agent loop as an opaque adapter and let Paperclip own scheduling, cost, approvals, and the audit trail** — that separation is the whole point of a control plane.

### Install (it auto-provisions its own database)

Paperclip's onboarder **auto-provisions an embedded PostgreSQL — no manual DB setup.** (If you've seen older SQLite `DATABASE_URL` instructions anywhere, ignore them; Paperclip uses PostgreSQL and sets it up for you.) Bind it to your tailnet, **not** the public internet:

```bash
# Tailnet bind — reachable over Tailscale, no public port
npx paperclipai onboard --yes --bind tailnet
```

Manual install if you want the repo checked out:

```bash
git clone https://github.com/paperclipai/paperclip.git ~/paperclip
cd ~/paperclip && pnpm install
cp .env.example .env          # set ANTHROPIC_API_KEY etc.; leave the DB config as the example provides
pnpm db:migrate
pnpm dev                      # API on :3100 (bind to localhost), UI alongside — Ctrl+C when verified
```

> Check the repo's current `.env.example` for exact variable names — it's the source of truth.

### Run under PM2 (secrets stay in `.env`, hardened restart policy)

```bash
cat > ~/paperclip/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'paperclip',
    cwd: '/root/paperclip',
    script: 'pnpm',
    args: 'start',
    env: { NODE_ENV: 'production', PORT: '3100' },   // no secrets here — Paperclip reads its own .env
    max_memory_restart: '600M',                       // bound leaks (see Ch.10)
    restart_delay: 5000,
    max_restarts: 10
  }]
};
EOF
chmod 600 ~/paperclip/.env
pm2 start ~/paperclip/ecosystem.config.js && pm2 save
pm2 status
```

Access the UI over Tailscale (e.g. `http://<tailscale-ip>:3100`). Create your admin account on first login.

---

## 5. Telegram Gateway — Your Phone Interface

The Hermes gateway is a long-running process that listens for Telegram messages and routes them to your agents. It connects *outbound*, so it needs **no inbound port** — a genuine security win.

### Create a bot

1. Telegram → `@BotFather` → `/newbot` → pick a name + username → save the **bot token**.
2. Message `@userinfobot` to get **your numeric Telegram user ID**.

### Configure + lock it down

In your Hermes config (confirm exact keys in the docs), set the Telegram `bot_token` and an **allow-list of user IDs**. This allow-list is your authentication — without it, anyone who finds the bot can talk to your agents and spend your budget.

> **Gotcha (the #1 gateway support question):** the user allow-list key is the per-user **`allow_from` / `TELEGRAM_ALLOWED_USERS`**, *not* a group-chat whitelist key — those control which *group chats* the bot replies in, not who's authorized. Use the per-user one.

Run it under PM2:

```bash
cat > ~/hermes-gateway.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'hermes-gateway',
    script: 'hermes',
    args: 'gateway start',
    max_memory_restart: '400M',
    restart_delay: 3000,
    max_restarts: 20
  }]
};
EOF
pm2 start ~/hermes-gateway.config.js && pm2 save
```

> If Hermes also runs a local dashboard, bind it to loopback (no auth needed) or your tailnet — never `0.0.0.0`. Use the `hermes gateway install` service path rather than leaving it in a `tmux` window, and make sure your shell init (nvm/pyenv PATH) is captured so tools resolve under the service.

### Test from your phone

DM your bot: `Hello — who are you and what can you do?` Expect a reply in ~1s. No response → `pm2 logs hermes-gateway`.

---

## 6. Day 1 Org Chart — 3 Agents

Three agents is a **deliberate ceiling**, not a starting point you grow casually. The field has learned this the hard way: solo builders repeatedly *delete* their multi-agent setups because maintenance outgrows value. The rule that keeps a small team reliable:

> **One stateful writer, read-only/sandboxed helpers, handoffs through task records — and don't add a fourth agent unless the *contract* genuinely changes.**

- The **CEO** is the single orchestrator and the only owner of the user-facing reply and durable state.
- **Research** is **read-only** intelligence.
- **Builder** writes only inside its own **sandbox** (Ch.8).
- CEO→Research and CEO→Builder handoffs go through **Paperclip task records**, not direct agent-to-agent calls — that gives you a replayable audit trail and avoids the "telephone game" of agents passing context to each other.

> **Model IDs drift.** The IDs below were current in June 2026 (Claude Opus 4.8 / Sonnet 4.6). Confirm the current IDs in the Anthropic docs at setup — a stale ID is the #1 first-run error.

### Tiered routing (don't send trivial asks to the frontier model)

Before the prompts: not every message needs Opus. Route the easy 90% (classification, simple lookups, titling) to a cheaper/smaller model and reserve the frontier model for genuine reasoning. Set Hermes' `auxiliary.*` models cheap (Ch.3), and in the CEO prompt encode **effort-scaling** ("simple requests get a direct answer or one tool call; don't over-spawn agents"). This is the difference between a stack people use daily and one they turn off over cost/latency.

### Agent 1: CEO (orchestration + memory + the only writer)

- **Adapter**: hermes_local · **Model**: `claude-opus-4-8` (or `claude-sonnet-4-6` to save cost)
- **Heartbeat**: every 6 hours · **Monthly budget cap**: $50 (and see Ch.9 for the harder caps)

```
You are the CEO of a one-person AI company. Your operator is {{OPERATOR_NAME}}.

You are the ONLY agent that holds durable state and the only one that replies to
{{OPERATOR_NAME}}. Your job: orchestrate, decide, remember.

When a task needs a specialist, create a Paperclip task for Research or Builder with
clear instructions, context, and the expected output format — never call them directly.
Read their task results, then you decide and reply.

Scale effort to the request: a simple question gets a direct answer or one tool call.
Do not spawn agents or chain tools for trivial asks.

Before any irreversible, external, or money-spending action, stop and ask for approval.

You have persistent memory. Reference it, keep it curated, be the continuity layer.
Be direct and brief.
```

### Agent 2: Research (read-only — and behind an injection boundary)

- **Adapter**: hermes_local · **Model**: `claude-sonnet-4-6` · **Heartbeat**: on assignment only · **Cap**: $30

```
You are a read-only research analyst. You receive tasks from the CEO via Paperclip.
Tools: web search/scraping and document analysis. You do NOT take actions in the
world and you do NOT hold the operator's action tools.

For every task: state what you're researching, list sources before summarizing, flag
anything unverified, and return findings as structured output (claims + sources), not
raw pasted pages. Never fabricate data.
```

> **Critical security pattern — the dual-LLM boundary (see Ch.8).** Research reads untrusted web/email content, which is the textbook *indirect prompt-injection* vector: a single malicious blog post or RSS item could carry instructions that hijack an agent holding your tools. So Research is deliberately **tool-poor and read-only**: it ingests untrusted content and returns a *structured summary*. The CEO (which holds the action tools) acts on that structured output and **never reads the raw page**. This quarantine is the highest-value architectural defense you can build into the stack.

### Agent 3: Builder (writes only inside a sandbox)

- **Adapter**: claude_local (Claude Code) · **Model**: `claude-sonnet-4-6` · **Heartbeat**: on assignment only · **Cap**: $40

```
You are a senior software engineer. You receive coding tasks from the CEO via Paperclip.
You run inside a sandbox with access only to your project workspace.

For every task: read the ticket, plan before coding, write clean tested code, then report
what you built, how to use it, and any open questions. Follow TDD where it fits. No magic
numbers. Handle errors explicitly.
```

> The Builder executes generated code. That is dangerous on a host that holds your API keys — **it must run sandboxed** (Ch.8). Never let it run unsandboxed on the VPS.

### A reviewer gate before irreversible actions

For high-stakes or high-spend actions, add a lightweight **clean-context reviewer** step: a verifier with no shared context checks the plan/output before it executes. A fresh-eyes reviewer reliably catches mistakes the actor can't see in its own context.

---

## 7. Scheduled Routines + Event-Driven Wakeups

Across every honest build log, **scheduled autonomous routines are what people keep using** — morning briefings, evening journaling, inbox triage — while generic chatbot chat is the first thing abandoned. Ship these as templates, not as a "someday" idea.

### Hermes cron (the cost-responsible way)

Hermes runs natural-language cron jobs in **fresh, isolated sessions**. Two rules keep them from burning tokens:

1. **Use `--no-agent` script jobs and a `wakeAgent: false` gate** for watchdog-style checks, so a tick that finds nothing doesn't spin up an LLM.
2. **Write self-contained prompts** — a cron session starts fresh, so it can't rely on prior context. (And never schedule recursive cron-from-cron.)

**Starter routines** (adapt the schedules):

- **Morning briefing (08:00):** "Summarize my calendar, flagged emails, and any overnight task results into a 5-bullet briefing; send it to me on Telegram."
- **Evening journal (20:00):** "Ask me three reflection questions; when I reply, append my answers + today's completed tasks to today's note in my second brain (Ch.14)."
- **Inbox triage (hourly, gated):** a `--no-agent` check that only wakes an agent if new high-priority mail arrived — then it drafts (never sends) replies for approval.

### Event-driven wakeups via n8n

Paperclip exposes a wakeup endpoint for external triggers (confirm the exact route in your build):

```
POST http://localhost:3100/api/agents/{agentId}/wakeup
Body: { "source": "automation", "triggerDetail": "...", "context": "..." }
```

Run n8n in Docker (its old `N8N_BASIC_AUTH_*` vars are deprecated — current n8n uses an owner account), bound to localhost behind Tailscale:

```bash
docker volume create n8n_data
docker run -d --restart unless-stopped --name n8n \
  -p 127.0.0.1:5678:5678 \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n
```

Example: an RSS/webhook trigger detects a competitor post or a risk-level change → n8n POSTs to the relevant agent's wakeup endpoint with the payload as `context`.

### Proactive-trigger discipline (so you don't mute it in a week)

An assistant that pings constantly gets silenced fast. The rules that keep proactive features welcome:

- **Batch** routine signals into the scheduled briefings instead of firing one ping each.
- **Honor quiet hours.**
- **Say why** each proactive message fired.
- **Stay silent when there's nothing worth saying.**
- **Earn autonomy gradually** — start with "draft for approval," expand to "act and report" only once you trust a given routine.

---

## 8. Securing Your Sovereign Stack

**This is the chapter that makes the difference between an asset and a liability.** A self-hosted agent holds your keys, reads untrusted input, and can take real actions — the threat model is real, and the free tools in this space have a track record of getting people owned. Budget the half-day.

### 8.1 Attack surface: keep it at zero public ports

You did the main thing in Ch.2 (Tailscale + loopback binds, UFW default-deny). Confirm it:

- The Paperclip UI/API and n8n are bound to `localhost` or the tailnet — **not** `0.0.0.0`. Verify with `ss -tlnp` (nothing operational should be listening on a public interface).
- The Telegram gateway needs no inbound port at all.
- SSH is key-only and ideally tailnet-only. Harden it:

```bash
# /etc/ssh/sshd_config.d/hardening.conf
PasswordAuthentication no
PermitRootLogin prohibit-password
# then:  systemctl restart ssh   (after confirming your key works AND tailnet SSH works)
apt install -y fail2ban && systemctl enable --now fail2ban
```

### 8.2 Dedicated, scoped service accounts — never your personal credentials

Every integration the agents touch (Gmail, GitHub, calendar, etc.) should use a **dedicated account or per-use-case API key, scoped to the minimum**:

- Read-only wherever the task allows.
- One key per use case (so you can revoke/attribute without collateral).
- Destructive scopes stay behind owner-approval (8.4).

Why it matters: if the box is breached or an agent is prompt-injected, the blast radius is bounded by what that scoped key can do — not by everything *you* can do. (A real-world incident: an agent with a found long-lived token deleted a production database in nine seconds. Least privilege is the seatbelt.)

### 8.3 Prompt injection & the dual-LLM boundary

LLMs **cannot reliably separate instructions from data** — any agent that reads web pages, emails, or documents can be hijacked by instructions hidden in that content. Filters and "ignore previous instructions" guards only slow attackers down; the durable defense is **architectural**:

- **Quarantine untrusted reads** in the read-only Research agent (Ch.6). It returns a *structured summary*; the tool-holding CEO acts only on that structure and never ingests the raw page.
- **Mark data vs. instructions** explicitly in prompts that must include external text.
- Treat any guardrail model as one defense-in-depth layer, not a fix.

### 8.4 Risk-tiered human approval (wire it to Paperclip)

Not every action deserves the same trust. Classify tools and gate them — Paperclip's approval flow is built for exactly this:

| Tier | Examples | Policy |
|------|----------|--------|
| **LOW** | web search, read a file, draft text | auto-run |
| **MEDIUM** | send a Telegram message, write a file in the workspace | auto-run, logged |
| **HIGH** | post externally, email on your behalf, delete data | **require approval** |
| **CRITICAL** | spend money, move funds, change infra, touch credentials | **explicit human confirmation, never auto** |

Default-deny for anything you haven't classified. A destructive or financial action must never be reachable by an auto-running loop.

### 8.5 Sandbox the Builder agent

The Builder runs generated code with shell access — confine it so a buggy or injected build step can't read your keys or wipe the box:

- Run it in a **hardened container**: drop all capabilities (`--cap-drop ALL`), read-only root filesystem, **no network by default** (allowlist egress if a task needs it), no `docker.sock`, never `--privileged`, mount only its project workspace.
- Apply CPU/memory/PID/timeout limits.
- Keep long-lived credentials and `~/.ssh` out of the sandbox entirely.

(OS-level sandboxing — Linux Landlock + seccomp — is a lighter alternative on a single box. Firecracker microVMs are overkill unless you're running genuinely hostile/multi-tenant code.)

### 8.6 Skills are untrusted code — vet them

A "skill" executes with the agent's permissions. A public skill marketplace is a supply-chain attack surface (OpenClaw's shipped hundreds of malicious skills — credential stealers, reverse shells). So:

- **Review the `SKILL.md` and any payload before installing.** Pin/vendor the skills you trust.
- **Never auto-install skills from a public registry into a privileged agent.** Keep Hermes' skill `write_approval` on.
- Treat your own agent-authored skills as data you periodically review and prune.

---

## 9. Cost Control That Actually Holds

Paperclip's per-agent monthly caps are necessary but **not sufficient on their own** — a monthly cap trips *after* a runaway loop has already burned the money (4k tokens doubling each step is ~32× by step 5). "Best-effort budget" is not enforcement. Add real walls:

### Hard, fast-tripping limits

- **Per-session token cap** and a **per-run step / tool-chain depth limit** so one loop can't spend the month overnight.
- **Cost-velocity circuit breakers** that trip at *N×* your planned $/min *before* the monthly cap is reached.
- The **cheap-auxiliary-model** lever from Ch.3 (titles/vision/compression on a cheap model ≈ the biggest single background-spend reduction).
- **64k+ context** enforced everywhere (an undersized context both breaks memory *and* silently re-sends truncated junk).

### A self-hosted LiteLLM gateway in front of all three agents

Put a single [LiteLLM](https://github.com/BerriAI/litellm) proxy between your agents and the providers. It centralizes what you otherwise can't see or control per-agent:

- **Per-key budgets and rate limits** (each agent gets its own key with its own ceiling).
- **Fallback chains** (provider outage → next provider, no downtime).
- **Cheaper-model routing** by task.
- **Per-key cost attribution** — so "which agent got expensive" is a number, not a guess. It runs on your box, keeping spend telemetry on your infrastructure.

```bash
pip install litellm        # or run the official Docker image; see docs.litellm.ai
# config.yaml: define model_list, per-key max_budget + rpm/tpm limits, and fallbacks,
# then point each agent's base_url at the proxy.
```

The point: the ~$5/mo infra story is only credible if the *variable* cost has hard walls. This is how you make "you control exactly what each agent spends" true rather than aspirational.

---

## 10. Reliability & Supervision

"Runs 24/7" has to survive the most common failure mode, which **PM2's crash-restart does not catch: an agent that's alive but wedged.** A deadlocked gateway stays `online` in PM2 forever; a restart-on-crash policy never fires.

### PM2 hygiene (already partly in Ch.4/5)

```bash
pm2 install pm2-logrotate              # logs won't fill the 40GB disk
# max_memory_restart is set in each ecosystem file (bounds memory leaks)
pm2 startup systemd -u root --hp /root && pm2 save   # survives reboot
```

### Liveness — detect "alive but stuck"

Add an external health probe that restarts a wedged process. Simplest version — a cron that checks the control plane responds and restarts it on timeout:

```bash
cat > /root/healthcheck.sh << 'EOF'
#!/bin/bash
# If Paperclip's local API doesn't answer in 10s, restart it.
curl -fs --max-time 10 http://localhost:3100/health >/dev/null 2>&1 || pm2 restart paperclip
# Add a similar probe for the gateway (e.g. a heartbeat file it touches each loop).
EOF
chmod +x /root/healthcheck.sh
( crontab -l 2>/dev/null; echo "*/5 * * * * /root/healthcheck.sh" ) | crontab -
```

> The more robust option, if a process supports it, is a **systemd unit with `WatchdogSec` + `sd_notify` heartbeats** and `Restart=on-watchdog` (plus `StartLimitBurst` so a crash-loop doesn't hammer the box). Use that for anything that can emit a heartbeat; use the external probe above for anything that can't.

---

## 11. Backups & Recovery

Your agents' memory is the single most valuable, hardest-to-recreate thing on the box. **The naïve backup — `tar` of a live SQLite file — can capture a mid-write, corrupt, unrestorable snapshot.** Do it correctly:

### Consistent SQLite snapshots (not a raw file copy)

```bash
cat > /root/backup-stack.sh << 'EOF'
#!/bin/bash
set -e
STAMP=$(date +%F-%H%M)
mkdir -p /root/backups
# Online-consistent SQLite snapshot (safe while Hermes is running):
sqlite3 ~/.hermes/memory.db ".backup '/root/backups/memory-$STAMP.db'"
# Paperclip's PostgreSQL — back up the ACTUAL DB, not just .env:
#   (use Paperclip's documented dump command, or pg_dump against its embedded instance)
# Configs/skills:
tar czf "/root/backups/configs-$STAMP.tgz" ~/.hermes/config.yaml ~/.hermes/skills ~/paperclip/.env 2>/dev/null || true
ls -1t /root/backups/memory-*.db   | tail -n +15 | xargs -r rm
ls -1t /root/backups/configs-*.tgz | tail -n +15 | xargs -r rm
EOF
chmod +x /root/backup-stack.sh
( crontab -l 2>/dev/null; echo "30 3 * * * /root/backup-stack.sh" ) | crontab -
```

### Continuous + off-box + tested

- **Continuous:** [Litestream](https://litestream.io) streams the live SQLite memory to S3-compatible storage with point-in-time restore — purpose-built for exactly this single-node case.
- **Off-box & encrypted:** push snapshots to object storage or another machine with `restic`/`borg` (deduped, encrypted). A backup that only lives on the same VPS dies with the VPS.
- **Snapshots:** enable Hetzner VPS snapshots for whole-box recovery.
- **Schedule a RESTORE DRILL.** Restore into a throwaway path and confirm the memory is queryable. *An untested backup is not a backup.*

---

## 12. Observability & Evals

You can't govern what you can't see. The stack claims "cost transparency per task" — make it real, and give yourself a way to know when a version bump made the agents worse.

### Tracing with self-hosted Langfuse

[Langfuse](https://langfuse.com) (OSS core, free to self-host) runs via docker-compose on the box, keeping traces on your infrastructure. Instrument the three agents to emit, per run: the **model version, prompt/config hash, tool snapshot, and per-call token cost**. Then you get the per-agent spend dashboard the design implies, and behavior drift becomes an attributable diff ("the CEO got more expensive after the model bump") instead of a mystery. Add anomaly alerts: cost/session, tool-calls/min, and injection-attempt counts.

### A tiny evals harness (the maturity step before you trust autonomy)

Before you hand agents budget and autonomy, build a cheap safety net:

- **~20 representative real cases** (the things you actually ask).
- **End-state evaluation** — did it reach the right final state? — not brittle step-by-step matching.
- **One rubric-based LLM-as-judge call** per case (score 0–1 on accuracy / completeness / source quality / tool efficiency, plus pass-fail), with human spot-checks.
- **Re-run the 20 cases after any Hermes / Paperclip / model bump** to catch drift introduced by the fast-moving dependencies this guide already warns about.

Ship it as a script in your repo. It's the difference between "it worked when I set it up" and "I know it still works."

---

## 13. Voice Layer (Mac, optional)

Hands-free dictation on your Mac. Optional, runs on your laptop, not the VPS — and the field consensus is that voice is polish, not the core (context and memory come first).

### The sovereign default: macOS built-in dictation

On Apple Silicon, macOS dictation runs **on-device** — free, private, nothing leaves your machine. **System Settings → Keyboard → Dictation → On**, pick a shortcut, dictate into any field including Telegram Desktop.

### Optional: Vibing (richer, but cloud-based — know the trade-off)

[Vibing](https://github.com/VibingJustSpeakIt/Vibing) (powered by Microsoft VibeVoice) adds context-aware rewriting. Install via the Mac setup guide in its repo.

> ⚠️ **Privacy trade-off, stated plainly.** Per Vibing's own FAQ, it **sends your audio and context — including screenshots, active-field text, and the current app name — to its servers** (it says this isn't retained). That's cloud processing of your screen contents, which cuts against this stack's whole premise. If sovereignty is why you're here, use the built-in macOS dictation. Use Vibing only if you've decided the richer rewriting is worth sending that context off-box.

---

## 14. Your Second Brain — a Markdown vault the agents maintain

This is what turns "three agents on a VPS" into a personal OS you actually live in. Pair the stack with a **plain-Markdown knowledge vault** the agents file *for* you — and the agents do the busywork that makes people abandon manual note-taking.

- **Substrate: plain Markdown files + folders**, in a directory the CEO/Research agents can read and write. No vector-DB-as-primary-store, no lock-in — any future agent (or you, or Obsidian) can read the same vault. The field consensus is blunt: "files and folders structured well enough that an AI can navigate them" beats a database for a personal OS.
- **The agents do the filing.** The CEO interviews you, designs the folder structure, creates and migrates notes, and links them with `[[wikilinks]]`. You stop curating; you start reviewing.
- **Tier the memory** so it doesn't bloat: raw capture → daily notes → weekly summaries → monthly rollups, with the agent promoting the durable bits up the chain. This is the same bounded-memory discipline from Ch.3, applied to your knowledge instead of the agent's working memory.

Wire it to the routines in Ch.7: the evening-journal routine appends to today's note; a weekly routine rolls up the week. Over months, this becomes the thing you'd actually miss if the box vanished — which is also why Ch.11 (backups) matters.

---

## 15. Architecture Diagram + Cost Model

```
  YOUR PHONE (Telegram)  ──►  Hermes Gateway  ──►  CEO Agent  ──►  reply (~1s)
                                     │ (outbound long-poll — no inbound port)
        ┌────────────────────────────┴───────────────────────────┐
        │            HETZNER CX22 VPS (~$5/mo)  ·  TAILSCALE-ONLY  │
        │  PM2/Docker: paperclip · hermes-gateway · n8n · langfuse │
        │  Agents:  CEO (sole writer) ─ tasks ─► Research (RO)     │
        │                              └─ tasks ─► Builder (sandbox)│
        │  LiteLLM proxy → per-agent budgets · fallback · routing   │
        │  NO public ports (control plane reachable via Tailscale)  │
        └──────────────────────────────────────────────────────────┘
             ▲ n8n webhooks                  ▲ your API keys (capped via LiteLLM)
       business signals              Anthropic / OpenAI / OpenRouter
```

### Monthly cost (honest, itemized)

| Item | Cost |
|------|------|
| Hetzner CX22 VPS | $5.00 |
| Tailscale (personal) | $0.00 |
| Domain (optional, amortized) | $0.83 |
| Claude API — CEO (moderate use) | $25.00 |
| Claude API — Research (moderate) | $15.00 |
| Claude API — Builder (on-demand) | $15.00 |
| Web search/scraping (optional) | ~$8.00 |
| **Total** | **~$69/month** |

The VPS is ~$5; the rest is **your own API usage, capped per agent (Ch.9)**. There's no platform fee — you pay providers directly.

---

## 16. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Telegram bot doesn't reply | gateway down, or your ID isn't in `allow_from` | `pm2 logs hermes-gateway`; verify the per-user allow-list (not the group key) |
| "model not found" on first run | stale model ID | confirm the current Claude model ID in the Anthropic docs |
| Agent "has no memory" | context window too small (e.g. local model at 4096) | set context to 64k+ (`num_ctx 65536`); don't conflate bounded `MEMORY.md` with FTS5 search |
| Paperclip won't start / DB errors | tried SQLite, or migrations didn't run | use `npx paperclipai onboard` (embedded PostgreSQL); read its current `.env.example` |
| Can't reach the UI | bound to localhost (correct) | reach it over Tailscale, or `ssh -L 3100:localhost:3100` |
| Process "online" but unresponsive | wedged, not crashed | the Ch.10 health probe should restart it; check the probe is installed |
| Costs spiked overnight | runaway loop hit the monthly cap late | add per-session token + step caps and a velocity breaker (Ch.9) |
| Box sluggish / OOM | too many services on 4 GB | move n8n/Langfuse off, or upgrade to CX32 (8 GB) |
| Backup won't restore | tarred a live DB mid-write | use `sqlite3 .backup` / Litestream; run restore drills (Ch.11) |

---

## 17. Keeping It Current

Hermes and Paperclip are fast-moving (Hermes pushes same-day as releases and defaults to tracking upstream master). Unpinned updates change agent behavior "in small but fatal ways."

- **Pin exact versions** and commit lockfiles for Hermes, Paperclip, Node, and model SDKs. Pin Hermes to a known-good **release tag** rather than master.
- **Gate updates** with Renovate/Dependabot PRs you test in isolation — don't pull `main` into production.
- **Beware in-place updates of running agents.** Redeploying or hot-swapping prompts/tool-defs *under* a mid-flight execution (e.g. one paused on a human approval) makes the model reinterpret old results against new schemas **with no error** — a silent corruption, not a crash. Pin each execution to the version it started on, and drain in-flight work before decommissioning.
- **Re-run your evals (Ch.12)** after every bump.
- This guide is versioned on GitHub — watch the repo, and [open a PR](https://github.com/ChrisJDiMarco/sovereign-stack/issues) if a step drifts.

---

## 18. What to Build Next

Once the core stack is hardened and running:

**Resist the agent-army trap.** The single most common regret in personal-AI-OS build logs is adding agents until maintenance outweighs use. Add a fourth agent only when the *contract* genuinely changes — not just because a new domain appeared (a new Hermes *skill* usually serves better than a new agent).

**Good next steps:**
- Deepen the **second brain** (Ch.14) — more routines that file and summarize for you.
- Add **custom skills** for your specific domains (vetted, per Ch.8.6).
- Expand **observability** into per-agent spend dashboards (Ch.12).
- Add a second **gateway channel** (Slack/Discord) alongside Telegram if you actually need it.
- Promote a routine from "draft for approval" to "act and report" once its evals and your trust support it.

---

*The Sovereign Stack Blueprint — free & open source (MIT) — v1.1, June 2026*
*Questions or fixes: [open an issue on GitHub](https://github.com/ChrisJDiMarco/sovereign-stack/issues)*
