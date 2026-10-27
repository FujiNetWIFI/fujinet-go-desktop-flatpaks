# fujinet-go-desktop-flatpaks

One Flatpak remote for every FujiNet Go desktop app, GNOME and KDE frontends.

```
flatpak remote-add --user --if-not-exists fujinet-go \
  https://fujinetwifi.github.io/fujinet-go-desktop-flatpaks/fujinet-go.flatpakrepo
flatpak install --user fujinet-go online.fujinet.go.nes.gnome
flatpak update
```

Single apps also install from `https://fujinetwifi.github.io/fujinet-go-desktop-flatpaks/<app-id>.flatpakref`.

## How it works

`.github/workflows/publish.yml` is the whole pipeline.

1. `scripts/plan.sh` compares each app's latest published release (see `apps.json`)
   with `versions.json` on the `gh-pages` branch.
2. Each stale app x frontend is built from the release tag's source with
   `flatpak-builder` (one matrix job each) and bundled.
3. `scripts/publish.sh` imports the bundles into the OSTree repo on `gh-pages`,
   signs it, regenerates appstream, and force-pushes a single commit. GitHub Pages serves it.

Runs daily, on `repository_dispatch` (`app-released`), and by hand:

```
gh workflow run publish.yml -f only=nes      # one app
gh workflow run publish.yml -f force=true    # rebuild everything
```

## Adding an app

Add it to `apps.json`. Its repo needs `build-aux/flatpak/online.fujinet.go.<name>.{gnome,kde}.yml`.

## Signing key

Secret `FLATPAK_GPG_PRIVATE_KEY` holds the signing key; the public half is embedded in
`fujinet-go.flatpakrepo`. Rotating the key means every user re-adds the remote.
