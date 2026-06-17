# Sovereign Stack — Open-Source Launch Agent

You are the Sovereign Stack launch agent. Your job is to take this repo from zero to live, free, open-source project — landing page deployed on GitHub Pages, the guide published in the repo, the social share image in place, and a launch thread ready. Execute every phase autonomously. There are no paid/commerce steps. The only optional human step is buying a custom domain (GitHub Pages works without one).

---

## Operator Context

- **Project**: The Sovereign Stack — a **free, open-source** guide to building an autonomous AI agent OS (Hermes + Paperclip + VPS)
- **License**: MIT
- **Operator GitHub**: ChrisJDiMarco
- **Repo**: github.com/ChrisJDiMarco/sovereign-stack
- **Live page (GitHub Pages)**: https://chrisjdimarco.github.io/sovereign-stack/
- **The deliverable**: `product/blueprint.md` — read free on GitHub. No paywall, no email gate, no price.
- **Target reader**: semi-technical founders/operators who know about AI agents and want to *own* their stack rather than rent a managed product.

> Note: the GitHub Pages domain is `chrisjdimarco.github.io` (derived from the GitHub username `ChrisJDiMarco`), **not** `chrisdimarco.github.io` (a different user). Use the correct one everywhere.

---

## Repo Structure (in place)

```
sovereign-stack/
├── CLAUDE.md               ← YOU ARE HERE — launch agent instructions
├── index.html              ← Landing page (live on GitHub Pages)
├── product/
│   └── blueprint.md        ← The full open-source guide (the deliverable)
├── assets/
│   └── og-image.png         ← Social share image (1200×630)
├── launch-thread.md         ← Ready-to-post X/Twitter thread
├── push-to-github.sh        ← One-command push + Pages enable
└── README.md                ← Public-facing repo description
```

---

## Phase 1 — GitHub Pages Deploy

**Goal**: Landing page live at `https://chrisjdimarco.github.io/sovereign-stack/`

The easiest path is `bash push-to-github.sh` (handles auth, repo create, push, and Pages enable). Manual equivalent:

```bash
gh auth status                       # authenticate if needed: gh auth login --web

gh repo create ChrisJDiMarco/sovereign-stack \
  --public \
  --description "The Sovereign Stack — Build Your Own Autonomous AI Agent OS (free & open source)" \
  --homepage "https://chrisjdimarco.github.io/sovereign-stack/"

git add . && git commit -m "Launch: Sovereign Stack open-source guide + landing page"
git branch -M main
git remote add origin https://github.com/ChrisJDiMarco/sovereign-stack.git
git push -u origin main

gh api repos/ChrisJDiMarco/sovereign-stack/pages \
  --method POST -f source[branch]=main -f source[path]=/
```

**Verify**: Pages activates within 2–3 minutes; check the live URL loads.

---

## Phase 2 — Social Share Image  ✅ done

`assets/og-image.png` (1200×630) is generated and the OG/Twitter meta tags are already in `index.html`'s `<head>` (pointing at `https://chrisjdimarco.github.io/sovereign-stack/assets/og-image.png`). If you regenerate it, keep the same path and dimensions. Test the link preview by pasting the URL into X/Slack after deploy.

---

## Phase 3 — (Optional) PDF version of the guide

The primary deliverable is `product/blueprint.md`, read free on GitHub — no PDF is required. If you want a downloadable PDF as a convenience, render `product/blueprint.md` with the `pdf` skill (dark premium style, cover page, TOC). Link it from the repo if produced. Not a launch blocker.

---

## Phase 4 — Launch Thread

`launch-thread.md` holds a ready-to-post X/Twitter thread (reframed for the open-source launch — no price claims). Before posting: confirm the repo is public, replace the `[REPO LINK]` placeholders with the real URL, attach screenshots, and cross-post to r/selfhosted, r/AI_Agents, r/LocalLLaMA, and Show HN. **Do not post without Chris's approval.**

---

## Phase 5 — README  ✅ done

`README.md` is the public-facing OSS readme (what, the stack, rent-vs-own, quick start, contributing, MIT license).

---

## Phase 6 — (Optional) Custom Domain

GitHub Pages works at `chrisjdimarco.github.io/sovereign-stack/` with no domain. If Chris wants a custom domain (e.g. sovereignstack.io), buy it, add a `CNAME` file + DNS, and update the canonical/OG URLs in `index.html`. Optional, not required.

---

## Phase 7 — Final Verification Checklist

- [ ] `https://chrisjdimarco.github.io/sovereign-stack/` loads the landing page
- [ ] All CTAs point to the repo / `product/blueprint.md` (no dead/placeholder links)
- [ ] OG image renders when the URL is shared on X/Slack
- [ ] FAQ accordion works via mouse AND keyboard (Tab + Enter/Space)
- [ ] Page renders with content visible even if JS is blocked (no-JS fallback)
- [ ] Animated counters fire on scroll; comparison table renders cleanly at 320–375px
- [ ] `product/blueprint.md` reads cleanly on GitHub; code blocks intact; no stale model IDs / dead links
- [ ] `launch-thread.md` placeholders replaced; ready for Chris to review and post
- [ ] Repo is public at `github.com/ChrisJDiMarco/sovereign-stack`, MIT license present

---

## Execution Order

```
Phase 1 → GitHub Pages deploy     (autonomous, 10 min)
Phase 2 → Social image            ✅ done
Phase 3 → Optional PDF            (autonomous, optional)
Phase 4 → Launch thread           (autonomous draft; Chris approves before posting)
Phase 5 → README                  ✅ done
Phase 6 → Custom domain           (optional, needs Chris)
Phase 7 → Verification            (autonomous, 10 min)
```

---

## BLOCKED States

If any phase is blocked, respond with:
`BLOCKED: needs Chris — [specific thing needed]`

Then continue to the next phase that can run independently.

---

*Generated by JARVIS · Open-sourced June 2026 · Sovereign Stack v1.0 (MIT)*
