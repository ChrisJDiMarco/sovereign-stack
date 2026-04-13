# Sovereign Stack — Autonomous Launch Agent

You are the Sovereign Stack launch agent. Your job is to take this repo from zero to live product — sales page deployed on GitHub Pages, Gumroad listing created, PDF product generated, and Twitter launch thread ready. Execute every phase autonomously. Only pause for the two items marked **NEEDS CHRIS** (Gumroad credentials and domain purchase). Everything else runs without human input.

---

## Operator Context

- **Product**: The Sovereign Stack — $97 digital guide to building an autonomous AI agent OS (Hermes + Paperclip + VPS)
- **Operator GitHub**: ChrisJDiMarco
- **Repo name**: sovereign-stack
- **Sales page URL (after deploy)**: https://chrisdimarco.github.io/sovereign-stack
- **Gumroad slug**: sovereign-stack
- **Price**: $97 USD, one-time
- **Target buyer**: Semi-technical founders/operators who know about AI agents and want to build their own vs. paying $200/month for Perplexity Computer

---

## Repo Structure (already in place)

```
sovereign-stack/
├── CLAUDE.md               ← YOU ARE HERE — autonomous agent instructions
├── index.html              ← Sales page (live on GitHub Pages)
├── product/
│   └── blueprint.md        ← The actual digital product content
├── assets/
│   └── og-image.png        ← Social share image (generate this)
└── README.md               ← Public-facing repo description
```

---

## Phase 1 — GitHub Pages Deploy

**Goal**: Sales page live at `https://chrisdimarco.github.io/sovereign-stack`

```bash
# Verify gh CLI is authenticated
gh auth status

# If not authenticated:
# gh auth login --web

# Create repo (skip if already exists)
gh repo create ChrisJDiMarco/sovereign-stack \
  --public \
  --description "The Sovereign Stack — Build Your Autonomous AI Agent OS" \
  --homepage "https://chrisdimarco.github.io/sovereign-stack"

# Enable GitHub Pages on main branch root
gh api repos/ChrisJDiMarco/sovereign-stack/pages \
  --method POST \
  -f source[branch]=main \
  -f source[path]=/

# Push all files
cd /path/to/sovereign-stack
git init
git add .
git commit -m "Launch: Sovereign Stack sales page + product blueprint"
git branch -M main
git remote add origin https://github.com/ChrisJDiMarco/sovereign-stack.git
git push -u origin main
```

**Verify**: After push, GitHub Pages activates within 2-3 minutes. Check `https://chrisdimarco.github.io/sovereign-stack` loads the sales page.

**If Pages fails to activate automatically**:
```bash
gh api repos/ChrisJDiMarco/sovereign-stack/pages \
  --method PUT \
  -f source[branch]=main \
  -f source[path]=/
```

---

## Phase 2 — Generate OG Social Image

**Goal**: Create `assets/og-image.png` (1200×630px) for Twitter/link previews.

Generate using the FAL.ai account Chris has active. Use the Flux model via Chrome MCP:

**Prompt for image generation**:
> "Dark tech product landing page hero image, 1200x630 pixels, ultra-dark near-black background (#060609), glowing terminal interface in the center showing green text on black, purple and cyan gradient accent glow, text overlay reads 'SOVEREIGN STACK' in bold white Satoshi font, subtitle 'Build Your Autonomous AI Agent OS', premium SaaS aesthetic, no humans, clean geometric"

Save output to `assets/og-image.png`.

Then add the OG meta tags to `index.html` `<head>`:
```html
<meta property="og:title" content="The Sovereign Stack — Build Your Autonomous AI Agent OS">
<meta property="og:description" content="The complete playbook for a persistent AI agent stack that runs 24/7 on $5/month. Hermes + Paperclip + VPS. Beats Perplexity Computer at 1/3 the price.">
<meta property="og:image" content="https://chrisdimarco.github.io/sovereign-stack/assets/og-image.png">
<meta property="og:url" content="https://chrisdimarco.github.io/sovereign-stack">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="The Sovereign Stack — Build Your Autonomous AI Agent OS">
<meta name="twitter:description" content="The complete playbook for a persistent AI agent stack that runs 24/7 on $5/month. Hermes + Paperclip + VPS. $97 one-time.">
<meta name="twitter:image" content="https://chrisdimarco.github.io/sovereign-stack/assets/og-image.png">
```

Commit and push after adding.

---

## Phase 3 — Polish the Blueprint PDF

**Goal**: `product/blueprint.md` → final PDF that gets delivered via Gumroad.

The blueprint.md file contains the full content outline. Convert to PDF using the PDF skill:

```bash
# Convert the markdown to a polished PDF
# Use the pdf skill with the following parameters:
# - Input: product/blueprint.md
# - Output: product/sovereign-stack-blueprint.pdf
# - Style: Dark premium technical document
# - Include: cover page, table of contents, all 8 sections
```

**Cover page**:
- Title: "The Sovereign Stack Blueprint"
- Subtitle: "Build Your Autonomous AI Agent OS — Complete Implementation Guide"
- Version: 1.0 — April 2026
- Background: Dark gradient matching the sales page

**Verify PDF**: Open the PDF, confirm all 8 sections are present, code blocks are readable, architecture diagram is included.

---

## Phase 4 — Gumroad Product Setup

⚠️ **NEEDS CHRIS**: Gumroad login credentials required for this phase. Chris must do this step or hand over session cookies.

**Steps Chris does (5 minutes)**:
1. Go to gumroad.com → New Product
2. Name: "The Sovereign Stack Blueprint"
3. Type: Digital Product
4. Price: $97 (no subscription, one-time)
5. Upload: `product/sovereign-stack-blueprint.pdf`
6. URL slug: `sovereign-stack`
7. Description: Copy from `gumroad-description.md` (generated below)
8. Cover image: Use `assets/og-image.png`
9. Publish

**After publish**, update every `href="https://gumroad.com/l/sovereign-stack"` in `index.html` with the real Gumroad URL. Then commit and push.

---

## Phase 5 — Update Buy Links in Sales Page

Once Gumroad URL is live, run this find-and-replace:

```bash
# Replace placeholder Gumroad links with real URL
sed -i 's|https://gumroad.com/l/sovereign-stack|REAL_GUMROAD_URL|g' index.html
git add index.html
git commit -m "Update buy links with live Gumroad URL"
git push
```

---

## Phase 6 — Twitter/X Launch Thread

**Goal**: A ready-to-post Twitter thread that drops on launch day.

Write and save to `launch-thread.md`:

---

**Tweet 1 (hook)**:
> Perplexity Computer: $200/month
> 
> My autonomous AI agent OS: $5/month infra + $97 one-time guide
> 
> Same power. You own it. Your data never leaves your server.
> 
> Here's exactly how I built it 🧵

**Tweet 2 (the problem)**:
> Most "AI agent" setups forget everything when the session ends.
> 
> You're back to zero every time.
> 
> The fix: Hermes — persistent SQLite memory, FTS5 search across every session, 160+ skills.
> 
> This is what Perplexity charges $200/month to abstract away.

**Tweet 3 (the stack)**:
> The Sovereign Stack runs 3 agents 24/7 on a $5/month VPS:
> 
> → CEO: orchestrates, remembers, decides
> → Research: Firecrawl + web intel on demand  
> → Builder: Claude Code + task queue
> 
> All controlled via Paperclip — visual org chart, cost controls, approval flows.

**Tweet 4 (the phone angle)**:
> Best part: DM your AI OS on Telegram from your phone.
> 
> Sub-1 second latency. No laptop. No dashboard.
> 
> Your CEO agent responds like a person. Because it has memory of every conversation you've had.

**Tweet 5 (the reveal)**:
> I documented the entire setup. Every command. Every config. Every gotcha.
> 
> 40+ hours of research → one weekend of setup → autonomous agents running forever.
> 
> $97. One-time. No subscription.
> 
> [LINK]

**Tweet 6 (comparison)**:
> vs Perplexity Computer ($200/mo):
> 
> ✓ Persistent memory (they can't do this)
> ✓ Your data stays on your server
> ✓ Telegram phone interface
> ✓ Cost transparency per task
> ✓ VibeVoice voice layer
> ✓ You own it forever
> 
> Save $1,572/year. Own your stack.

---

Save to `launch-thread.md`. Do NOT post — Chris approves before posting.

---

## Phase 7 — README.md for the Repo

Write a clean public README. This is what developers see on GitHub:

```markdown
# The Sovereign Stack

> Build your autonomous AI agent OS — persistent memory, Telegram phone interface, Paperclip governance — on a $5/month VPS.

**[Get the Blueprint →](https://gumroad.com/l/sovereign-stack)**

## What's in the repo

- `index.html` — Sales page (live at https://chrisdimarco.github.io/sovereign-stack)
- `product/` — Product content (PDF delivered via Gumroad)

## The Stack

- **Hermes** — NousResearch's persistent memory agent (SQLite, FTS5, 160+ skills)
- **Paperclip** — Open-source AI company OS (governance, cost controls, org chart)
- **Hetzner CX22** — $5/month VPS (Ubuntu 24.04, PM2, Caddy)
- **Hermes Gateway** — Telegram interface (DM your agents from your phone)
- **VibeVoice** — Voice layer (speak to your agents on desktop)

## Questions

Open an issue or email hey@sovereignstack.io
```

---

## Phase 8 — Final Verification Checklist

Run through this before calling launch complete:

- [ ] `https://chrisdimarco.github.io/sovereign-stack` loads the sales page
- [ ] All buy buttons point to live Gumroad URL (not placeholder)
- [ ] OG image loads correctly when URL is shared on Twitter
- [ ] FAQ accordion works (click each question)
- [ ] Animated counters fire on scroll
- [ ] Comparison table renders on mobile (375px)
- [ ] Gumroad product delivers PDF on purchase
- [ ] PDF has cover page, TOC, all 8 sections, code blocks readable
- [ ] `launch-thread.md` is ready for Chris to review and post
- [ ] Repo is public at `github.com/ChrisJDiMarco/sovereign-stack`

---

## Execution Order

```
Phase 1 → GitHub Pages deploy        (autonomous, 10 min)
Phase 2 → OG social image            (autonomous, 10 min, needs FAL.ai)
Phase 3 → Polish blueprint PDF       (autonomous, 20 min)
Phase 4 → Gumroad setup              (NEEDS CHRIS, 5 min)
Phase 5 → Update buy links           (autonomous, 2 min, after Phase 4)
Phase 6 → Launch thread              (autonomous, 10 min)
Phase 7 → README                     (autonomous, 5 min)
Phase 8 → Verification               (autonomous, 10 min)
```

Total autonomous time: ~67 minutes
Time requiring Chris: ~5 minutes (Gumroad only)

---

## BLOCKED States

If any phase is blocked, respond with:
`BLOCKED: needs Chris — [specific thing needed]`

Then continue to the next phase that can run independently.

---

*Generated by JARVIS · April 2026 · Sovereign Stack v1.0*
