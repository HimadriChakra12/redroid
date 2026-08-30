# droid

Personal Anbox alternative for X11, built on [redroid](https://github.com/remote-android/redroid-doc)
instead of Waydroid — no LXC, no nested Wayland compositor, just a Docker
container plus `scrcpy` for display. One resizable "phone screen" window,
not per-app native windows (that trade-off was made deliberately).

Data lives in `~/.droid` (overridable via `DROID_DIR`), separate from
anything else on the machine. The image ships Google Play Services
(MindTheGapps), Aurora Store, Fennec F-Droid, and Bare Browser, with the
stock browser/camera/dialer/etc. removed.

## Requirements

- Arch: `pacman -S docker android-tools scrcpy jq curl git python`
- `binder_linux` and `ashmem_linux` kernel modules:

  ```
  sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
  sudo modprobe ashmem_linux
  ```

  Add both to `/etc/modules-load.d/redroid.conf` to survive reboots.

## First run

```
make image     # builds redroid+MindTheGapps locally (slow, one-time)
make setup     # boots the container, installs apps, strips defaults
make run       # opens the scrcpy window
```

After that, day to day it's just `make run` (implies `up`).

## Getting files in and out

- **Host → device**: `src/push.c` is a standalone C binary (no `make`/repo
  context needed once built) that pushes files into the device's
  `/sdcard/Download` over `adb push` — sudoless by construction, since it
  never touches the host bind-mount, just the adb protocol.

  ```
  make install-push   # builds + installs to ~/.local/bin/push
  push file1.apk photo.jpg
  ```

  Override the target device with `ADB_HOST`/`ADB_PORT` env vars if you're
  not on the default `127.0.0.1:5555`.

- **Device → host**: Android's shared storage is symlinked automatically at
  `~/.droidstorage` (→ `~/.droid/media/0`) by `up.sh` — copy straight out of
  `~/.droidstorage/Download` etc. That directory is written by root/
  media_rw inside the container, so `up.sh` also grants your user read
  access via a POSIX ACL (`setfacl`, tried with `sudo -n` so it never hangs
  on a password prompt). If that fails silently (no passwordless sudo
  configured), it'll print the exact command to run once yourself:

  ```
  sudo setfacl -R -m u:$(whoami):rX -d -m u:$(whoami):rX ~/.droid/media
  ```

  To make even that one-time step unnecessary, add a scoped sudoers rule
  (`sudo visudo -f /etc/sudoers.d/droid-storage`) so `up.sh`'s `sudo -n`
  attempt succeeds without ever prompting:

  ```
  himadri ALL=(root) NOPASSWD: /usr/bin/setfacl -R -m u\:himadri\:rX -d -m u\:himadri\:rX /home/himadri/.droid/media
  ```

## Layout

```
config/env.sh              all the tunables (data dir, container name, android version...)
config/apps-install.json   apps to sideload — array of {name, source, ...}
config/apps-remove.list    packages to pm-uninstall after first boot
scripts/                   one script per Makefile target
```

Edit the two config files to change what's installed/removed — no code
changes needed. Re-run `make provision` / `make strip` any time.

`apps-install.json` entries take one of three shapes:

```json
{ "name": "Aurora Store", "source": "fdroid", "id": "com.aurora.store" }
{ "name": "Bare Browser", "source": "github", "id": "Shshtwy/bare-browser" }
{ "name": "Some App",     "source": "url",    "id": "https://example.com/app.apk" }
```

- `fdroid` — `id` is an F-Droid package id, resolves the latest version via their API.
- `github` — `id` is `owner/repo`, pulls the newest `.apk` asset from the latest release.
- `url` — `id` is a direct link to an APK, downloaded as-is (no version resolution).

There's a placeholder `TODO` entry in `apps-install.json` — fill in its `id`
with a real URL (or delete the entry) before running `make provision`.
Left as-is it'll just fail and get skipped; it won't break the other installs.

## Caveats / things to check on your machine

- `build-image.sh` shells out to a community script
  ([ayasa520/redroid-script](https://github.com/ayasa520/redroid-script))
  to bake MindTheGapps in via its `-mtg` flag, since doing that by hand
  means editing the system partition. Baking GApps in yourself is
  possible but is a separate, bigger project. This ecosystem has several
  forks with different, non-obvious flag names (`-m` means Magisk in some
  of them, not GApps) — if `make image` errors out on the flag or on a
  specific `ANDROID_VERSION`, check that repo's README/issues for the
  version you picked before assuming the wrapper is broken; falling back
  to `ANDROID_VERSION=12.0.0` in `config/env.sh` is the most commonly
  reported working combination.
- The exact image tag that script produces has moved around across
  versions/forks; `build-image.sh` greps `docker images` for it after the
  build rather than assuming a fixed name, and writes it to
  `config/.image-tag`. If the build succeeds but nothing matches the grep,
  check `docker images` yourself and drop the tag into that file manually.
- Freeform windowing (`run-display.sh`) is enabled via the standard
  `settings put global enable_freeform_support 1` /
  `force_resizable_activities 1` toggles. Whether that's enough to get
  real per-app resizable windows *inside* the mirrored screen varies by
  Android version — 13 may need extra `wm` flags. Treat it as a starting
  point, not guaranteed to work out of the box.
- `apps-remove.list` covers the common AOSP package names; the GApps image
  may use slightly different ones for some of them (e.g. Google's own
  dialer/messages instead of the AOSP ones) — check `adb shell pm list
  packages` after first boot and adjust the list.
