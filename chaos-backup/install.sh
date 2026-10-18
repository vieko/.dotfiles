#!/bin/bash
# Install the chaos restic nightly (unit, timer, failure hook, excludes) by COPY.
# Not stowed: PID 1 execs /usr/local/bin/chaos-backup as root, and SELinux will
# not let it run a user_home_t file behind a symlink into ~/.dotfiles.
# Idempotent. Run as root: sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

install -m 755 usr/local/bin/chaos-backup usr/local/bin/chaos-backup-failed /usr/local/bin/
install -d -m 755 /etc/restic /etc/systemd/system/chaos-backup.service.d
install -m 644 etc/restic/excludes.txt /etc/restic/excludes.txt
install -m 644 etc/systemd/system/chaos-backup.service etc/systemd/system/chaos-backup.timer \
               etc/systemd/system/chaos-backup-failed.service /etc/systemd/system/
install -m 644 etc/systemd/system/chaos-backup.service.d/10-onfailure.conf \
               /etc/systemd/system/chaos-backup.service.d/
install -d -m 700 /var/cache/restic
systemctl daemon-reload
systemctl enable --now chaos-backup.timer

# The passphrase is the one thing this repo cannot supply. From 2026-07-07 to
# 2026-10-18 the file held the literal word PASSPHRASE and every run failed
# silently (104 nights). Refuse to look healthy if that is still the case.
if [ ! -s /root/.restic-pass ]; then
  echo "!! /root/.restic-pass is missing. Create it (chmod 600) with the repo passphrase from the vault."
elif grep -qx 'PASSPHRASE' /root/.restic-pass; then
  echo "!! /root/.restic-pass still holds the placeholder. Replace it with the real passphrase."
elif ! restic -r /mnt/backup/restic --password-file /root/.restic-pass cat config >/dev/null 2>&1; then
  echo "!! /root/.restic-pass does not open /mnt/backup/restic (wrong passphrase, or repo not initialised / not mounted)."
else
  echo "ok: passphrase opens the repository"
fi
systemctl list-timers chaos-backup.timer --no-pager
