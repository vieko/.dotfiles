# chaos: Fedora 44 setup notes

**BLUF: `noapic` or it won't boot. Mount disks by LABEL/UUID, never `/dev/nvmeXn1`.
Repos + packages: `sudo bash scripts/.scripts/fedora-fresh-install.sh`.**

## Boot (X570 AORUS MASTER)
- `noapic` is required — without it: `No irq handler for vector` flood, no boot.
- Lives in `GRUB_CMDLINE_LINUX` so new kernels inherit it. Verify after kernel updates:
  `sudo sh -c 'grep -h options /boot/loader/entries/*.conf'`

## Disks
- Identical NVMes shuffle device names every boot. Identify: `lsblk -o NAME,SERIAL`.
  fstab by `LABEL=` or `UUID=` only.

## GPU (Navi 32)
- Black screen right after backlight = missing amdgpu firmware (`gc_11_0_*.bin`, ships in `linux-firmware`).

## Conventions
- Snapshots: snapper on `root` + `home`, `python3-dnf-plugin-snapper` for auto pre/post-dnf.
  Take a named baseline after install: `sudo snapper -c root create -d "clean baseline"`.
- Hyprland: COPR `lionheartp/Hyprland`. ghostty: COPR `scottames/ghostty`. Node: `n`, not nvm.
- Long dnf commands: run from a script file — terminal paste-wrap splits them into garbage.
