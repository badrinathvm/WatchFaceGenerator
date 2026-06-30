#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# release.sh — Bump version, tag, create GitHub Release, update Homebrew formula
#
# Usage:
#   ./release.sh <version>      e.g.  ./release.sh 2.1.0
#
# Requires:
#   GITHUB_TOKEN env var with repo scope for creating the GitHub Release
# ---------------------------------------------------------------------------

VERSION=${1:-}
if [[ -z "$VERSION" ]]; then
    echo "Usage: ./release.sh <version>  (e.g. ./release.sh 2.1.0)"
    exit 1
fi

TAG="v${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFT_FILE="$SCRIPT_DIR/WatchFaceGenerator.swift"
TAP_DIR="$SCRIPT_DIR/../homebrew-tap"
FORMULA="$TAP_DIR/Formula/watchface-generator.rb"
REPO="badrinathvm/WatchFaceGenerator"
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"

# ── Validate paths ──────────────────────────────────────────────────────────
if [[ ! -f "$SWIFT_FILE" ]]; then
    echo "✖  WatchFaceGenerator.swift not found at $SWIFT_FILE"; exit 1
fi
if [[ ! -f "$FORMULA" ]]; then
    echo "✖  Formula not found at $FORMULA"; exit 1
fi

echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Releasing watchface-generator $TAG"
echo "  └─────────────────────────────────────────┘"
echo ""

# ── Collect release notes interactively ────────────────────────────────────
echo "  ▶  Release title (e.g. v${VERSION} — What's New):"
printf "     > "; read -r RELEASE_TITLE
if [[ -z "$RELEASE_TITLE" ]]; then RELEASE_TITLE="${TAG}"; fi

echo ""
echo "  ▶  Release notes (type END on a new line when done):"
RELEASE_NOTES=""
while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    RELEASE_NOTES="${RELEASE_NOTES}${line}\n"
done

# ── 1. Push any pending local commits first ────────────────────────────────
echo ""
cd "$SCRIPT_DIR"
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
if [[ "$AHEAD" -gt 0 ]]; then
    echo "  ▶  Pushing $AHEAD pending local commit(s)..."
    git push origin main
    echo "  ✓  Pending commits pushed"
fi

# ── 2. Bump version in Swift script ────────────────────────────────────────
echo "  ▶  Bumping version → $VERSION"
sed -i '' "s/let version = \"[0-9.]*\"/let version = \"${VERSION}\"/" "$SWIFT_FILE"

# ── 3. Commit and push version bump ────────────────────────────────────────
echo "  ▶  Committing version bump..."
git add WatchFaceGenerator.swift release.sh
git diff --cached --quiet && echo "  ✓  Version already at $VERSION, skipping commit" || {
    git commit -m "Bump version to ${VERSION}"
    git push origin main
    echo "  ✓  Pushed to main"
}

# ── 4. Delete old tag if exists, create new one ─────────────────────────────
echo "  ▶  Tagging ${TAG}..."
git tag -d "$TAG" 2>/dev/null && echo "  ↺  Deleted local tag $TAG" || true
git push origin --delete "$TAG" 2>/dev/null && echo "  ↺  Deleted remote tag $TAG" || true
git tag "$TAG"
git push origin "$TAG"
echo "  ✓  Tagged and pushed ${TAG}"

# ── 5. Create GitHub Release with notes ────────────────────────────────────
if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "  ▶  Creating GitHub Release..."
    NOTES_ESCAPED=$(printf '%s' "$RELEASE_NOTES" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
    TITLE_ESCAPED=$(python3 -c "import json; print(json.dumps('${RELEASE_TITLE}'))")
    curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/${REPO}/releases" \
        -d "{\"tag_name\":\"${TAG}\",\"name\":${TITLE_ESCAPED},\"body\":${NOTES_ESCAPED},\"draft\":false,\"prerelease\":false}" \
        | python3 -c "import sys,json; r=json.load(sys.stdin); print('  ✓  Release URL: ' + r.get('html_url','(check GitHub)'))"
else
    echo "  ⚠  GITHUB_TOKEN not set — skipping GitHub Release creation."
    echo "     Set it with: export GITHUB_TOKEN=<your_token>"
fi

# ── 6. Compute sha256 ───────────────────────────────────────────────────────
echo "  ▶  Computing sha256..."
sleep 3
SHA256=$(curl -sL "$TARBALL_URL" | shasum -a 256 | awk '{print $1}')
if [[ -z "$SHA256" ]]; then
    echo "✖  Failed to compute sha256 — check that ${TAG} exists on GitHub"; exit 1
fi
echo "  ✓  sha256: $SHA256"

# ── 7. Update the Homebrew formula ─────────────────────────────────────────
echo "  ▶  Updating formula..."
cd "$TAP_DIR"
sed -i '' "s|refs/tags/v[0-9.]*\.tar\.gz|refs/tags/${TAG}.tar.gz|" "$FORMULA"
sed -i '' "s/version \"[0-9.]*\"/version \"${VERSION}\"/" "$FORMULA"
sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"${SHA256}\"/" "$FORMULA"
sed -i '' "s/assert_match \"[0-9.]*\"/assert_match \"${VERSION}\"/" "$FORMULA"
echo "  ✓  Formula updated"

# ── 8. Commit and push formula ──────────────────────────────────────────────
echo "  ▶  Pushing formula..."
git add Formula/watchface-generator.rb
git commit -m "watchface-generator ${VERSION}"
git push origin main
echo "  ✓  Formula pushed"

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │  ✅  watchface-generator ${TAG} released!"
echo "  │"
echo "  │  brew update && brew upgrade watchface-generator"
echo "  └──────────────────────────────────────────────────────┘"
echo ""
