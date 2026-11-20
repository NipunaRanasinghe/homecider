"""Generate docs/images/architecture-{light,dark}.svg for the README. Run: python3 docs/images/architecture.py docs/images"""
import sys

THEMES = {
    "light": dict(bg="#ffffff", fg="#1f2328", muted="#59636e", line="#d0d7de", mac="#f6f8fa", macs="#424a53",
                  dev="#ffffff", net="#eef1f4", nets="#57606a",
                  core="#eaeef2", cores="#57606a", media="#ddf4ff", medias="#0969da", photos="#dafbe1",
                  photoss="#1a7f37", dl="#fff1e5", dls="#bc4c00", dash="#fbefff", dashs="#8250df",
                  bk="#d7f5f0", bks="#0e7a6d", store="#ffffff", stores="#8c959f"),
    "dark": dict(bg="#0d1117", fg="#e6edf3", muted="#9198a1", line="#3d444d", mac="#151b23", macs="#9198a1",
                 dev="#0d1117", net="#1c2128", nets="#9198a1",
                 core="#21262d", cores="#9198a1", media="#0c2d6b", medias="#4493f8", photos="#05341a",
                 photoss="#3fb950", dl="#3d1d00", dls="#db6d28", dash="#2b1458", dashs="#ab7df8",
                 bk="#08332f", bks="#39c5bb", store="#0d1117", stores="#656c76"),
}
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace"


def build(c):
    o = []
    a = o.append

    def box(x, y, w, h, fill, stroke, dashed=False, r=8, sw=1.5):
        d = ' stroke-dasharray="6 4"' if dashed else ""
        a(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{c[fill]}" stroke="{c[stroke]}" stroke-width="{sw}"{d}/>')

    def text(x, y, s, cls="t"):
        a(f'<text x="{x}" y="{y}" class="{cls}">{s}</text>')

    def node(x, y, w, h, title, lines, fill, stroke, dashed=False):
        box(x, y, w, h, fill, stroke, dashed)
        text(x + 12, y + 23 if lines else y + h / 2 + 5, title, "b")
        for i, l in enumerate(lines):
            text(x + 12, y + 42 + i * 16, l, "s")

    def tag(x, y, label, stroke):
        w = 8 + len(label) * 7.2
        a(f'<rect x="{x}" y="{y}" width="{w:.0f}" height="18" rx="4" fill="{c["bg"]}" stroke="{c[stroke]}" stroke-width="1"/>')
        a(f'<text x="{x + 5}" y="{y + 13}" class="m" fill="{c[stroke]}">{label}</text>')

    def arrow(d, color="muted", dashed=False, both=False):
        da = ' stroke-dasharray="5 4"' if dashed else ""
        m = f' marker-start="url(#a-{color})"' if both else ""
        a(f'<path d="{d}" fill="none" stroke="{c[color]}" stroke-width="1.6"{da}{m} marker-end="url(#a-{color})"/>')

    W, H = 1240, 720
    a(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" '
      f'aria-label="HomeCider architecture: devices on the home network reach an Apple Silicon Mac that runs Jellyfin, '
      f'Immich, an optional dashboard and an optional download chain; backups, alerts and downloads are the only '
      f'outgoing connections.">')
    a('<defs>')
    for col in ("muted", "dls", "bks"):
        a(f'<marker id="a-{col}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
          f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{c[col]}"/></marker>')
    a('</defs>')
    a(f'<style>.t{{font:13px {FONT};fill:{c["fg"]}}}.b{{font:600 14px {FONT};fill:{c["fg"]}}}'
      f'.s{{font:12px {FONT};fill:{c["muted"]}}}.h{{font:700 11px {FONT};letter-spacing:.08em;fill:{c["muted"]}}}'
      f'.m{{font:11px {MONO}}}.l{{font:11px {FONT};fill:{c["muted"]}}}.T{{font:700 16px {FONT};fill:{c["fg"]}}}</style>')
    a(f'<rect width="{W}" height="{H}" rx="12" fill="{c["bg"]}"/>')

    # Left: devices and network
    text(20, 50, "ON YOUR HOME NETWORK", "h")
    node(20, 72, 180, 56, "Phone", ["Immich app · Jellyfin"], "dev", "line")
    node(20, 144, 180, 56, "TV · laptop · tablet", ["Jellyfin · browser"], "dev", "line")
    node(20, 216, 180, 56, "Your computer", ["SSH"], "dev", "line")
    node(230, 72, 170, 200, "Home router", ["no port forwarding"], "net", "nets")
    for y in (100, 172, 244):
        arrow(f"M200,{y} L228,{y}")
    node(230, 296, 170, 56, "Tailscale", ["from away"], "net", "nets", dashed=True)
    arrow("M400,172 L428,172")
    arrow("M400,324 L428,324", dashed=True)

    # Legend
    text(20, 400, "KEY", "h")
    tag(20, 412, "module", "cores")
    text(92, 425, "HomeCider module that adds it", "l")
    text(20, 454, "🔒  only reachable on the Mac", "l")
    text(38, 470, "(use an SSH tunnel)", "l")
    a(f'<rect x="20" y="486" width="26" height="14" rx="3" fill="none" stroke="{c["muted"]}" stroke-dasharray="5 3"/>')
    text(54, 498, "optional or off by default", "l")

    # The Mac
    box(430, 20, 580, 604, "mac", "macs", r=12, sw=2)
    text(448, 48, "Apple Silicon Mac · macOS", "T")
    text(448, 66, "configured by HomeCider · containers in OrbStack", "s")

    box(448, 80, 544, 44, "core", "cores")
    tag(460, 93, "core", "cores")
    text(512, 106, "FileVault · firewall · key-only SSH · no sleep", "t")

    # Apps
    xs = (448, 636, 824)
    node(xs[0], 146, 168, 72, "Jellyfin", ["native · hardware", "transcoding"], "media", "medias")
    tag(xs[0] + 114, 129, "media", "medias")
    node(xs[1], 146, 168, 72, "Immich", ["with database and ML"], "photos", "photoss")
    tag(xs[1] + 107, 129, "photos", "photoss")
    node(xs[2], 146, 168, 72, "Homepage", ["dashboard"], "dash", "dashs", dashed=True)
    tag(xs[2] + 85, 129, "dashboard", "dashs")

    # Storage
    node(xs[0], 240, 168, 52, "Media library", ["~/Media"], "store", "stores")
    node(xs[1], 240, 168, 52, "Photo library", ["~/Photos/immich"], "store", "stores")
    node(xs[2], 240, 168, 52, "Vaults", ["encrypted disk images"], "store", "stores")
    arrow(f"M{xs[0] + 84},218 L{xs[0] + 84},238")
    text(xs[0] + 92, 233, "reads only", "l")
    arrow(f"M{xs[1] + 84},218 L{xs[1] + 84},238")

    # Downloads module
    box(448, 310, 544, 196, "mac", "dls", dashed=True)
    tag(460, 320, "downloads", "dls")
    text(546, 333, "off by default", "s")
    node(466, 350, 150, 56, "Seerr", ["request page"], "dl", "dls")
    node(640, 350, 160, 56, "Radarr · Sonarr", ["pick and file releases"], "dl", "dls")
    node(824, 350, 150, 56, "Prowlarr", [], "dl", "dls")
    node(466, 438, 150, 56, "Maintainerr 🔒", ["removes watched"], "dl", "dls")
    node(640, 438, 160, 56, "qBittorrent 🔒", ["downloads"], "dl", "dls")
    node(824, 438, 150, 56, "Gluetun", ["VPN kill switch"], "dl", "dls")
    arrow("M616,378 L638,378", "dls")
    arrow("M800,378 L822,378", "dls", both=True)
    arrow("M720,406 L720,436", "dls")
    arrow("M800,466 L822,466", "dls")
    arrow("M541,438 L541,422 L650,422 L650,408", "dls", dashed=True)
    text(548, 432, "cleanup", "l")

    # Background jobs
    text(448, 526, "IN THE BACKGROUND", "h")
    node(xs[0], 550, 168, 56, "Updates", ["weekly"], "core", "cores")
    tag(xs[0] + 121, 533, "core", "cores")
    node(xs[1], 550, 168, 56, "Backup", ["nightly, encrypted"], "bk", "bks", dashed=True)
    tag(xs[1] + 107, 533, "backup", "bks")
    node(xs[2], 550, 168, 56, "Alerts", ["every 5 minutes"], "core", "cores")
    tag(xs[2] + 121, 533, "core", "cores")

    # Internet
    text(1040, 50, "ON THE INTERNET", "h")
    node(1040, 350, 180, 56, "Indexers", ["search sites"], "net", "nets")
    node(1040, 438, 180, 56, "Torrent peers", ["only through the VPN"], "net", "nets")
    node(1040, 550, 180, 56, "ntfy.sh", ["alerts to your phone"], "net", "nets")
    node(1040, 648, 180, 56, "Backblaze B2 or S3", ["off-site backup"], "net", "nets", dashed=True)
    arrow("M974,378 L1038,378", "dls")
    arrow("M974,466 L1038,466", "dls")
    arrow("M992,578 L1038,578")
    arrow(f"M{xs[1] + 84},606 L{xs[1] + 84},676 L1038,676", "bks", dashed=True)
    a('</svg>')
    return "\n".join(o)


out = sys.argv[1]
for name, c in THEMES.items():
    with open(f"{out}/architecture-{name}.svg", "w") as f:
        f.write(build(c))
