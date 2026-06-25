#!/usr/bin/env bash
#
# Calculate the next semantic-version tag for a release.
#
# Self-contained semver tagging for the release workflow (no third-party action).
# It mirrors the branching strategy documented in CONTRIBUTING.md, deciding the
# bump level from the prefix of the branch(es) merged since the last tag:
#
#   major/*           -> major bump   (X+1.0.0)
#   feature/*         -> minor bump   (X.Y+1.0)
#   bugfix/*          -> patch bump   (X.Y.Z+1)
#   docs?/* , misc/*  -> build        (core version unchanged)
#   (none matched)    -> patch        (safe default)
#
# Pushes to the develop branch (default: main) produce prereleases:  vX.Y.Z-alpha.N
# Pushes to the main branch    (default: release) produce stable:     vX.Y.Z
#
# Branch prefixes are read from merge-commit subjects, e.g.
#   "Merge pull request #123 from owner/feature/foo".
#
# Outputs (appended to $GITHUB_OUTPUT): semver_tag, semver, ancestor_tag, is_prerelease

set -euo pipefail

prefix="${PREFIX:-v}"
prerelease_id="${PRERELEASE_ID:-alpha}"
develop_branch="${DEVELOP_BRANCH:-main}"
main_branch="${MAIN_BRANCH:-release}"

branch="${GITHUB_REF#refs/heads/}"

# Latest stable tag (vX.Y.Z) is the base we bump from, and the ancestor for changelogs.
stable_re="^${prefix}[0-9]+\.[0-9]+\.[0-9]+$"
ancestor_tag="$(git tag --sort=-v:refname | grep -E "$stable_re" | head -n1 || true)"

if [ -z "$ancestor_tag" ]; then
  base="0.0.0"
  range=""
else
  base="${ancestor_tag#"$prefix"}"
  range="${ancestor_tag}..HEAD"
fi

IFS='.' read -r major minor patch <<<"$base"

# Subjects of commits introduced since the last stable tag.
if [ -n "$range" ]; then
  subjects="$(git log "$range" --pretty=%s 2>/dev/null || true)"
else
  subjects="$(git log --pretty=%s)"
fi

pick_bump() {
  if echo "$subjects" | grep -Eq '(^|/)major/';        then echo major; return; fi
  if echo "$subjects" | grep -Eq '(^|/)feature/';      then echo minor; return; fi
  if echo "$subjects" | grep -Eq '(^|/)bugfix/';       then echo patch; return; fi
  if echo "$subjects" | grep -Eq '(^|/)(docs?|misc)/'; then echo build; return; fi
  echo patch
}
bump="$(pick_bump)"

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  build) : ;; # keep core version, just cut a new (pre)release
esac
core="${major}.${minor}.${patch}"

if [ "$branch" = "$develop_branch" ]; then
  is_prerelease=true
  core_re="${core//./\\.}"
  last_n="$(git tag --sort=-v:refname \
    | grep -E "^${prefix}${core_re}-${prerelease_id}\.[0-9]+$" \
    | head -n1 | sed -E 's/.*\.([0-9]+)$/\1/' || true)"
  n=$(( ${last_n:-0} + 1 ))
  semver="${core}-${prerelease_id}.${n}"
elif [ "$branch" = "$main_branch" ]; then
  is_prerelease=false
  semver="${core}"
else
  echo "Refusing to version branch '$branch' (expected '$develop_branch' or '$main_branch')" >&2
  exit 1
fi

semver_tag="${prefix}${semver}"

echo "branch=$branch bump=$bump ancestor=${ancestor_tag:-<none>} -> $semver_tag (prerelease=$is_prerelease)" >&2

{
  echo "semver_tag=${semver_tag}"
  echo "semver=${semver}"
  echo "ancestor_tag=${ancestor_tag}"
  echo "is_prerelease=${is_prerelease}"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
