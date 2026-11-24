<div align="center">

<h1><img src="docs/images/logo.png" alt="" width="52" align="absmiddle"/> HomeCider</h1>

**A self-hosted home server for Apple Silicon.**

<img src="docs/images/banner.jpg" alt="HomeCider: media streaming, photo management, system security, encrypted backups and media downloads" width="900"/>

HomeCider helps you turn an Apple Silicon Mac into a private home server. It brings together media streaming, photo and video backups, encrypted off-site backups, and system-level security in one automated setup.

[![shellcheck](https://github.com/NipunaRanasinghe/homecider/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/NipunaRanasinghe/homecider/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS on Apple Silicon](https://img.shields.io/badge/macOS-Apple%20Silicon-black?logo=apple)
![Status: 0.1.0-dev](https://img.shields.io/badge/status-0.1.0--dev-orange)

[Quick start](#quick-start) ·
[What you get](#what-you-get) ·
[Install](#install) ·
[Commands](#commands) ·
[How it works](#how-it-works) ·
[Docs](#documentation) ·
[Contributing](#contributing)

</div>

---

## Quick start

```sh
brew install nipunaranasinghe/homecider/homecider
homecider init && homecider doctor && homecider apply
```

> [!IMPORTANT]
> `apply` changes settings for the whole Mac and turns off SSH password login.
> Read [Before you install](#before-you-install) first.

> [!NOTE]
> Early development (0.1.0-dev). Reports from any Apple Silicon Mac are welcome.

## What you get

| | Module | What it does | Default |
|:-:|---|---|---|
| 🛡️ | `core` | Key-only SSH, no sleep (lid closed too), firewall and stealth mode, sharing services off, macOS updates download-only, push alerts (disk, battery, services, updates), weekly app and container updates, clean shutdown on low battery (laptops) | always on |
| 🎬 | `media` | [Jellyfin](https://jellyfin.org) running natively with Apple VideoToolbox hardware transcoding, as a hidden user that can read only your media folder | on |
| 🖼️ | `photos` | [Immich](https://immich.app) photo and video backup from your phone, pinned version | on |
| ☁️ | `backup` | Nightly encrypted [restic](https://restic.net) backup to Backblaze B2 or any S3 bucket, 30-day deletion protection, restore test, alert when stale. See [docs/backup.md](docs/backup.md) | off (needs a bucket) |
| ⬇️ | `downloads` | Request and library management (Seerr, Radarr, Sonarr, Prowlarr, qBittorrent, Maintainerr) with 1080p quality profiles. VPN-only unless you opt in to your home connection. See [docs/downloads.md](docs/downloads.md) | **off** |
| 📊 | `dashboard` | [Homepage](https://gethomepage.dev) on port 3000 for checking the server from a phone: services with live numbers, container status, and the Mac's battery, disk, memory, alerts and last backup. No login; see [docs/dashboard.md](docs/dashboard.md) | off |

HomeCider is designed for use on your home network. It does not configure public internet access or port forwarding, does not use UPnP, and keeps administrative tools bound to localhost. To reach Jellyfin and Immich away from home without exposing them, see [docs/remote-access.md](docs/remote-access.md).

<p align="center">
  <img src="docs/images/immich-demo.jpg" alt="Immich photo timeline in the web app" width="820"/><br/>
  <sub>Immich's photo timeline (<code>photos</code> module). Screenshot of Immich's public demo at <a href="https://demo.immich.app">demo.immich.app</a>, not of a HomeCider server.</sub>
</p>

<p align="center">
  <img src="docs/images/seerr-discover.jpg" alt="Seerr Discover page listing trending and popular films and shows" width="820"/><br/>
  <sub>Seerr's Discover page, where people at home request films and shows (<code>downloads</code> module, off by default).</sub>
</p>

<p align="center">
  <img src="docs/images/dashboard.png" alt="HomeCider dashboard at phone width: Mac status panel, then Jellyfin, Immich and the download apps with live counts" width="300"/><br/>
  <sub>The dashboard at phone width (<code>dashboard</code> module, off by default). See <a href="docs/dashboard.md">docs/dashboard.md</a>.</sub>
</p>

### Why macOS and not Linux

- **Hardware transcoding.** Jellyfin uses VideoToolbox on Apple Silicon; Linux on these Macs has no hardware
  video encoder.
- **Battery as a UPS.** On a MacBook, power cuts are covered by the battery, with an alert and a clean shutdown.
- **FileVault.** The whole disk is encrypted when the Mac is off or stolen.

Containers run in [OrbStack](https://orbstack.dev), which uses less memory and CPU than Docker Desktop.
Jellyfin runs outside Docker because containers on macOS cannot use VideoToolbox.

## Before you install

HomeCider is intended for a Mac that stays at home and is available most of the time. A dedicated machine is
recommended because HomeCider changes settings for the whole Mac; the full list is in
[What `apply` changes on your Mac](#what-apply-changes-on-your-mac). Every setting and its default is in
[`homecider.env.example`](homecider.env.example).

> [!WARNING]
> **After a restart or power cut, everything stays down until someone unlocks the Mac in person.** With
> FileVault on (recommended), macOS waits at the unlock screen before any service or SSH starts. Laptops ride
> out short power cuts on battery; desktops restart only when power returns and still need the unlock.

> [!IMPORTANT]
> **Your router must block incoming IPv6 connections.** HomeCider opens no ports on the router, but with IPv6
> the Mac gets an address that the internet can reach directly. Jellyfin, Immich, the dashboard and (with
> `downloads`) Seerr, Radarr, Sonarr and Prowlarr listen on every address, and the macOS firewall allows them. Most home routers drop
> incoming IPv6 connections; if yours does not, those pages (the dashboard has no login) are public.
>
> To check after `apply`: `homecider doctor` prints the Mac's public IPv6 address if it has one. On a phone using
> mobile data (Wi-Fi off, no VPN), open `http://[<that address>]:8096`. It must time out. If Jellyfin loads, turn
> on the router's IPv6 firewall, or turn off IPv6 on the router.

### Requirements

- Apple Silicon Mac (M1 or later), current or previous macOS release: MacBook (lid closed), Mac mini, iMac or
  Mac Studio. Intel Macs are not supported ([docs/DESIGN.md](docs/DESIGN.md)).
- [Homebrew](https://brew.sh)
- Remote Login (SSH) on, with your SSH public key in `~/.ssh/authorized_keys`. **`apply` turns off SSH password
  login**, so add the key first.
- FileVault on (recommended).

## Install

Run these commands on the Mac you want to use as your server:

```sh
brew install nipunaranasinghe/homecider/homecider
homecider init      # writes ~/.config/homecider/homecider.env; review MODULES and paths
homecider doctor    # checks prerequisites
homecider apply     # sets everything up; asks for your password once for system changes
```

`apply` is designed to be idempotent. You can run it again after changing `homecider.env`, after upgrading
HomeCider, or to reapply a setting.

To upgrade HomeCider: `brew upgrade homecider && homecider apply`.

<details>
<summary>Install from a git clone instead</summary>

```sh
git clone https://github.com/NipunaRanasinghe/homecider.git ~/homecider
cd ~/homecider
bin/homecider init && bin/homecider doctor && bin/homecider apply
```

Use `bin/homecider` wherever this README says `homecider`. To upgrade: `git pull && bin/homecider apply`.
</details>

### First-time checklist

1. Install the [ntfy](https://ntfy.sh) app on your phone and subscribe to the topic `apply` printed.
2. Open Jellyfin at `http://<mac>:8096` and Immich at `http://<mac>:2283` **right away** and create the admin
   accounts. The first visitor becomes admin.
3. Jellyfin: Dashboard → Playback → Transcoding → Hardware acceleration: **Apple VideoToolbox**.
4. Laptops: set a charge limit (System Settings → Battery), so the battery is not held at 100% all the time.

<p align="center">
  <img src="docs/images/jellyfin-transcoding.png" alt="Jellyfin transcoding settings with Apple VideoToolbox selected" width="700"/><br/>
  <sub>Step 3: Jellyfin's transcoding page with Apple VideoToolbox selected.</sub>
</p>

## Commands

| Command | What it does |
|---|---|
| `homecider init` | Creates `homecider.env` from the example |
| `homecider doctor` | Checks prerequisites and configuration |
| `homecider apply` | Sets up every enabled module (asks for sudo once); safe to re-run |
| `homecider status` | Shows services, jobs, containers, disk, battery and active alerts |
| `homecider backup now \| snapshots \| restore-test` | Runs a backup, lists snapshots, or tests a restore (`backup` module) |
| `homecider vault create \| open \| close \| list` | Manages encrypted disk images for archives |
| `homecider leaktest` | Checks that downloads go through the VPN (`downloads` module) |
| `homecider secret set NAME` | Stores a secret in `secrets.env` without echoing it |
| `homecider uninstall` | Stops services and removes system changes; data is kept |

<p align="center">
  <img src="docs/images/status.svg" alt="Output of homecider status" width="660"/><br/>
  <sub>Output of <code>homecider status</code> with <code>core</code>, <code>media</code>, <code>photos</code> and <code>downloads</code> enabled.</sub>
</p>

## Everyday use

### Alerts

Alerts arrive on your phone when:

- the disk is above 85% (`DISK_ALERT_PCT`)
- the Mac runs on battery
- Jellyfin or Immich is down for 10 minutes
- a container stops or reports unhealthy
- VPN port forwarding is on but Gluetun has had no forwarded port for 10 minutes (`downloads` module)
- the last backup is more than 36 hours old
- a macOS update is waiting

Alerts go through the public [ntfy.sh](https://ntfy.sh) server: the message text (e.g. "Disk 91% full",
"Jellyfin is down") passes through it, and anyone who knows your topic name can read your alerts. The topic is
random (`hc-` plus 24 hex characters); keep it private, or set `NTFY_SERVER` to your own ntfy server.

### Vaults

For archives you rarely open (old phone backups, documents): `homecider vault create NAME` makes an
AES-256 encrypted disk image in `~/Vault`; while closed it is unreadable, even to programs running as you.
The `backup` module backs vaults up as they are, still encrypted.

### Updates

- HomeCider's Homebrew apps (OrbStack, Jellyfin, restic) and container images update every Sunday at 04:00
  (`UPDATE_WEEKDAY`, `UPDATE_HOUR`). Set `UPDATE_ALL_HOMEBREW=true` to upgrade every Homebrew app.
- HomeCider itself is not upgraded by this job: a new version takes effect only after `apply` (see [Install](#install)).
- After the update, dangling Docker images (untagged, unused) are removed; `UPDATE_PRUNE_IMAGES=false` keeps them.
- Immich is pinned; you get a message when a new release exists.
- macOS updates download automatically and wait for you, because each one restarts into the FileVault unlock
  screen.

## How it works

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/architecture-dark.svg">
  <img src="docs/images/architecture-light.svg" width="100%" alt="HomeCider architecture. Devices on the home network reach the Mac through the router; Tailscale is optional for access from away. The Mac runs the core security settings, Jellyfin natively with VideoToolbox (media), Immich with its database, cache and machine learning (photos), and the optional Homepage dashboard. The optional downloads module chains Seerr, Radarr and Sonarr, Prowlarr, qBittorrent and Gluetun, with Maintainerr removing watched media; qBittorrent and Maintainerr are reachable only on the Mac. Background jobs run weekly updates, alerts every 5 minutes, and the optional nightly encrypted backup. Outgoing connections go to indexers, torrent peers through the VPN, ntfy.sh for alerts, and Backblaze B2 or S3 for backups.">
</picture>

🔒 listens on 127.0.0.1 only (use an SSH tunnel) · dashed: optional or off by default.
Without a VPN configured, qBittorrent sends nothing; the home connection is an explicit opt-in.

## What `apply` changes on your Mac

So you can review it before running:

| Area | Change |
|---|---|
| SSH | `/etc/ssh/sshd_config.d/000-homecider.conf`: password and keyboard-interactive login off, root login off, only your user allowed |
| Power | `pmset`: sleep off (also with the lid closed), wake on network. Laptops shut down at 15% battery (`BATTERY_SHUTDOWN_PCT`) |
| Network | Application firewall on with stealth mode; File Sharing, Screen Sharing and Remote Apple Events off |
| Software Update | Automatic check and download; no automatic install |
| launchd | LaunchAgents `io.homecider.alerts` and `io.homecider.update`; on laptops, LaunchDaemon `io.homecider.low-battery` |
| `media` | Hidden user `_jellyfin` (UID 450), LaunchDaemon `io.homecider.jellyfin`, data in `/Library/Application Support/jellyfin`, a sudoers rule that lets you restart Jellyfin without a password. Your home folder becomes `750` and other home folders readable by other users become private |
| `photos`, `downloads` or `dashboard` | A `PATH` line for OrbStack's `docker` in `~/.zshenv`, the compose and buildx plugins linked into `~/.docker/cli-plugins/`, OrbStack set to start at login with a memory cap (`DOCKER_MEMORY_MIB`) |
| Files | Your settings in `~/.config/homecider/homecider.env`. Secrets (ntfy topic, database and app passwords) in `~/Library/Application Support/homecider/secrets.env` (mode 600), generated Compose settings in `~/Library/Application Support/homecider/compose/`. Nothing is written into the code folder |

## Uninstall

```sh
homecider uninstall
brew uninstall homecider    # only after homecider uninstall: the launchd jobs run scripts from this install
```

Stops the containers, removes the launchd jobs, the SSH config file, the sudoers rule and the `_jellyfin` user,
and resets `pmset` to the macOS defaults (sleep on). SSH password login is allowed again.

- **Kept**: media, photos, app data, Jellyfin data, vaults, `homecider.env`, `secrets.env`, the backup repository
  and the Homebrew apps (`brew uninstall --cask orbstack jellyfin` removes them).
- **Not changed back**: firewall and stealth mode, sharing services (off), the macOS update policy and
  home-folder permissions. HomeCider does not record their values before `apply`; change them in System Settings.

## Documentation

| Document | Contents |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Design decisions |
| [docs/backup.md](docs/backup.md) | Setting up and restoring the `backup` module |
| [docs/downloads.md](docs/downloads.md) | Setting up the `downloads` module and its VPN |
| [docs/remote-access.md](docs/remote-access.md) | Reaching Jellyfin and Immich away from home with Tailscale |
| [docs/dashboard.md](docs/dashboard.md) | The `dashboard` module: what it shows, API keys, access |
| [homecider.env.example](homecider.env.example) | Every setting, with defaults |
| [CHANGELOG.md](CHANGELOG.md) | Changes in each release, and what is not yet tested |

## Contributing

Contributions are welcome. If you find a bug or have an improvement, please open an issue or submit a focused pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for issue details and testing guidance.

For security vulnerabilities, use GitHub's private vulnerability reporting rather than opening a public issue.

## Third-party components

HomeCider installs and configures software maintained by other projects. Each component remains subject to its own license.
`modules/photos/docker-compose.yml` and `example.env` are Immich's official files (AGPL-3.0), unmodified.
Container images belong to their projects (Immich, LinuxServer.io, Seerr, Maintainerr, Recyclarr).
Quality profiles come from [TRaSH Guides](https://trash-guides.info) via Recyclarr.

## License

[MIT](LICENSE)
