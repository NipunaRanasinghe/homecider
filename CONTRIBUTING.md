# Contributing to HomeCider

Thanks for helping. HomeCider is maintained by one person in spare time, so small, focused changes are easiest
to review.

## Reporting a problem

Open an issue with:

- Mac model and chip (e.g. Mac mini M2), macOS version (`sw_vers -productVersion`)
- Enabled modules and any non-default settings from `homecider.env` (leave out paths you consider private)
- Output of `homecider doctor` and `homecider status` (`bin/homecider` in a git clone)
- The failing command and its output; logs from `~/Library/Logs/homecider/`

**Never post** `secrets.env`, `.env` files, API keys, passwords, your ntfy topic or VPN keys.
Security issues: do not open a public issue; use GitHub's private vulnerability reporting on this repository.

Issues asking which indexers, trackers or download sources to use are closed without an answer. HomeCider ships
none and does not recommend any.

## Testing on your Mac

Reports from different Mac models are especially useful:

1. Fresh install following the README, on a Mac you can reset.
2. Run `homecider apply` twice: the second run must finish without errors and without restarting Jellyfin.
3. Note anything you had to do by hand.

## Changing code

- **Shell**: POSIX `sh` (no bash-only syntax), `set -eu` in scripts, quote variables. Run
  `shellcheck -s sh` on changed files, and `bats tests` (`brew install bats-core`) when you change `lib/common.sh`.
- **Idempotent**: every step must be safe to run again. Check before you create, compare before you restart.
- **No personal values**: everything specific to a server comes from `homecider.env` or `secrets.env`.
  Add new settings to `homecider.env.example` with their default and a one-line explanation.
- **Secrets** go through `ensure_secret` / `set_secret` (mode 600, outside the repository), never into git.
- **Safe defaults**: nothing new may listen on the internet, and anything that weakens security must be an
  explicit opt-in, as `DOWNLOADS_ALLOW_HOME_IP` is.
- **Root vs user**: system changes go in a module's `root.sh` (run once under sudo by `apply`); everything else in
  `user.sh`. Root scripts must not depend on files the user can change at runtime.
- **Docs**: update the README section "What `apply` changes on your Mac" when you change system settings, and the
  module's doc in `docs/`.
- Commits: one short subject line describing the change.

## Repository layout

```
bin/homecider          the command
lib/common.sh          config loading, defaults, helpers
modules/<name>/        root.sh (runs with sudo) and/or user.sh, plus the module's files
homecider.env.example  every setting, with defaults
docs/                  design decisions and module guides
tests/                 BATS tests (run: bats tests)
```

## Adding a module

A module is a folder in `modules/` with `root.sh` and/or `user.sh`, enabled by name in `MODULES`. Before writing
one, open an issue describing what it installs, what it changes on the Mac, and how it stays off the internet.

A module that runs a service, uses Docker or stores data also has a manifest, `modules/<name>/module.env`.
`lib/common.sh` sources every manifest, so it holds only variable assignments, no commands:

- **Defaults** for the module's settings, as `: "${PHOTOS_DIR:=$HC_HOME/Photos/immich}"`. Also add each setting
  to `homecider.env.example`.
- **`MOD_*` fields**, read by the core scripts with `module_field <module> <field>`. Leave out the ones that do
  not apply.

| Field | Example | Used by |
|---|---|---|
| `MOD_TITLE` | `Immich` | Name in alert and release messages |
| `MOD_STATUS` | `"immich http://localhost:2283 /api/server/ping"` | `homecider status`: short name, URL shown, health path (optional) |
| `MOD_ALERT` | `yes` | Alerts job: "`MOD_TITLE` is down" when the `MOD_STATUS` health URL fails twice |
| `MOD_COMPOSE` | `yes` | Module runs containers: OrbStack is installed and the weekly update pulls its images |
| `MOD_RELEASE` | `"immich-app/immich IMMICH_VERSION"` | Weekly update: GitHub repository and version setting; one message per new release |
| `MOD_BACKUP_PATHS` | `"$PHOTOS_DIR"` | Backup: folders to back up, space-separated, even when the module is off |
| `MOD_BACKUP_EXCLUDES` | `"$PHOTOS_DIR/thumbs"` | Backup: folders not to back up (plain paths, no patterns) |
| `MOD_KEPT` | `"$PHOTOS_DIR"` | Uninstall: data folders listed as kept |

`tests/modules.bats` fails when a script outside a module's folder calls `has_module <name>` or uses one of the
module's settings, unless that line is in the test's allow-list. Use a `MOD_*` field instead where one fits.
