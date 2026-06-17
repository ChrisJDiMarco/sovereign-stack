# The Sovereign Stack Blueprint
### Build Your Own Autonomous AI Agent OS — Complete Implementation Guide
**Free & open source (MIT) · Last updated June 2026**

> **This is a living document.** The tools below move fast. Each chapter notes the version it was last verified against — if a command has drifted, [open an issue or PR](https://github.com/ChrisJDiMarco/sovereign-stack/issues) and the fix gets folded back in for everyone. Always sanity-check install commands against each project's current docs.

---

## Table of Contents

1. What You're Building (and Why You'd Own It Instead of Renting)
2. VPS Selection + Bare Metal Setup
3. Hermes Agent — Install + Configuration
4. Paperclip Control Plane — Install + First Run
5. Telegram Gateway — Your Phone Interface
6. Day 1 Org Chart: 3 Agents That Work
7. Event-Driven Wakeups via n8n
8. Voice Layer (Mac, Optional)
9. Architecture Diagram + Honest Cost Model
10. Troubleshooting
11. Backups & Recovery
12. Keeping It Current
13. What to Build Next

---

## 1. What You're Building

By the end of this guide you will have:

- **3 AI agents running 24/7** on a ~$5/month VPS, with persistent memory across every session
- **Telegram DM access from your phone** — message your CEO agent like a person, get real work done
- **Paperclip control plane** — visual org chart, per-agent cost caps, governance approvals
- **Event-driven wakeups** — business signals (filings, competitor content, risk spikes) wake your agents automatically via n8n webhooks
- **Optional voice interface on Mac** — hands-free dictation, local or cloud (your choice)

### Own it instead of renting it

Managed agent products (Perplexity Computer and the like) are genuinely good. If you'd rather pay a subscription and let someone else run everything, that's a perfectly reasonable choice — and their traction proves the market is real.

The Sovereign Stack is for the operator who wants the opposite: **the memory, the data, and the cost ceiling all live on hardware you control.** Your VPS, your SQLite memory file, your API keys with hard caps. Nothing leaves a box you own. The software is free and open source — this guide just saves you the weekend of figuring out how the pieces fit together.

**Realistic monthly cost**: ~$69/month all-in (a ~$5 VPS + your own metered API usage, which you cap).
**Setup time**: one focused weekend.

---

## 2. VPS Selection + Bare Metal Setup

*Verified against Ubuntu 24.04 LTS, Node 22, June 2026.*

### Recommended: Hetzner CX22

- **Provider**: hetzner.com
- **Plan**: CX22 — 2 vCPU, 4 GB RAM, 40 GB SSD
- **Cost**: ~$5/month (billed hourly)
- **OS**: Ubuntu 24.04 LTS
- **Region**: Closest to you

> Why Hetzner over DigitalOcean/AWS? Price. ~$5/month for this spec vs. $12–24/month elsewhere, with no meaningful difference for this stack. Any VPS with 2 vCPU / 4 GB works — this guide just uses the CX22 as the concrete example.
>
> **Sizing note:** 4 GB RAM is enough for Hermes + Paperclip + Caddy. If you also run n8n *and* Paperclip's embedded PostgreSQL on the same box (Chapter 7), watch your memory — consider the next tier up (CX32, 8 GB) or move n8n to its own small instance.

### Initial Server Setup

```bash
# SSH into your new server
ssh root@YOUR_SERVER_IP

# Update packages
apt update && apt upgrade -y

# Install essentials
apt install -y curl git wget unzip build-essential

# Install NVM (Node Version Manager) — check nvm-sh/nvm for the current version tag
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
nvm alias default 22
node --version   # expect v22.x

# Paperclip needs pnpm 9.15+
npm install -g pnpm

# Python (for some tooling)
apt install -y python3 python3-pip python3-venv

# PM2 process manager
npm install -g pm2
pm2 startup systemd -u root --hp /root   # run the command it prints, then:
pm2 save
```

### Firewall — keep the surface small

Only SSH and the web ports face the public internet. **Do not open the app ports (3100/5678) publicly** — Caddy reverse-proxies them, and the apps bind to localhost.

```bash
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP (Caddy redirects to HTTPS)
ufw allow 443/tcp    # HTTPS (Caddy)
ufw enable
ufw status
```

> If you need to reach Paperclip's UI before you've set up a domain, use an SSH tunnel (`ssh -L 3100:localhost:3100 root@YOUR_SERVER_IP`) rather than opening the port to the world.

### Caddy (Reverse Proxy + Auto-HTTPS)

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy

# Caddyfile — replace paperclip.yourdomain.com with your domain
cat > /etc/caddy/Caddyfile << 'EOF'
paperclip.yourdomain.com {
    reverse_proxy localhost:3100
}
EOF

systemctl restart caddy
systemctl status caddy   # expect "active (running)"
```

> **Domain**: point an A record at your VPS IP (Namecheap, Cloudflare, etc. — ~$10/year). Caddy provisions the TLS cert automatically.

---

## 3. Hermes Agent — Install + Configuration

*Hermes is Nous Research's open-source persistent-memory agent. Verified against the published docs, June 2026 — always confirm the current install command at the official docs.*

### Install Hermes

Use the **documented installer** (more stable than pointing at a raw file path in the repo):

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc

hermes --version
```

> Hermes installs its own runtime (Python + `uv`); the Node setup above is for Paperclip and n8n. The docs live at `hermes-agent.nousresearch.com/docs` and the source at `github.com/NousResearch/hermes-agent`.

### What you get

- Persistent **SQLite memory** that survives restarts, with **FTS5 full-text recall** across sessions
- **60+ built-in tools** out of the box, plus a self-improving skill loop (add your own custom skills)
- A **gateway** that serves one agent across many channels — CLI, **Telegram**, Discord, Slack, and more
- **Claude-native**, with OpenAI, OpenRouter, and any OpenAI-compatible endpoint also supported

### Configure providers

Hermes is configured via its config file (confirm the exact path/keys in the current docs — schema evolves). The shape is roughly:

```yaml
default_provider: anthropic
providers:
  anthropic:
    api_key: ${ANTHROPIC_API_KEY}     # prefer an env var over a literal key
  openai:
    api_key: ${OPENAI_API_KEY}        # optional
  openrouter:
    api_key: ${OPENROUTER_API_KEY}    # optional, for multi-model routing

memory:
  backend: sqlite
  path: ~/.hermes/memory.db
```

```bash
# Keep the config readable only by you
chmod 600 ~/.hermes/config.yaml
```

> **Secrets hygiene:** export keys from your shell profile or a root-only env file and reference them — don't paste live keys into files you might commit. Never put `~/.hermes/` in a git repo.

### Test Hermes

```bash
hermes run --prompt "Hello. Tell me your name and what tools you have available."

ls -la ~/.hermes/          # expect config + memory.db + sessions/ + skills/
hermes sessions search "hello"
```

---

## 4. Paperclip Control Plane

*Paperclip is the open-source "AI company OS." Verified against `github.com/paperclipai/paperclip`, June 2026. Requires Node 20+ and pnpm 9.15+.*

Paperclip gives your agents a governance layer — visual org chart, per-agent cost caps, a wakeup queue with budget checks, and approval flows.

### Quickest path: the onboarder

Paperclip ships an onboarding command that **auto-provisions an embedded PostgreSQL database — no manual DB setup**. (This is the important correction if you've seen older SQLite-based instructions: Paperclip uses PostgreSQL, and it sets it up for you.)

```bash
# Trusted-local bind (default — good for a single-operator box behind Caddy)
npx paperclipai onboard --yes

# Or expose on your LAN / tailnet instead:
# npx paperclipai onboard --yes --bind lan
# npx paperclipai onboard --yes --bind tailnet
```

### Manual install (if you want the repo checked out)

```bash
git clone https://github.com/paperclipai/paperclip.git ~/paperclip
cd ~/paperclip
pnpm install

# Copy the example env and fill it in — do NOT hardcode keys elsewhere
cp .env.example .env
#   set ANTHROPIC_API_KEY=... and any auth secret the example asks for
#   leave the database config as the example provides (embedded Postgres)

pnpm db:migrate
pnpm dev          # API on :3100, UI served alongside — Ctrl+C when verified
```

> Check the repo's current `.env.example` for the exact variable names — they're the source of truth and change between releases.

### Run it under PM2 (secrets stay in `.env`, not in the PM2 file)

Keep the ecosystem file free of secrets — Paperclip reads its own `.env` from its working directory.

```bash
cat > ~/paperclip/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'paperclip',
    cwd: '/root/paperclip',
    script: 'pnpm',
    args: 'start',
    env: { NODE_ENV: 'production', PORT: '3100' },
    restart_delay: 5000,
    max_restarts: 10
  }]
};
EOF

# Lock down the secret file
chmod 600 ~/paperclip/.env

pm2 start ~/paperclip/ecosystem.config.js
pm2 save
pm2 status        # expect: paperclip | online
```

### Access the UI

Open `https://paperclip.yourdomain.com` (via Caddy) — or tunnel to `localhost:3100` over SSH if you haven't set up a domain yet. Create your admin account on first login.

---

## 5. Telegram Gateway — Your Phone Interface

This is how you DM your agents from your phone. The Hermes gateway is a long-running process that listens for Telegram messages and routes them to your agents.

### Create a Telegram bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot`
3. Choose a name (e.g. "My AI OS") and username (e.g. `mysovereignstack_bot`)
4. Save the **bot token** BotFather gives you
5. Message `@userinfobot` to get **your numeric Telegram user ID** (you'll allow-list it)

### Configure + start the gateway

Add the Telegram channel to your Hermes config (confirm exact keys in the current docs), set `bot_token` and an `allowed_users` list with your ID, then run the gateway under PM2:

```bash
cat > ~/hermes-gateway.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'hermes-gateway',
    script: 'hermes',
    args: 'gateway start',
    restart_delay: 3000,
    max_restarts: 20
  }]
};
EOF

pm2 start ~/hermes-gateway.config.js
pm2 save
pm2 status        # expect: hermes-gateway | online
```

### Test from your phone

Open your bot in Telegram and send: `Hello — who are you and what can you do?` You should get a reply in about a second. No response? Check `pm2 logs hermes-gateway`.

> **Lock it down:** the `allowed_users` list is your authentication. Without it, anyone who finds the bot can talk to your agents (and spend your API budget). Set it before you do anything real.

---

## 6. Day 1 Org Chart — 3 Agents

Set these three up in Paperclip first. Don't over-engineer. Start with three that work.

> **Model IDs drift.** The IDs below were current in June 2026 (Claude Opus 4.8 / Sonnet 4.6). Confirm the current model IDs in the Anthropic docs at setup time — a stale ID is the #1 cause of a "model not found" error on first run.

### Agent 1: CEO (Orchestration + Memory)

In Paperclip UI → New Agent:
- **Name**: CEO
- **Adapter**: hermes_local
- **Model**: `claude-opus-4-8` (or `claude-sonnet-4-6` to save cost)
- **System prompt**:

```
You are the CEO of a one-person AI company. Your operator is {{OPERATOR_NAME}}.

Your job: orchestrate, decide, and remember. When {{OPERATOR_NAME}} messages you
(via Telegram or Paperclip), you either handle the task directly or delegate to a
specialist agent with clear instructions.

You have persistent memory across every session. Reference it. Update it. Be the
continuity layer across all work.

When delegating: post a task in Paperclip for the relevant agent with clear
instructions, context, and the expected output format.

Always say what you're doing and why. Be direct and brief.
```

- **Heartbeat**: every 6 hours (check inbox, review priorities)
- **Monthly budget cap**: $50

### Agent 2: Research

- **Name**: Research
- **Adapter**: hermes_local
- **Model**: `claude-sonnet-4-6`
- **System prompt**:

```
You are a senior research analyst. You receive tasks from the CEO agent or directly
from {{OPERATOR_NAME}} via Paperclip.

Your tools: web search/scraping and document analysis.

For every research task:
1. State what you're researching and why
2. List your sources before summarizing
3. Flag anything that couldn't be verified
4. Deliver findings in a structured format the CEO can act on

Never fabricate data. If you can't find it, say so.
```

- **Heartbeat**: on assignment only
- **Monthly budget cap**: $30

### Agent 3: Builder

- **Name**: Builder
- **Adapter**: claude_local (Claude Code, not Hermes)
- **Model**: `claude-sonnet-4-6`
- **System prompt**:

```
You are a senior software engineer. You receive coding tasks from the CEO agent via
Paperclip.

For every task:
1. Read the ticket carefully — the context you need is there
2. Plan before coding (write the approach first)
3. Write clean, tested code
4. Report back: what you built, how to use it, any open questions

Follow TDD where it fits. No magic numbers. Handle errors explicitly.
```

- **Heartbeat**: on assignment only
- **Monthly budget cap**: $40

---

## 7. Event-Driven Wakeups via n8n

This is what makes the stack proactive rather than reactive. Business signals wake your agents automatically.

### The Wakeup API

Paperclip exposes a wakeup endpoint for external triggers. Confirm the exact route in your Paperclip build (UI → Agent Settings shows the agent IDs), then POST to it from n8n:

```
POST http://localhost:3100/api/agents/{agentId}/wakeup
Body: { "source": "automation", "triggerDetail": "manual", "context": "..." }
```

### Install n8n — Docker recommended

n8n recommends Docker over a global npm install (global installs break on Node upgrades). The old `N8N_BASIC_AUTH_*` variables are **deprecated** — current n8n uses an owner account created on first launch.

```bash
docker volume create n8n_data
docker run -d --restart unless-stopped --name n8n \
  -p 127.0.0.1:5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_HOST=n8n.yourdomain.com \
  -e WEBHOOK_URL=https://n8n.yourdomain.com/ \
  docker.n8n.io/n8nio/n8n
```

> Bind to `127.0.0.1` and reverse-proxy with Caddy (add an `n8n.yourdomain.com` block), then create the owner account on first visit. Don't expose 5678 publicly.

### Example wakeup workflows

**Risk spike → CEO wakeup**
```
Trigger: webhook (POST when a monitored risk level changes)
Action:  HTTP POST to .../api/agents/CEO_AGENT_ID/wakeup
Body:    { "source": "automation", "triggerDetail": "risk", "context": "Risk level changed to HIGH" }
```

**Scheduled scan → Research wakeup**
```
Trigger: schedule (every 6h) OR a webhook from your data source
Action:  if new items found → POST to the Research agent's wakeup endpoint with the payload
```

**Competitor content → CEO wakeup**
```
Trigger: RSS feed from competitor blogs / feeds
Action:  on new post → wakeup CEO with a content summary
```

---

## 8. Voice Layer (Mac, Optional)

Hands-free dictation on your Mac. This is optional and runs on your laptop, not the VPS.

### The sovereign default: macOS built-in dictation

If keeping everything local matters to you (it's the whole point of this stack), use macOS's built-in dictation — on Apple Silicon it runs **on-device**, it's free, and nothing leaves your machine:

- **System Settings → Keyboard → Dictation → On**
- Pick a shortcut (e.g. double-press Control), then dictate into any text field — including Telegram Desktop, which reaches your Hermes agents.

### Optional: Vibing (richer, but cloud-based — know the trade-off)

[Vibing](https://github.com/VibingJustSpeakIt/Vibing) is a macOS dictation app *powered by Microsoft VibeVoice* that adds context-aware rewriting and translation. Follow the Mac setup guide in its repo to install (download from its Releases; grant accessibility, screen-recording, and microphone permissions).

> ⚠️ **Privacy trade-off, stated plainly.** Per Vibing's own FAQ, it **sends your audio and contextual information — including screenshots, text in the active field, and the current app name — to its servers** for processing (it says this isn't retained afterward). That's convenient, but it's cloud processing of your screen contents, which cuts against this stack's "your data never leaves your server" principle. If sovereignty is why you're here, prefer the built-in macOS dictation above. Use Vibing only if you've decided the richer rewriting is worth sending that context off-box.

> Microsoft VibeVoice also has text-to-speech models if you want *spoken* responses from your agents — that's an advanced extra; see the VibeVoice project (`github.com/microsoft/VibeVoice`) and confirm the current packages before wiring it up.

---

## 9. Architecture Diagram + Cost Model

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR PHONE (Telegram)                     │
│          DM → Hermes Gateway → CEO Agent → response          │
└─────────────────────┬───────────────────────────────────────┘
                      │ Telegram API (~1s)
┌─────────────────────▼───────────────────────────────────────┐
│                  HETZNER CX22 VPS (~$5/mo)                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PM2 / Docker                                        │   │
│  │  ├── paperclip (localhost:3100) — control plane      │   │
│  │  ├── hermes-gateway — Telegram listener              │   │
│  │  └── n8n (localhost:5678) — event triggers           │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ CEO Agent   │  │ Research    │  │ Builder Agent       │ │
│  │ (Hermes)    │  │ Agent       │  │ (Claude Code via    │ │
│  │ SQLite mem  │  │ (Hermes)    │  │  Paperclip)         │ │
│  │ 60+ tools   │  │ web intel   │  │ Task-ticket driven  │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
│  Caddy (the ONLY public surface) → https://paperclip.…      │
└─────────────────────────────────────────────────────────────┘
         │ n8n webhooks                │ API calls (your keys)
┌────────▼──────────┐      ┌──────────▼──────────────────────┐
│ Business Signals  │      │ AI Providers (bring your own key)│
│ · Filings/permits │      │ · Anthropic (Claude) — primary   │
│ · Risk monitors   │      │ · OpenAI / OpenRouter (optional) │
│ · RSS/competitor  │      │ · any OpenAI-compatible endpoint │
└───────────────────┘      └──────────────────────────────────┘
```

### Monthly Cost (honest, itemized)

| Item | Cost |
|------|------|
| Hetzner CX22 VPS | $5.00 |
| Domain (amortized) | $0.83 |
| Claude API — CEO (moderate use) | $25.00 |
| Claude API — Research (moderate) | $15.00 |
| Claude API — Builder (on-demand) | $15.00 |
| Web search/scraping (optional) | ~$8.00 |
| **Total** | **~$69/month** |

The VPS is ~$5; the rest is **your own API usage, which you cap per agent in Paperclip**. Light users land well under this; heavy users more. There's no platform fee — you pay providers directly.

---

## 10. Troubleshooting

The most common things that break, and where to look first.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Telegram bot doesn't reply | gateway down, or your user ID isn't allow-listed | `pm2 logs hermes-gateway`; verify `allowed_users` contains your numeric ID |
| "model not found" / invalid model on first agent run | stale model ID in the agent config | confirm the current Claude model ID in the Anthropic docs and update the agent |
| Paperclip won't start / DB errors | tried to point it at SQLite, or migrations didn't run | use `npx paperclipai onboard --yes` (it provisions embedded PostgreSQL); check `pnpm db:migrate` ran; read its current `.env.example` |
| Can't reach the UI | port not exposed (correct) | tunnel: `ssh -L 3100:localhost:3100 root@SERVER`, or finish the Caddy + domain step |
| Process died after reboot | PM2 startup not saved | `pm2 save` and confirm the `pm2 startup` line ran |
| Box is sluggish / OOM | n8n + Paperclip + Postgres on 4 GB | move n8n to its own instance or upgrade to CX32 (8 GB) |
| Agent burned through budget | no/loose cost cap | set per-agent monthly caps in Paperclip; lower the heartbeat frequency |

---

## 11. Backups & Recovery

Your agents' entire memory lives in a few files. Back them up, or one lost droplet wipes everything they've ever learned.

- **Enable VPS snapshots** in the Hetzner console (cheap, automatic point-in-time recovery).
- **Back up the SQLite memory + configs** on a schedule:

```bash
# Nightly backup of Hermes memory + key configs to a tarball
cat > /root/backup-stack.sh << 'EOF'
#!/bin/bash
set -e
STAMP=$(date +%F)
mkdir -p /root/backups
tar czf "/root/backups/sovereign-$STAMP.tgz" \
  ~/.hermes/memory.db ~/.hermes/config.yaml \
  ~/paperclip/.env 2>/dev/null || true
# keep the last 14 days
ls -1t /root/backups/sovereign-*.tgz | tail -n +15 | xargs -r rm
EOF
chmod +x /root/backup-stack.sh

# Run it nightly at 03:30
( crontab -l 2>/dev/null; echo "30 3 * * * /root/backup-stack.sh" ) | crontab -
```

- For real durability, copy the tarballs off-box (e.g. `rclone` to object storage or `scp` to another machine).

---

## 12. Keeping It Current

This stack is built on fast-moving open-source tools — repos restructure, model IDs change, install scripts get updated. To avoid silent rot:

- **Pin what you can.** Note the versions you installed (`hermes --version`, the Paperclip commit, your Node version) so you can reproduce a working state.
- **Verify before upgrading.** Read each project's release notes before pulling `main` — agent tooling ships breaking changes.
- **Watch the source repos** (Hermes, Paperclip, n8n) for releases.
- **This guide is versioned on GitHub.** Watch/star the repo for updates, and if you hit a step that's drifted, [open an issue or PR](https://github.com/ChrisJDiMarco/sovereign-stack/issues) — fixes land for everyone.

---

## 13. What to Build Next

Once your three-agent stack is running smoothly:

**Week 2:**
- Add a Scheduler agent (calendar + meeting prep)
- Add a Finance agent (revenue, expenses, invoices)
- Wire a morning briefing as a scheduled wakeup

**Week 3–4:**
- Multi-company isolation in Paperclip (separate companies per project)
- Version-control your agent definitions in git
- Add a second gateway channel (Slack, Discord) alongside Telegram

**Month 2:**
- Custom skills for your specific domains
- Per-agent spend dashboards via n8n
- Weekly review automation (Friday → summary → your phone)

---

*The Sovereign Stack Blueprint — free & open source (MIT) — last updated June 2026*
*Questions or fixes: [open an issue on GitHub](https://github.com/ChrisJDiMarco/sovereign-stack/issues)*
