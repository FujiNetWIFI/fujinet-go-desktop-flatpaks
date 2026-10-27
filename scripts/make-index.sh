#!/usr/bin/env bash
# Print the landing page. Usage: make-index.sh <versions.json> <base-url>
set -euo pipefail
versions=$1
base_url=$2
apps=$(dirname "$0")/../apps.json

cat <<HTML
<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FujiNet Go desktop flatpaks</title>
<style>
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 46rem; margin: 2rem auto; padding: 0 1rem; }
  pre { background: #8881; padding: .75rem 1rem; overflow-x: auto; }
  td, th { padding: .2rem .8rem .2rem 0; text-align: left; }
</style>
<h1>FujiNet Go desktop flatpaks</h1>
<p>Add the remote once, then install and update like any other flatpak:</p>
<pre>flatpak remote-add --user --if-not-exists fujinet-go ${base_url}/fujinet-go.flatpakrepo
flatpak install --user fujinet-go online.fujinet.go.nes.gnome</pre>
<p>Each app comes in a GNOME and a KDE frontend (<code>.gnome</code> / <code>.kde</code>).</p>
<table>
<tr><th>App</th><th>Version</th><th>GNOME</th><th>KDE</th></tr>
HTML

jq -r --slurpfile v "$versions" '
  .[] | . as $a
  | "online.fujinet.go.\($a.name)" as $id
  | "<tr><td>\($a.title)</td><td>\($v[0][$id + ".gnome"] // "-")</td>"
    + "<td><code>\($id).gnome</code></td><td><code>\($id).kde</code></td></tr>"' "$apps"

echo '</table>'
