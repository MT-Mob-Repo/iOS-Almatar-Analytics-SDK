#!/usr/bin/env bash
# Outputs the next semantic version (major.minor.patch) by incrementing the patch of the latest tag.
set -e
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
major=$(echo "$latest_tag" | cut -d. -f1)
minor=$(echo "$latest_tag" | cut -d. -f2)
patch=$(echo "$latest_tag" | cut -d. -f3)
patch=$((patch + 1))
echo "${major}.${minor}.${patch}"
