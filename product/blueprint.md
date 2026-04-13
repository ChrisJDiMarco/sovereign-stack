# The Sovereign Stack Blueprint
### Build Your Autonomous AI Agent OS — Complete Implementation Guide
**Version 1.0 — April 2026**

---

## Table of Contents

1. What You're Building (and Why It Beats $200/Month)
2. VPS Selection + Bare Metal Setup
3. Hermes Agent — Install + Configuration
4. Paperclip Control Plane — Install + First Run
5. Telegram Gateway — Your Phone Interface
6. Day 1 Org Chart: 3 Agents That Work
7. Event-Driven Wakeups via n8n
8. VibeVoice Voice Layer (Mac)
9. Full Architecture Diagram + Cost Model
10. What to Build Next

---

## 1. What You're Building

By the end of this guide you will have:

- **3 AI agents running 24/7** on a $5/month VPS, with persistent memory across every session
- **Telegram DM access from your phone** — message your CEO agent like a person, get real work done
- **Paperclip control plane** — visual org chart, per-agent cost controls, governance approvals
- **Event-driven wakeups** — business signals (permit filings, competitor content, risk spikes) wake your agents automatically via n8n webhooks
- **Voice interface on Mac** — speak to your agents hands-free via VibeVoice + Vibing app

**Why this beats Perplexity Computer ($200/month)**:
Perplexity Computer runs in their cloud (your data, their servers), has no persistent memory between sessions, and has no phone interface. The Sovereign Stack is yours. Your VPS, your data, your memory, your agents. Forever.

**Total monthly cost**: ~$69/month all-in (VPS + API tokens at normal usage)
**Setup time**: One focused weekend

---

## 2. VPS Selection + Bare Metal Setup

### Recommended: Hetzner CX22

- **Provider**: hetzner.com
- **Plan**: CX22 — 2 vCPU, 4GB RAM, 40GB SSD
- **Cost**: ~$5/month (billed hourly)
- **OS**: Ubuntu 24.04 LTS
- **Region**: Closest to you (EU Central for US East, US East for US West)

> Why Hetzner over DigitalOcean/AWS? Price. $5/month for equivalent spec vs. $12-24/month. No feature difference for this stack.

### Initial Server Setup

```bash
# SSH into your new server
ssh root@YOUR_SERVER_IP

# Update packages
apt update && apt upgrade -y

# Install essentials
apt install -y curl git wget unzip build-essential

# Install NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
nvm alias default 22

# Verify Node
node --version  # Should show v22.x.x

# Install pnpm
npm install -g pnpm

# Install Python 3.11+
apt install -y python3 python3-pip python3-venv

# Install PM2 (process manager)
npm install -g pm2

# Set PM2 to auto-start on reboot
pm2 startup systemd -u root --hp /root
# Run the command it outputs, then:
pm2 save
```

### Firewall Setup

```bash
# Allow SSH, HTTP, HTTPS, and Paperclip ports
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3100/tcp   # Paperclip API
ufw allow 5173/tcp   # Paperclip UI (local only — restrict after setup)
ufw enable
ufw status
```

### Caddy (Reverse Proxy + Auto-HTTPS)

```bash
# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy

# Create Caddyfile (replace paperclip.yourdomain.com with your domain)
cat > /etc/caddy/Caddyfile << 'EOF'
paperclip.yourdomain.com {
    reverse_proxy localhost:3100
}
EOF

# Restart Caddy
systemctl restart caddy
systemctl status caddy  # Should show "active (running)"
```

> **Note on domain**: You need a domain pointed to your VPS IP. Cheapest option: Namecheap, ~$10/year. Update your domain's A record to point to your server IP. Caddy handles SSL automatically.

---

## 3. Hermes Agent — Install + Configuration

Hermes is NousResearch's persistent memory agent. It's the core intelligence layer — the thing that actually remembers and acts.

### Install Hermes

```bash
# Install via official script
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
source ~/.bashrc

# Verify install
hermes --version
```

### Configure API Keys

```bash
# Create Hermes config directory
mkdir -p ~/.hermes

# Create config file
cat > ~/.hermes/config.yaml << 'EOF'
default_provider: anthropic
providers:
  anthropic:
    api_key: YOUR_ANTHROPIC_API_KEY
  openai:
    api_key: YOUR_OPENAI_API_KEY   # optional backup
  openrouter:
    api_key: YOUR_OPENROUTER_KEY   # optional multi-model routing

memory:
  backend: sqlite
  path: ~/.hermes/memory.db

skills_dir: ~/.hermes/skills/
sessions_dir: ~/.hermes/sessions/
EOF

# Set permissions
chmod 600 ~/.hermes/config.yaml
```

### Test Hermes

```bash
# Start a quick test session
hermes run --prompt "Hello. Tell me your name and what tools you have available."

# Check memory was created
ls -la ~/.hermes/
# Should show: config.yaml, memory.db, sessions/, skills/

# Search past sessions
hermes sessions search "test"
```

### JARVIS Skills Migration

If you have existing JARVIS skills (`.md` files), copy them to Hermes:

```bash
# Copy your JARVIS skill files to Hermes skills directory
cp ~/jarvis/skills/*.md ~/.hermes/skills/

# Hermes loads all .md files in skills/ automatically on next run
# Verify
hermes skills list
```

---

## 4. Paperclip Control Plane

Paperclip is the open-source AI company OS. It gives your agents a governance layer — visual org chart, per-agent cost caps, heartbeat scheduling, approval flows.

### Clone + Install Paperclip

```bash
# Clone Paperclip (use the official repo)
git clone https://github.com/paperclipai/paperclip ~/paperclip
cd ~/paperclip

# Install dependencies
pnpm install

# Create environment file
cat > .env << 'EOF'
DATABASE_URL=file:./dev.db
BETTER_AUTH_SECRET=GENERATE_A_RANDOM_32_CHAR_STRING_HERE
ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY
SERVE_UI=true
PAPERCLIP_DEPLOYMENT_MODE=authenticated
EOF

# Generate a secret (run this and paste the output into BETTER_AUTH_SECRET above)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Run migrations
pnpm db:migrate

# Test run (verify it starts)
pnpm dev
# Should show: Server running on port 3100, UI on port 5173
# Press Ctrl+C to stop
```

### PM2 Configuration for Paperclip

```bash
# Create PM2 ecosystem file
cat > ~/paperclip/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'paperclip',
    cwd: '/root/paperclip',
    script: 'pnpm',
    args: 'start',
    env: {
      NODE_ENV: 'production',
      DATABASE_URL: 'file:./prod.db',
      BETTER_AUTH_SECRET: 'YOUR_SECRET_HERE',
      ANTHROPIC_API_KEY: 'YOUR_KEY_HERE',
      SERVE_UI: 'true',
      PAPERCLIP_DEPLOYMENT_MODE: 'authenticated',
      PORT: '3100'
    },
    restart_delay: 5000,
    max_restarts: 10
  }]
};
EOF

# Start Paperclip via PM2
pm2 start ~/paperclip/ecosystem.config.js
pm2 save

# Verify
pm2 status
# Should show: paperclip | online
```

### Access Paperclip UI

Open `https://paperclip.yourdomain.com` (or `http://YOUR_VPS_IP:3100` without Caddy).

Create your admin account on first login.

---

## 5. Telegram Gateway — Your Phone Interface

This is how you DM your agents from your phone. Hermes Gateway is a persistent server process (not an agent) that listens for Telegram messages and routes them to your Hermes agents.

### Create a Telegram Bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot`
3. Choose a name (e.g., "My AI OS") and username (e.g., `mysovereignstack_bot`)
4. BotFather gives you a **bot token** — save it

### Configure Hermes Gateway

```bash
# Add Telegram config to Hermes
cat >> ~/.hermes/config.yaml << 'EOF'

gateway:
  channels:
    telegram:
      enabled: true
      bot_token: YOUR_TELEGRAM_BOT_TOKEN
      allowed_users:
        - YOUR_TELEGRAM_USER_ID   # Get this from @userinfobot on Telegram
EOF
```

### Start Hermes Gateway via PM2

```bash
# Create PM2 entry for Hermes Gateway
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
pm2 status  # Should show: hermes-gateway | online
```

### Test From Your Phone

1. Open Telegram, find your bot (`@mysovereignstack_bot`)
2. Send: `Hello — who are you and what can you do?`
3. You should get a response within 1-2 seconds

If no response: check `pm2 logs hermes-gateway` for errors.

---

## 6. Day 1 Org Chart — 3 Agents

Set these three up in Paperclip first. Don't over-engineer. Start with three that work.

### Agent 1: CEO (Orchestration + Memory)

In Paperclip UI → New Agent:
- **Name**: CEO
- **Adapter**: hermes_local
- **Model**: claude-opus-4-6 (or claude-sonnet-4-6 to save cost)
- **System prompt**:

```
You are the CEO of a one-person AI company. Your operator is Chris.

Your job: orchestrate, decide, and remember. When Chris messages you (via Telegram or Paperclip), you either handle the task directly or delegate to a specialist agent with clear instructions.

You have persistent memory across every session. Reference it. Update it. Use it to be the continuity layer across all work.

When delegating: post a task in Paperclip for the relevant agent with clear instructions, context, and expected output format.

Always respond with what you're doing and why. Be direct and brief.
```

- **Heartbeat**: Every 6 hours (check inbox, review priorities)
- **Monthly budget cap**: $50

### Agent 2: Research

In Paperclip UI → New Agent:
- **Name**: Research
- **Adapter**: hermes_local
- **Model**: claude-sonnet-4-6
- **System prompt**:

```
You are a senior research analyst. You receive tasks from the CEO agent or directly from Chris via Paperclip.

Your tools: Firecrawl (web scraping + search), Hermes web search, document analysis.

For every research task:
1. State what you're researching and why
2. List your sources before summarizing
3. Flag anything that couldn't be verified
4. Deliver findings in a structured format the CEO can act on

Never hallucinate data. If you can't find it, say so.
```

- **Heartbeat**: On assignment only (no scheduled heartbeat — fires when CEO delegates)
- **Monthly budget cap**: $30

### Agent 3: Builder

In Paperclip UI → New Agent:
- **Name**: Builder
- **Adapter**: claude_local (Claude Code, not Hermes)
- **Model**: claude-sonnet-4-6
- **System prompt**:

```
You are a senior software engineer. You receive coding tasks from the CEO agent via Paperclip.

For every task:
1. Read the task ticket carefully — all context you need is there
2. Plan before coding (write the approach in a comment first)
3. Write clean, tested code
4. Report back with: what you built, how to use it, any open questions

Follow TDD where applicable. No magic numbers. Handle errors explicitly.
```

- **Heartbeat**: On assignment only
- **Monthly budget cap**: $40

---

## 7. Event-Driven Wakeups via n8n

This is what makes the stack proactive rather than reactive. Business signals automatically wake your agents.

### The Wakeup API

Paperclip exposes this endpoint for external triggers:

```
POST /api/agents/{agentId}/wakeup
Body: { "source": "automation", "triggerDetail": "manual" }
```

Find your agent IDs in Paperclip UI → Agent Settings → Agent ID.

### n8n Setup (on same VPS or separate)

```bash
# Install n8n
npm install -g n8n

# Create PM2 entry
cat >> ~/n8n.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'n8n',
    script: 'n8n',
    args: 'start',
    env: {
      N8N_PORT: 5678,
      N8N_BASIC_AUTH_ACTIVE: 'true',
      N8N_BASIC_AUTH_USER: 'admin',
      N8N_BASIC_AUTH_PASSWORD: 'CHOOSE_A_STRONG_PASSWORD'
    }
  }]
};
EOF

pm2 start ~/n8n.config.js
pm2 save
```

### Example Wakeup Workflows

**Workflow 1: Crucix Risk Spike → CEO Wakeup**
```
Trigger: Webhook from Crucix (POST when risk level changes)
Action: HTTP POST to http://localhost:3100/api/agents/CEO_AGENT_ID/wakeup
Body: { "source": "automation", "triggerDetail": "manual", "context": "Crucix risk level changed to HIGH" }
```

**Workflow 2: Permit Filing Alert → Research Wakeup**
```
Trigger: Schedule (every 6 hours) OR webhook from permit data source
Action 1: Fetch new permit filings for target zip codes
Action 2: If new filings found → HTTP POST to Research agent wakeup
Body: { "source": "automation", "triggerDetail": "permit_alert", "filings": [...] }
```

**Workflow 3: Competitor Content → CEO Wakeup**
```
Trigger: RSS feed from competitor blogs/Twitter
Action: When new post detected → wakeup CEO with content summary
```

---

## 8. VibeVoice Voice Layer (Mac Desktop)

Speak to your agents hands-free on Mac. Zero additional VPS infrastructure.

### Step 1: Install Vibing App

Vibing is a macOS app that wraps VibeVoice-ASR-7B and adds system-wide voice input.

```bash
# Option A: Download from GitHub releases
# https://github.com/fakerybakery/vibing/releases
# Download the .dmg, drag to Applications

# Option B: If Homebrew cask is available
brew install --cask vibing
```

### Step 2: Configure Vibing

- Open Vibing → Settings
- Model: VibeVoice-ASR-7B (downloads automatically, ~4GB, M-series runs locally)
- Hotkey: Choose your trigger shortcut (e.g., `Cmd+Shift+Space`)
- Language: Auto-detect

### Step 3: Use It

1. Press hotkey → speak your message
2. Vibing transcribes in real-time using your M-series chip
3. Text is injected wherever your cursor is — type into Telegram Desktop to reach your Hermes agents

**Phone**: Use iOS native dictation (tap the microphone on the Telegram keyboard). Good enough for casual messages. VibeVoice's 60-min long-form / speaker diarization capabilities are overkill for 1-on-1 agent chats.

### Optional: VibeVoice-Realtime TTS (Spoken Responses)

```bash
pip install vibevoice-realtime --break-system-packages

# Test TTS
echo "Hello from your AI agent OS" | vibevoice-realtime-tts

# To pipe Hermes responses to audio (advanced):
hermes run --prompt "Summarize today's priorities" | vibevoice-realtime-tts
```

---

## 9. Architecture Diagram + Cost Model

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR PHONE (Telegram)                     │
│          DM → Hermes Gateway → CEO Agent → response          │
└─────────────────────┬───────────────────────────────────────┘
                      │ Telegram API (<1s)
┌─────────────────────▼───────────────────────────────────────┐
│                  HETZNER CX22 VPS ($5/mo)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PM2 Process Manager                                 │   │
│  │  ├── paperclip (port 3100) — Control plane           │   │
│  │  ├── hermes-gateway — Telegram listener              │   │
│  │  └── n8n (port 5678) — Event triggers                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ CEO Agent   │  │ Research    │  │ Builder Agent       │ │
│  │ (Hermes)    │  │ Agent       │  │ (Claude Code via    │ │
│  │ SQLite mem  │  │ (Hermes)    │  │  Paperclip)         │ │
│  │ 160+ skills │  │ Firecrawl   │  │ Task-ticket driven  │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Paperclip UI (https://paperclip.yourdomain.com)     │   │
│  │  Visual org chart · Cost controls · Approvals        │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         │ n8n webhooks                │ API calls
┌────────▼──────────┐      ┌──────────▼──────────────────────┐
│ Business Signals  │      │ AI Providers (BYOK)              │
│ · Permit filings  │      │ · Anthropic (Claude)             │
│ · Crucix risk     │      │ · OpenAI (optional)              │
│ · RSS/competitor  │      │ · OpenRouter (fallback)          │
│ · Calendar events │      └──────────────────────────────────┘
└───────────────────┘
```

### Monthly Cost Breakdown

| Item | Cost |
|------|------|
| Hetzner CX22 VPS | $5.00 |
| Domain (amortized) | $0.83 |
| Claude API (CEO, moderate usage) | $25.00 |
| Claude API (Research, moderate) | $15.00 |
| Claude API (Builder, on-demand) | $15.00 |
| Firecrawl (100 scrapes/mo) | $8.00 |
| **Total** | **~$69/month** |

vs. Perplexity Computer: **$200/month**. You save $1,572/year.

---

## 10. What to Build Next

Once your three-agent stack is running smoothly:

**Week 2 additions:**
- Add a Scheduler agent (manages your calendar, preps meeting briefs)
- Add a Finance agent (tracks revenue, expenses, invoices)
- Set up Crucix intelligence briefing as a morning wakeup trigger

**Week 3-4:**
- Multi-company isolation in Paperclip (separate companies for each business)
- GitHub sync for agent definitions (version control your org chart)
- Slack integration via Hermes Gateway (alternative to Telegram)

**Month 2:**
- Custom skills for your specific domains (Permit Intel, Thinklet, NuHigh)
- Per-agent Stripe spend dashboards via n8n
- Weekly review automation (Friday 5pm Paperclip → weekly summary → iMessage)

---

*The Sovereign Stack Blueprint — v1.0 — April 2026*
*Questions: hey@sovereignstack.io*
