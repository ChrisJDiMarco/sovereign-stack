#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Sovereign Stack — One-Command GitHub Push
# Run this from your Mac terminal:  bash ~/jarvis/owners-inbox/sovereign-stack-repo/push-to-github.sh
# ═══════════════════════════════════════════════════════════════

set -e
REPO_DIR="$HOME/jarvis/owners-inbox/sovereign-stack-repo"
GITHUB_USER="ChrisJDiMarco"
REPO_NAME="sovereign-stack"

echo ""
echo "🚀 Sovereign Stack — GitHub Setup"
echo "════════════════════════════════════"
echo ""

# Step 1: Check git is available
if ! command -v git &> /dev/null; then
  echo "❌ git not found. Install Xcode CLI tools: xcode-select --install"
  exit 1
fi

# Step 2: Check gh CLI is available
if ! command -v gh &> /dev/null; then
  echo "⚠️  GitHub CLI (gh) not found. Installing via Homebrew..."
  brew install gh
fi

# Step 3: Check gh auth
echo "🔑 Checking GitHub authentication..."
if ! gh auth status &> /dev/null; then
  echo "👉 Opening GitHub login (browser will open)..."
  gh auth login --web
fi

echo "✅ GitHub authenticated"
echo ""

# Step 4: Init git repo
echo "📁 Setting up git repo..."
cd "$REPO_DIR"

if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi

git config user.email "chris.john.dimarco@gmail.com"
git config user.name "Chris DiMarco"

# Step 5: Create GitHub repo (skip if exists)
echo "🏗️  Creating GitHub repo..."
if gh repo view "$GITHUB_USER/$REPO_NAME" &> /dev/null; then
  echo "   Repo already exists — skipping create"
else
  gh repo create "$GITHUB_USER/$REPO_NAME" \
    --public \
    --description "The Sovereign Stack — Build Your Autonomous AI Agent OS on \$5/month" \
    --homepage "https://$GITHUB_USER.github.io/$REPO_NAME"
  echo "✅ Repo created: github.com/$GITHUB_USER/$REPO_NAME"
fi

# Step 6: Commit and push
echo "📤 Committing and pushing..."
git add .
git commit -m "Launch: Sovereign Stack sales page, blueprint, and agent plan" 2>/dev/null || \
  echo "   (nothing new to commit)"

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
git push -u origin main --force
echo "✅ Pushed to github.com/$GITHUB_USER/$REPO_NAME"

# Step 7: Enable GitHub Pages
echo "🌐 Enabling GitHub Pages..."
gh api "repos/$GITHUB_USER/$REPO_NAME/pages" \
  --method POST \
  -f "source[branch]=main" \
  -f "source[path]=/" \
  --silent 2>/dev/null && echo "✅ GitHub Pages enabled" || \
  echo "   (Pages may already be active — check github.com/$GITHUB_USER/$REPO_NAME/settings/pages)"

# Step 8: Done
echo ""
echo "════════════════════════════════════"
echo "✅ ALL DONE"
echo ""
echo "📦 Repo:       https://github.com/$GITHUB_USER/$REPO_NAME"
echo "🌐 Live page:  https://$GITHUB_USER.github.io/$REPO_NAME"
echo "   (Pages takes 2-3 min to go live after first push)"
echo ""
echo "NEXT STEPS (manual — ~5 min):"
echo "  1. Go to gumroad.com → New Product → upload product/blueprint.md as PDF"
echo "  2. Set price to \$97, slug to 'sovereign-stack'"
echo "  3. Copy the Gumroad URL, update in index.html:"
echo "     sed -i '' 's|https://gumroad.com/l/sovereign-stack|YOUR_REAL_URL|g' index.html"
echo "     git add index.html && git commit -m 'Live Gumroad link' && git push"
echo ""
echo "  Then run the Twitter thread in: owners-inbox/sovereign-stack-repo/launch-thread.md"
echo "════════════════════════════════════"
