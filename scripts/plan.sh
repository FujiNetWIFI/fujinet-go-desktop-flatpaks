#!/usr/bin/env bash
# Decide which flatpaks need building: one entry per app x frontend whose
# latest published release tag differs from the tag recorded in versions.json
# on the gh-pages branch.
#
# Env: GH_TOKEN, GITHUB_REPOSITORY; optional ONLY (an app name), FORCE (true),
#      VERSIONS_FILE (test override for the gh-pages versions.json).
# Prints the matrix JSON, and writes matrix= and count= to $GITHUB_OUTPUT.
set -euo pipefail

cd "$(dirname "$0")/.."

known='{}'
if [[ -n ${VERSIONS_FILE:-} ]]; then
  known=$(cat "$VERSIONS_FILE")
else
  known=$(gh api "repos/${GITHUB_REPOSITORY}/contents/versions.json?ref=gh-pages" \
            --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)
  [[ -n $known ]] || known='{}'
fi

entries='[]'
while read -r name repo; do
  [[ -z ${ONLY:-} || $ONLY == "$name" ]] || continue
  # /releases/latest skips drafts and prereleases
  if ! tag=$(gh api "repos/${repo}/releases/latest" --jq .tag_name 2>/dev/null); then
    echo "::warning::no published release for ${repo}" >&2
    continue
  fi
  for frontend in gnome kde; do
    id="online.fujinet.go.${name}.${frontend}"
    have=$(jq -r --arg id "$id" '.[$id] // ""' <<<"$known")
    if [[ ${FORCE:-false} == true || $have != "$tag" ]]; then
      entries=$(jq -c --arg id "$id" --arg repo "$repo" --arg tag "$tag" \
        '. + [{id: $id, repo: $repo, tag: $tag,
               manifest: "build-aux/flatpak/\($id).yml"}]' <<<"$entries")
    fi
  done
done < <(jq -r '.[] | "\(.name) \(.repo)"' apps.json)

matrix=$(jq -c '{include: .}' <<<"$entries")
count=$(jq 'length' <<<"$entries")
echo "$matrix"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  echo "matrix=${matrix}" >> "$GITHUB_OUTPUT"
  echo "count=${count}" >> "$GITHUB_OUTPUT"
fi
