# HomeCider

**Home-brewed server for your spare Mac.** HomeCider turns an Apple Silicon Mac (a MacBook with the lid
closed, or a Mac mini) into a private home server for films, shows and photo backup, set up by one command
and kept on your home network.

> Status: early development (0.1.0-dev). Tested on a MacBook Air M1 with the current macOS.
> Other Apple Silicon Macs should work; reports are welcome.

## What you get

| Module | What it does | Default |
|---|---|---|
| `core` | Key-only SSH, no sleep (lid closed too), firewall and stealth mode, sharing services off, macOS updates download-only, push alerts (disk, battery, services, updates), weekly app and container updates, clean shutdown on low battery (laptops) | always on |
| `media` | [Jellyfin](https://jellyfin.org) running natively with Apple VideoToolbox hardware transcoding, as a hidden user that can read only your media folder | on |
| `photos` | [Immich](https://immich.app) photo and video backup from your phone, pinned version | on |
| `backup` | Nightly encrypted [restic](https://restic.net) backup to Backblaze B2 or any S3 bucket, 30-day deletion protection, restore test, alert when stale | off (needs a bucket) |
| `downloads` | Request and library management (Seerr, Radarr, Sonarr, Prowlarr, qBittorrent, Maintainerr) with 1080p quality profiles. VPN-only unless you opt in to your home connection | **off** |

Nothing is exposed to the internet: no port forwards, no UPnP, and admin-only tools listen on localhost.

## Why macOS and not Linux

- **Hardware transcoding.** Jellyfin uses VideoToolbox on Apple Silicon; Linux on these Macs has no hardware
  video encoder.
- **Battery as a UPS.** On a MacBook, power cuts are covered by the battery, with an alert and a clean shutdown.
- **FileVault.** The whole disk is encrypted when the Mac is off or stolen.

Containers run in [OrbStack](https://orbstack.dev), which uses less memory and CPU than Docker Desktop.
Jellyfin runs outside Docker because containers on macOS cannot use VideoToolbox.

## Requirements

- Apple Silicon Mac (M1 or later), current or previous macOS release
- [Homebrew](https://brew.sh)
- Remote Login (SSH) on, with your SSH public key in `~/.ssh/authorized_keys`. **`apply` turns off SSH password
  login**, so add the key first.
- FileVault on (recommended). After every restart the Mac must be unlocked in person before services start.

## Install

On the Mac that will be the server:

```sh
git clone https://github.com/NipunaRanasinghe/homecider.git ~/homecider
cd ~/homecider
bin/homecider init      # writes homecider.env; review MODULES and paths
bin/homecider doctor    # checks prerequisites
bin/homecider apply     # sets everything up; asks for your password once for system changes
```

`apply` is safe to re-run: after changing `homecider.env`, after `git pull`, or to repair a setting.

Then, once:

1. Install the [ntfy](https://ntfy.sh) app on your phone and subscribe to the topic `apply` printed.
2. Open Jellyfin at `http://<mac>:8096` and Immich at `http://<mac>:2283` **right away** and create the admin
   accounts. The first visitor becomes admin.
3. Jellyfin: Dashboard → Playback → Transcoding → Hardware acceleration: **Apple VideoToolbox**.
4. Laptops: set a charge limit (System Settings → Battery), so the battery is not held at 100% all the time.

## Everyday use

```sh
bin/homecider status    # services, jobs, containers, disk, battery, active alerts
bin/homecider apply     # after editing homecider.env or pulling a new version
```

- **Alerts** arrive on your phone when the disk is above 85%, the Mac runs on battery, a service is down for
  10 minutes, or a macOS update is waiting.
- **Vaults** for archives you rarely open (old phone backups, documents): `homecider vault create NAME` makes an
  AES-256 encrypted disk image in `~/Vault`; while closed it is unreadable, even to programs running as you.
  The `backup` module backs vaults up as they are, still encrypted.
- **Updates**: Homebrew apps and container images update every Sunday at 04:00. Immich is pinned; you get
  a message when a new release exists. macOS updates download automatically and wait for you, because each one
  restarts into the FileVault unlock screen.

## What `apply` changes on your Mac

So you can review it before running:

- `/etc/ssh/sshd_config.d/000-homecider.conf`: password and keyboard-interactive login off, root login off,
  only your user allowed.
- `pmset`: sleep off (also with the lid closed), wake on network.
- Application firewall on with stealth mode; File Sharing, Screen Sharing and Remote Apple Events off.
- Software Update: automatic check and download; no automatic install.
- LaunchAgents `io.homecider.alerts` and `io.homecider.update`; on laptops, LaunchDaemon `io.homecider.low-battery`.
- `media`: hidden user `_jellyfin` (UID 450), LaunchDaemon `io.homecider.jellyfin`, data in
  `/Library/Application Support/jellyfin`, a sudoers rule that lets you restart Jellyfin without a password.
  Your home folder becomes `750` and other home folders readable by other users become private.
- Secrets (ntfy topic, database and app passwords) in `~/Library/Application Support/homecider/secrets.env`,
  mode 600, never in the repository.

## Repository layout

```
bin/homecider          the command
lib/common.sh          config loading, defaults, helpers
modules/<name>/        root.sh (runs with sudo) and/or user.sh, plus the module's files
homecider.env.example  every setting, with defaults
docs/                  design decisions and module guides
```

## Third-party components

HomeCider installs and configures software from other projects; each keeps its own license.
`modules/photos/docker-compose.yml` and `example.env` are Immich's official files (AGPL-3.0), unmodified.
Container images belong to their projects (Immich, LinuxServer.io, Seerr, Maintainerr, Recyclarr).
Quality profiles come from [TRaSH Guides](https://trash-guides.info) via Recyclarr.

## License

[MIT](LICENSE)
