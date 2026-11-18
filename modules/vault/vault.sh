#!/bin/sh
# Encrypted vaults: AES-256 sparse-bundle disk images in VAULT_DIR (default ~/Vault, mode 700), for archives that
# should be unreadable while not in use. Closed, they are unreadable even to a process running as you.
#   homecider vault create NAME [SIZE]   new vault (default 100g max; uses only the space of its contents)
#   homecider vault open NAME            mount at /Volumes/NAME (asks for the password)
#   homecider vault close NAME           unmount
#   homecider vault list                 vaults and whether they are open
# The password is never stored: not in the Keychain, not by homecider. Keep it in a password manager.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
: "${VAULT_DIR:=$HC_HOME/Vault}"
img() { echo "$VAULT_DIR/$1.sparsebundle"; }
need_name() { [ -n "${1:-}" ] || die "usage: homecider vault $2 NAME"; case "$1" in *[!A-Za-z0-9_-]*) die "NAME: letters, digits, - and _ only";; esac; }

case "${1:-list}" in
  create)
    need_name "${2:-}" create; size="${3:-100g}"
    [ -e "$(img "$2")" ] && die "$(img "$2") already exists"
    mkdir -p "$VAULT_DIR"; chmod 700 "$VAULT_DIR"
    echo "Save a new password in your password manager first, then copy it from the saved entry."
    hdiutil create -quiet -size "$size" -type SPARSEBUNDLE -fs APFS -encryption AES-256 -volname "$2" "$(img "$2")"
    echo "Now open it once with the password pasted from your password manager, to prove it was saved correctly:"
    if hdiutil attach -quiet "$(img "$2")"; then
      chmod 700 "/Volumes/$2"
      echo "Vault $2 created and open at /Volumes/$2. Copy files in, verify them, then: homecider vault close $2"
    else
      rm -rf "$(img "$2")"
      die "the password did not open the new vault; it was deleted. Check the saved password and run create again."
    fi ;;
  open)
    need_name "${2:-}" open
    [ -e "$(img "$2")" ] || die "no vault $2 in $VAULT_DIR"
    hdiutil attach -quiet "$(img "$2")" && echo "open at /Volumes/$2; close it when done: homecider vault close $2" ;;
  close)
    need_name "${2:-}" close
    hdiutil detach -quiet "/Volumes/$2" && echo "vault $2 closed" ;;
  list)
    for v in "$VAULT_DIR"/*.sparsebundle; do
      [ -e "$v" ] || { echo "no vaults in $VAULT_DIR"; break; }
      n="$(basename "$v" .sparsebundle)"
      printf '%-24s %-8s %s\n' "$n" "$([ -d "/Volumes/$n" ] && echo OPEN || echo closed)" "$(du -sh "$v" | cut -f1)"
    done ;;
  *) sed -n '4,7p' "$0" | sed 's/^# //'; exit 1 ;;
esac
