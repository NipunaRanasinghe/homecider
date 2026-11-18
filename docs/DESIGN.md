# Design decisions

| Topic | Decision | Reason |
|---|---|---|
| Platform | Apple Silicon only; current and previous macOS release; laptops and desktops | VideoToolbox on every model; Intel needs different transcoding and more testing |
| Containers | OrbStack | Lower RAM and CPU use than Docker Desktop |
| Jellyfin | Native (Homebrew cask), hidden user `_jellyfin`, LaunchDaemon | Containers on macOS cannot use VideoToolbox; a separate user keeps a media-file exploit away from personal files |
| Install | `git clone` + one idempotent `homecider` command | One entry point; re-running repairs drift; no `curl \| sh` |
| Configuration | One `homecider.env` (untracked); secrets generated into `~/Library/Application Support/homecider/secrets.env` | Personal values never enter the repository |
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
- [ ] `backup` module: restic to Backblaze B2 / S3, nightly, 30-day deletion protection (no-delete app key + lifecycle)
- [ ] `vault` helper: encrypted disk image for archives (`homecider vault create | open | close`)
- [ ] Automate the remaining app wiring where an API exists (Seerr, Prowlarr, Jellyfin library refresh)
- [ ] CI: shellcheck, `homecider doctor` dry run
- [ ] Fresh-install test on a second Mac
