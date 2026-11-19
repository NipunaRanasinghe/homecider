# dashboard module

A [Homepage](https://gethomepage.dev) page on port 3000 that shows the enabled services and the Mac's state, for
checking the server from a phone. Add `dashboard` to `MODULES`, then run `homecider apply`.

- At home: `http://<local IP of the Mac>:3000`, for example `http://192.168.1.6:3000`. The `.local` name
  (`http://<mac>.local:3000`) works on iPhones and Macs, but not on most Android phones.
- Away, with [Tailscale](remote-access.md): `http://<mac-name>.<tailnet>.ts.net:3000`

Give the Mac a fixed local IP address (a DHCP reservation in the router), so the address does not change.

## What it shows

**Mac**: battery, disk used, free memory, load (1-minute average), active alerts, last backup and whether the
launchd jobs are loaded. The alerts job writes these values to `status.json` every 5 minutes.

**Services**, generated from `MODULES` on every `apply`:

| Service | Link | Running / stopped | Numbers (needs a key) |
|---|---|---|---|
| Jellyfin | yes | no (not a container) | movies, series, episodes; what is playing. Key: see below |
| Immich | yes | yes | users, photos, videos, storage. Key: see below |
| Seerr | yes | yes | pending, approved, available requests. Key read from Seerr's `settings.json` |
| Radarr, Sonarr, Prowlarr | yes | yes | queue, missing, grabs. Keys already in `secrets.env` |
| qBittorrent | no (127.0.0.1 only) | yes | download and upload speed. Uses `QBIT_PASSWORD` |
| Maintainerr, Gluetun | no | yes | none |

Links use the Mac's Tailscale name when Tailscale is installed (works at home and away while Tailscale is on in
the phone), otherwise its local IP address.

## Jellyfin and Immich keys (once)

Jellyfin: Dashboard → API Keys → **+**, name it `homecider`. Then on the Mac:

```sh
homecider secret set JELLYFIN_API_KEY
```

Immich: Account Settings → API Keys → **New API Key**, with the `server.statistics` permission. Then:

```sh
homecider secret set IMMICH_API_KEY
```

Run `homecider apply` after setting a key.

## Access and security

- **No login.** Anyone who can open port 3000 can view the page: devices on your home network and devices signed
  in to your Tailscale account. Every app behind it still needs its own login.
- **API keys stay on the Mac.** They are in the generated config (`~/Library/Application Support/homecider/
  compose/dashboard/config/`, mode 600); Homepage calls the services from the server, not from the browser.
- **Allowed host names.** Homepage answers only requests addressed to the Mac's `.local` name, its local IP
  address and, with Tailscale, its Tailscale name and IP (`HOMEPAGE_ALLOWED_HOSTS`). If the local IP address
  changes, run `homecider apply` again.
- **Docker access is read-only.** Homepage reads container status through a proxy container that refuses every
  write request (`POST=0`); it cannot start, stop or create containers.

## Containers

All three are pinned in `modules/dashboard/docker-compose.yml`; the weekly update job does not change them.

| Container | Image | Published on the Mac |
|---|---|---|
| `homepage` | `ghcr.io/gethomepage/homepage:v2.8.0` | port 3000, all interfaces |
| `homepage-socket-proxy` | `tecnativa/docker-socket-proxy:v0.4.2` | no |
| `homepage-status` | `busybox:1.37` (serves `status.json`) | no |

Generated config: `settings.yaml`, `services.yaml`, `docker.yaml`, `widgets.yaml` and `bookmarks.yaml` are
rewritten on every `apply`. Edits to them are lost; Homepage's other files in that folder are left alone.
