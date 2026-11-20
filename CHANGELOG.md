# Changelog

All notable changes to HomeCider are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

First release, planned as 0.1.0.

### Added

- `homecider` command: `init`, `doctor`, `apply`, `status`, `uninstall`, `secret set`, `backup`, `vault` and
  `leaktest`. `apply` is safe to run again.
- Install with Homebrew (`brew install nipunaranasinghe/homecider/homecider`) or from a git clone.
- `core` module: key-only SSH, no sleep, firewall in stealth mode, sharing services off, download-only macOS
  updates, push alerts through ntfy, weekly app and container updates, clean shutdown on low battery.
- `media` module: Jellyfin running natively with VideoToolbox hardware transcoding, as a hidden user.
- `photos` module: Immich with a pinned version and a notice when a new release exists.
- `backup` module: nightly encrypted restic backup to Backblaze B2 or S3, 30-day deletion protection, restore test.
- `downloads` module: Seerr, Radarr, Sonarr, Prowlarr, qBittorrent and Maintainerr with 1080p quality profiles;
  VPN-only through Gluetun unless the home connection is explicitly allowed.
- `dashboard` module: Homepage on port 3000 with a Mac status panel and read-only Docker access.
- Encrypted vaults for archives (`homecider vault`).
- Guide for remote access with Tailscale (`docs/remote-access.md`).

### Not yet tested

- Only tested on one Mac (MacBook Air M1).
- `downloads` with a real VPN provider: the Gluetun setup, `homecider leaktest` and the port forwarding alert.
- `backup` against Backblaze B2 (tested with a local repository only).
- `vault create` and `vault open`, which need a person to type the password.
- `homecider uninstall` with the `dashboard` module.
- The Immich app steps in `docs/remote-access.md`.
