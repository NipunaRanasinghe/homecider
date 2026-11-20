# Design decisions

| Topic | Decision | Reason |
|---|---|---|
| Platform | Apple Silicon only; current and previous macOS release; laptops and desktops | VideoToolbox on every model. Intel is excluded because Apple no longer releases new macOS versions for it and there is no Intel Mac to test on |
| Containers | OrbStack | Lower RAM and CPU use than Docker Desktop |
| Jellyfin | Native (Homebrew cask), hidden user `_jellyfin`, LaunchDaemon | VideoToolbox (see README, Why macOS); a separate user keeps a media-file exploit away from personal files |
| Install | Homebrew tap (or `git clone`) + one idempotent `homecider` command | One entry point; re-running repairs drift; no `curl \| sh` |
| Configuration | `~/.config/homecider/homecider.env`; secrets and generated Compose `.env` files in `~/Library/Application Support/homecider/` (mode 700/600) | The code folder stays read-only (git checkout or Homebrew); personal values never enter the repository |
| Modules | `core` always; `media`, `photos` on; `backup`, `downloads`, `dashboard` opt-in | Each module can be reviewed and turned off |
| Downloads network | VPN-only by default (qBittorrent bound to `tun0`); home connection only with `DOWNLOADS_ALLOW_HOME_IP=true` | Safe default; the home IP is exposed only by explicit choice |
| Access | Home network only; no port forwards, no UPnP; tools without a login listen on 127.0.0.1 | Nothing reachable from the internet |
| Alerts | ntfy.sh with a random topic | No mail account needed |
| Updates | Homebrew casks and container images weekly via launchd; Immich pinned with a release notice; macOS download-only | No Docker-socket updater; Immich releases can break; macOS updates restart into FileVault |
| Disk encryption | FileVault recommended; no auto-login | A stolen Mac does not expose data |
| First admin accounts | Created by the user in each web UI | homecider never chooses or stores the user's passwords |
