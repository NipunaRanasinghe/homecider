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

## Set up your phone and other devices

1. Install the Tailscale app and sign in with the same account.
2. Check that it works with Tailscale on and Wi-Fi off:
   - Jellyfin: `http://<mac-name>.<tailnet>.ts.net:8096`
   - Immich: `http://<mac-name>.<tailnet>.ts.net:2283`

**Jellyfin apps** (phone, TV, laptop): add a server with the Tailscale address. At home the apps can keep using
the local address.

**Immich app**: Settings → Networking → turn on **Automatic URL switching**.

- Local network: your home Wi-Fi name and the local URL, for example `http://<mac>.local:2283`.
- External network: `http://<mac-name>.<tailnet>.ts.net:2283`.

The app reads the Wi-Fi name to choose the URL, so it asks for location permission. Background backup away from
home works only while Tailscale is connected on the phone.

The traffic is plain HTTP inside the Tailscale tunnel. The tunnel encrypts it between your devices.

## What stays unreachable

- qBittorrent (`:8080`) and Maintainerr (`:6246`) listen on `127.0.0.1` only, so they are not reachable through
  Tailscale either. Use an SSH tunnel, for example
  `ssh -L 8080:127.0.0.1:8080 <mac-name>.<tailnet>.ts.net`.
- Seerr, Radarr, Sonarr and Prowlarr (with the `downloads` module) listen on all interfaces, so every device in
  your tailnet can reach them. Each requires a login.
- Every device signed in to your Tailscale account can reach the Mac. To limit this, use Tailscale access
  controls (ACLs) in the admin console.

## Turn it off

```sh
sudo tailscale down                     # disconnect, keep the setup
sudo brew services stop tailscale       # stop the daemon and remove it from boot
brew uninstall tailscale
```

Remove the Mac from the admin console (Machines → ⋯ → Remove).
