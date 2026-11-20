# Remote access with Tailscale

HomeCider services are reachable only from your home network. To use Jellyfin and Immich away from home (for
example, phone photo backup on mobile data), connect the Mac and your devices with
[Tailscale](https://tailscale.com). HomeCider does not install or configure it; the steps below are manual.

Tailscale builds an encrypted WireGuard network between your own devices. Connections are made outbound from each
device, so the router needs no port forward and nothing on the Mac becomes reachable from the internet.

Plain WireGuard is not recommended here: it needs a UDP port forward on the router, which HomeCider avoids.

## What Tailscale can see

Tailscale's coordination server stores your device list, their names and Tailscale IP addresses, and when they
were last online. It does not see your traffic: connections are end-to-end encrypted between your devices. When
two devices cannot connect directly, traffic passes through Tailscale's relay servers, still encrypted.

To avoid Tailscale's server, run [Headscale](https://github.com/juanfont/headscale), a self-hosted coordination
server, on a machine you control. Its setup is not covered here.

## Set up the Mac (about 5 minutes)

Use the Homebrew `tailscale` formula. It runs `tailscaled` as a system daemon, so it does not depend on a logged-in
desktop session. The Tailscale app from the App Store or tailscale.com also works but runs only while you are
logged in.

```sh
brew install tailscale
sudo brew services start tailscale     # starts tailscaled now and at every boot
sudo tailscale up                       # prints a login URL; open it in any browser and sign in
tailscale status                        # lists the Mac and its Tailscale name
```

Then, in the Tailscale admin console (Machines → the Mac → ⋯):

- **Disable key expiry.** By default a device must sign in again every 180 days; until it does, remote access
  stops.

The Mac's name is shown as `<mac-name>.<tailnet>.ts.net` (MagicDNS). `tailscale ip -4` shows its `100.x.y.z`
address; either works in the URLs below.

With FileVault on, Tailscale starts only after the Mac is unlocked in person, like every other service.

## Allow Tailscale connections in Jellyfin

Jellyfin treats Tailscale addresses (`100.64.0.0/10`) as outside your home network. With remote connections off,
the Jellyfin page loads through Tailscale but then shows "Select server" or "Connection failure".

1. On the home network, open Jellyfin at the Mac's local address (for example `http://192.168.1.6:8096`) and log in as admin.
2. Dashboard → Networking → turn on **Allow remote connections to this server** → Save.
3. Restart Jellyfin: `sudo launchctl kickstart -k system/io.homecider.jellyfin` (no password needed).

This opens nothing to the internet: without a router port forward, the only remote devices that can reach
Jellyfin are the ones signed in to your Tailscale account.

Check from a device on Tailscale: `http://<mac-name>.<tailnet>.ts.net:8096/System/Info/Public` shows a short JSON
text with `"ServerName"`. An error or blank page means remote connections are still off.

## Set up your phone and other devices

1. Install the Tailscale app and sign in with the same account.
2. Check that it works with Tailscale on and Wi-Fi off:
   - Jellyfin: `http://<mac-name>.<tailnet>.ts.net:8096`
   - Immich: `http://<mac-name>.<tailnet>.ts.net:2283`

**Jellyfin apps** (phone, TV, laptop): add a server with the Tailscale address. At home the apps can keep using
the local address.

**Immich app**: in the app's settings, open the networking section and turn on automatic URL switching. (Menu
names differ between app versions; this step has not been checked against the current app.)

- Local network: your home Wi-Fi name and the local URL with the Mac's local IP address, for example
  `http://192.168.1.6:2283`. Android cannot open `.local` names, so do not use `http://<mac>.local:2283` there.
- External network: `http://<mac-name>.<tailnet>.ts.net:2283`.

The app reads the Wi-Fi name to choose the URL, so it asks for location permission. Background backup away from
home works only while Tailscale is connected on the phone.

The traffic is plain HTTP inside the Tailscale tunnel. The tunnel encrypts it between your devices.

## If it does not work

- **The `ts.net` name does not load, but the `100.x.y.z` address does**: on the phone, check that the Tailscale
  app's **Use Tailscale DNS** is on, and on Android that Private DNS is **Automatic** (a provider hostname
  bypasses Tailscale's DNS). Then turn Tailscale off and on. The `100.x.y.z` address always works as a fallback.
- **Jellyfin shows "Select server" or "Connection failure"**: remote connections are off; see
  [Allow Tailscale connections in Jellyfin](#allow-tailscale-connections-in-jellyfin).
- **Slow**: `tailscale status` on the Mac shows `direct` or `relay` for each device. The first connection can go
  through a Tailscale relay server; it normally switches to `direct` within a minute.

## What stays unreachable

- qBittorrent (`:8080`) and Maintainerr (`:6246`) listen on `127.0.0.1` only, so they are not reachable through
  Tailscale either. Use an SSH tunnel, for example
  `ssh -L 8080:127.0.0.1:8080 <mac-name>.<tailnet>.ts.net`.
- Seerr, Radarr, Sonarr and Prowlarr (with the `downloads` module) listen on all interfaces, so every device in
  your tailnet can reach them. Each requires a login.
- The dashboard (port 3000, with the `dashboard` module) has **no login**, so every device in your tailnet can
  open it.
- Every device signed in to your Tailscale account can reach the Mac. To limit this, use Tailscale access
  controls (ACLs) in the admin console.

## Turn it off

```sh
sudo tailscale down                     # disconnect, keep the setup
sudo brew services stop tailscale       # stop the daemon and remove it from boot
brew uninstall tailscale
```

Remove the Mac from the admin console (Machines → ⋯ → Remove).
