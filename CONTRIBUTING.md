# Contributing to HomeCider

Thanks for helping. HomeCider is maintained by one person in spare time, so small, focused changes are easiest
to review.

## Reporting a problem

Open an issue with:

- Mac model and chip (e.g. Mac mini M2), macOS version (`sw_vers -productVersion`)
- Enabled modules and any non-default settings from `homecider.env` (leave out paths you consider private)
- Output of `bin/homecider doctor` and `bin/homecider status`
- The failing command and its output; logs from `~/Library/Logs/homecider/`

**Never post** `secrets.env`, `.env` files, API keys, passwords, your ntfy topic or VPN keys.
Security issues: do not open a public issue; use GitHub's private vulnerability reporting on this repository.

Issues asking which indexers, trackers or download sources to use are closed without an answer. HomeCider ships
none and does not recommend any.

## Testing on your Mac

Reports from Macs other than the MacBook Air M1 it was built on are especially useful:

1. Fresh install following the README, on a Mac you can reset.
2. Run `bin/homecider apply` twice: the second run must finish without errors and without restarting Jellyfin.
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

## Adding a module

A module is a folder in `modules/` with `root.sh` and/or `user.sh`, enabled by name in `MODULES`. Before writing
one, open an issue describing what it installs, what it changes on the Mac, and how it stays off the internet.
