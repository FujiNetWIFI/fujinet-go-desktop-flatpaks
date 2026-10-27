#!/usr/bin/env bash
# Fold freshly built bundles into the OSTree repo on the gh-pages branch and
# push it back as a single orphan commit (history would only bloat Pages).
#
# Usage: publish.sh <artifacts-dir> <site-dir>
#   <artifacts-dir>/*/<id>.flatpak and <id>.tag come from the build jobs.
#   <site-dir> is a clone of gh-pages (created empty if the branch is new).
# Env: GPG_PRIVATE_KEY, GITHUB_REPOSITORY; optional PUSH_TOKEN (push when set).
set -euo pipefail

artifacts=$1
site=$2
root=$(cd "$(dirname "$0")/.." && pwd)
owner=${GITHUB_REPOSITORY%%/*}
base_url="https://${owner,,}.github.io/${GITHUB_REPOSITORY#*/}"

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
chmod 700 "$GNUPGHOME"
gpg --batch --quiet --import <<<"$GPG_PRIVATE_KEY"
key=$(gpg --batch --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')

if [[ ! -d $site/.git ]]; then
  mkdir -p "$site"
  git -C "$site" init -q -b gh-pages
fi
repo=$site/repo
[[ -f $repo/config ]] || ostree init --mode=archive-z2 --repo="$repo"

versions=$site/versions.json
[[ -s $versions ]] || echo '{}' > "$versions"

shopt -s nullglob
for bundle in "$artifacts"/*/*.flatpak; do
  id=$(basename "$bundle" .flatpak)
  tag=$(cat "${bundle%.flatpak}.tag")
  echo "importing ${id} ${tag}"
  flatpak build-import-bundle --gpg-sign="$key" --gpg-homedir="$GNUPGHOME" "$repo" "$bundle"
  jq --arg id "$id" --arg tag "$tag" '.[$id] = $tag' "$versions" > "$versions.new"
  mv "$versions.new" "$versions"
done

# one-commit history per ref: users only ever update forward
flatpak build-update-repo --prune --prune-depth=1 \
  --gpg-sign="$key" --gpg-homedir="$GNUPGHOME" \
  --title="FujiNet Go desktop apps" "$repo"

pubkey=$(gpg --batch --export "$key" | base64 -w0)

touch "$site/.nojekyll"

cat > "$site/fujinet-go.flatpakrepo" <<REPO
[Flatpak Repo]
Title=FujiNet Go desktop apps
Url=${base_url}/repo/
Homepage=${base_url}/
Comment=FujiNet Go emulator frontends for GNOME and KDE
GPGKey=${pubkey}
REPO

for id in $(jq -r 'keys[]' "$versions"); do
  cat > "$site/${id}.flatpakref" <<REF
[Flatpak Ref]
Title=${id}
Name=${id}
Branch=master
Url=${base_url}/repo/
IsRuntime=false
RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo
GPGKey=${pubkey}
REF
done

"$root/scripts/make-index.sh" "$versions" "$base_url" > "$site/index.html"

if [[ -n ${PUSH_TOKEN:-} ]]; then
  git -C "$site" -c user.name='github-actions[bot]' \
      -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
      checkout -q --orphan publish
  git -C "$site" add -A
  git -C "$site" -c user.name='github-actions[bot]' \
      -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
      commit -q -m "Publish flatpak repo"
  git -C "$site" push --force \
      "https://x-access-token:${PUSH_TOKEN}@github.com/${GITHUB_REPOSITORY}" publish:gh-pages
fi
