# backup module

Nightly [restic](https://restic.net) backup to an S3-compatible bucket. Data is encrypted on the Mac before upload
with `RESTIC_PASSWORD`; the bucket provider never sees it. Add `backup` to `MODULES`.

## What is backed up

`PHOTOS_DIR` (photos and Immich's daily database dumps in `backups/`), `DATA_DIR`, `DOWNLOADS_CONFIG_DIR`,
homecider's config and secrets, `VAULT_DIR` (default `~/Vault`, encrypted images are backed up as they are) and
`BACKUP_EXTRA_PATHS`. Skipped: Immich thumbnails and transcoded videos, the live Postgres directory, logs, caches,
and media (it can be downloaded again).

Schedule: every night at `BACKUP_HOUR`:30. On Sundays `forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12
--prune`; on the 1st of the month `check --read-data-subset 5%`. A failed run, or no successful run for 36 hours,
sends an ntfy alert.

## Backblaze B2 setup (about 10 minutes)

1. Create a B2 account; turn on two-factor login.
2. Create a **private** bucket with **default encryption** on. Object Lock is not needed.
3. Bucket lifecycle settings: **Custom**, "days till hide" empty, **"days till delete" 30**. Deleted or
   overwritten files stay recoverable for 30 days after they are hidden.
4. Create an application key **restricted to that bucket and without `deleteFiles`**, so a compromised Mac can
   hide backups but not erase them. The web UI cannot leave out `deleteFiles`; use the B2 CLI once:
   ```sh
   brew install b2-tools
   b2 account authorize                       # master key, interactively
   b2 key create --bucket <bucket> homecider listBuckets,listFiles,readFiles,writeFiles,shareFiles
   b2 account clear
   ```
5. On the Mac:
   ```sh
   homecider secret set AWS_ACCESS_KEY_ID        # the key ID from step 4
   homecider secret set AWS_SECRET_ACCESS_KEY    # the application key from step 4
   homecider secret set RESTIC_PASSWORD          # a long random password; also keep it in a password manager
   ```
   In `homecider.env`: `BACKUP_REPOSITORY=s3:https://s3.<region>.backblazeb2.com/<bucket>` and add `backup` to
   `MODULES`. Then `homecider apply`, `homecider backup now`, `homecider backup restore-test`.

**Without `RESTIC_PASSWORD` the backup cannot be restored.** Store it outside the Mac.

Note: with restic's S3 backend, deletes during `prune` become B2 "hide" markers, which the lifecycle rule removes
after 30 days. Whether B2 allows S3 deletes (hides) for a key without `deleteFiles` must be confirmed on first
setup: if the weekly prune fails with an access error, add `deleteFiles` to the key and rely on the lifecycle rule.

## Restore

```sh
homecider backup snapshots
. modules/backup/env.sh   # or export RESTIC_REPOSITORY / RESTIC_PASSWORD / AWS_* yourself
restic restore latest --target /tmp/restore --include "$HOME/Photos/immich/library"
```
For Immich, restore `PHOTOS_DIR`, then follow Immich's database restore guide using the newest dump in `backups/`.
