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

## hyprpm / hy3 landmines (2026-07)

- **Never run hyprpm under sudo** — it root-owns the state store (`/var/cache/hyprpm/<user>`)
  and every later unprivileged run fails with "Failed to write plugin state". Recovery: delete
  the store, `sudo install -d -o $USER -g $USER /var/cache/hyprpm/$USER`, rerun as user.
- **Plugin builds failing with `explicit operator bool` / ranges errors inside hyprland
  headers** = COPR version skew: hyprland was built against an older hyprutils than the
  installed -devel. Fix until the COPR rebuilds: overlay the matching hyprutils version's
  `include/hyprutils` into `/var/cache/hyprpm/<user>/headersRoot/include/` (its -I wins over
  /usr/include; smart pointers are header-only so runtime ABI is unaffected). Note:
  `hyprpm update -f` rebuilds headersRoot and wipes the overlay.
- **hy3 manifest pins may lag hyprland patch releases** — no pin for the running hash means
  hyprpm silently builds git-chasing `main`. Pin explicitly:
  `hyprpm add https://github.com/outfoxxed/hy3 <rev-from-hyprpm.toml-for-your-0.XX>`

## Conventions
- Snapshots: snapper on `root` + `home`, `python3-dnf-plugin-snapper` for auto pre/post-dnf.
  Take a named baseline after install: `sudo snapper -c root create -d "clean baseline"`.
- Hyprland: COPR `lionheartp/Hyprland`. ghostty: COPR `scottames/ghostty`. Node: `n`, not nvm.
- Long dnf commands: run from a script file — terminal paste-wrap splits them into garbage.
