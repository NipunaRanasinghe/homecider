# downloads module

Opt-in: add `downloads` to `MODULES` in `homecider.env`.

## Network

| `DOWNLOADS_NETWORK` | Behaviour |
|---|---|
| `vpn` (default) | qBittorrent is bound to the `tun0` interface. Until a VPN container provides `tun0`, it sends no peer or tracker traffic. Everything else (requests, search, quality profiles) works. |
| `home` | Torrent traffic uses your home connection. Every peer, and any copyright monitor in the swarm, sees your home IP address. Requires `DOWNLOADS_ALLOW_HOME_IP=true`. Do not add a router port forward. |

Downloading copyrighted material may be illegal where you live. HomeCider ships no indexers; you choose them.

## What apply sets up

- Containers: Seerr `:5055`, Radarr `:7878`, Sonarr `:8989`, Prowlarr `:9696` (each requires a login),
  qBittorrent and Maintainerr on `127.0.0.1` only (`:8080`, `:6246`; reach them with an SSH tunnel).
- `MEDIA_DIR` is mounted as `/data` in Radarr, Sonarr and qBittorrent; downloads go to `/data/torrents` and are
  hardlinked into `/data/Movies` and `/data/Shows`, so seeding uses no extra space.
- qBittorrent: random password (in `secrets.env`), UPnP off, executable and archive files skipped
  (`*.exe *.scr *.lnk *.bat *.cmd *.msi *.zip *.rar`), seeding stops at ratio 1 or after 1 day.
- Quality profiles from `modules/downloads/recyclarr.yml` (TRaSH Guides templates): 1080p only, H.264 or HEVC,
  DTS audio and Dolby Vision without HDR fallback rejected, SDR preferred, films at most 66 MB per minute
  (8 GB for 2 hours), episodes at most 50 MB per minute.
- Maintainerr rules: fully watched films and seasons go to a "Leaving soon" collection 6 days after the last
  view and are deleted 1 day later. Unwatched media is never matched.

## One-time setup in the web UIs

1. Radarr, Sonarr, Prowlarr: open each and set the login (Forms, Required) immediately.
2. Prowlarr: add indexers; Settings → Apps → add Radarr (`http://radarr:7878`) and Sonarr (`http://sonarr:8989`)
   with Prowlarr server `http://prowlarr:9696`.
3. Radarr and Sonarr: Settings → Download Clients → qBittorrent, host `qbittorrent`, port `8080`, user `admin`,
   password `QBIT_PASSWORD` from `secrets.env`. Root folders `/data/Movies` and `/data/Shows`.
4. Radarr and Sonarr: Settings → Connect → Emby/Jellyfin, host `host.docker.internal`, port `8096`, a Jellyfin
   API key, Update Library on, Map Paths From `/data/` To your `MEDIA_DIR/`.
5. Seerr: sign in with Jellyfin (`host.docker.internal:8096`); add Radarr and Sonarr with **Enable Scan** on
   (needed for download progress).
6. Maintainerr (`ssh -L 6246:localhost:6246 <mac>`): connect Jellyfin (`http://host.docker.internal:8096`, an
   API key), Radarr and Sonarr, then run `homecider apply` again to add the cleanup rules.
