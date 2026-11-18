# Design decisions

| Topic | Decision | Reason |
|---|---|---|
| Platform | Apple Silicon only; current and previous macOS release; laptops and desktops | VideoToolbox on every model. Intel is excluded because Apple no longer releases new macOS versions for it and there is no Intel Mac to test on; the code changes would be small (the `arm64` check in `doctor`, the `/opt/homebrew` path) |
| Containers | OrbStack | Lower RAM and CPU use than Docker Desktop |
| Jellyfin | Native (Homebrew cask), hidden user `_jellyfin`, LaunchDaemon | Containers on macOS cannot use VideoToolbox; a separate user keeps a media-file exploit away from personal files |
| Install | `git clone` + one idempotent `homecider` command | One entry point; re-running repairs drift; no `curl \| sh` |
| Configuration | `~/.config/homecider/homecider.env`; secrets and generated Compose `.env` files in `~/Library/Application Support/homecider/` (mode 700/600) | The code folder stays read-only (git checkout or Homebrew); personal values never enter the repository |
| Modules | `core` always; `media`, `photos` on; `downloads` opt-in | Each module can be reviewed and turned off |
| Downloads network | VPN-only by default (qBittorrent bound to `tun0`); home connection only with `DOWNLOADS_ALLOW_HOME_IP=true` | Safe default; the home IP is exposed only by explicit choice |
| Access | Home network only; no port forwards, no UPnP; tools without a login listen on 127.0.0.1 | Nothing reachable from the internet |
| Alerts | ntfy.sh with a random topic | No mail account needed |
| Updates | Homebrew casks and container images weekly via launchd; Immich pinned with a release notice; macOS download-only | No Docker-socket updater; Immich releases can break; macOS updates restart into FileVault |
| Disk encryption | FileVault recommended; no auto-login | A stolen Mac does not expose data |
| First admin accounts | Created by the user in each web UI | homecider never chooses or stores the user's passwords |
| License | MIT; third-party files keep their licenses | Permissive, common for setup tooling |

# Roadmap to 0.1.0

- [x] `core`, `media`, `photos`, `downloads` modules ported from a working server
- [x] `homecider init | apply | status | doctor`
- [x] Gluetun VPN container for `downloads` (qBittorrent and Prowlarr in its network, port forwarding, `homecider leaktest`). Compose config validated; not yet run against a real VPN provider
- [x] `backup` module: restic to Backblaze B2 / S3, nightly, 30-day deletion protection (no-delete app key + lifecycle), `homecider backup now | snapshots | restore-test`. Tested with a local repository; not yet against B2
- [x] `vault` helper: encrypted disk image for archives (`homecider vault create | open | close | list`); create requires reopening with the saved password. `list` and input checks tested; create/open need a person to type the password
- [ ] Automate the remaining app wiring where an API exists (Seerr, Prowlarr, Jellyfin library refresh)
- [ ] CI: shellcheck, `homecider doctor` dry run
- [ ] Fresh-install test on a second Mac
