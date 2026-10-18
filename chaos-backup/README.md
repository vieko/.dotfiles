# chaos-backup

Nightly restic backup of the irreplaceable set on **chaos** (`~/dev`, `~/.dotfiles`,
`~/Documents`, `~/backups`, `~/Pictures`) to the local `/mnt/backup` disk
(fstab: `UUID=... /mnt/backup btrfs compress=zstd:1,nofail`). Runs as root at
03:30 via `chaos-backup.timer`; `restic forget --prune` (7d/4w/6m) and a 2 %
read-data check follow each successful run.

Install by copy, not stow (see `install.sh` header for why):

```bash
sudo ~/.dotfiles/chaos-backup/install.sh
```

Then, **by hand, from the vault**: `/root/.restic-pass` (mode 600, the repo
passphrase, no trailing newline needed). `install.sh` tells you if it is
missing, still the placeholder, or does not open the repo.

Failure path: `chaos-backup.service.d/10-onfailure.conf` sets
`OnFailure=chaos-backup-failed.service`, which Telegrams the last error lines
using the `TELEGRAM_*` vars grepped out of `/home/vieko/.secrets` (the same
bot the app-cacahuate guards use). Test it: `sudo systemctl start
chaos-backup-failed.service`.

Known gotchas baked into the script:
- the unit has no `$HOME`, so `RESTIC_CACHE_DIR=/var/cache/restic` is set explicitly
  (restic otherwise aborts with "unable to locate cache directory");
- `source ~/.secrets` under `set -u` dies in a systemd environment; the hook
  `eval`s only the two exported lines it needs.

Running root commands from an agent session on chaos: `SUDO_ASKPASS=~/.scripts/zenity-askpass sudo -A <cmd>`
pops a desktop password prompt (no tty needed).
