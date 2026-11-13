# Tailscale Exit Node — Static Egress IP

Small Hetzner VMs running Tailscale as exit nodes, used to give the
laptop a stable public IP for vendor allowlists (currently Salesforce).
Two nodes: `egress-pdx` (North America) and `egress-nue` (Europe, added
2026-11 for working from Italy; Hetzner has no Italian location).

Temporary until Vercel ships first-class static-egress for non-prod
traffic. When that lands, decommission everything below.

## Topology

```
Calgary laptop ──tailnet──► egress-pdx (Hetzner CPX11, Hillsboro OR)
                              ↓ public IPv4
                              5.78.100.55
                              ↓
                         vercel.my.salesforce.com
                         (Hyperforce / AWS us-west-2)
```

- Calgary → Hillsboro: ~25ms
- Hillsboro → SFDC us-west-2: ~5ms
- One-way total ≈ what direct Calgary→Oregon is anyway.

From Europe, use `egress-nue` instead (Italy → Nuremberg ~15ms); routing
Italy → Oregon → SFDC would cross the Atlantic twice.

```
Italy laptop ──tailnet──► egress-nue (Hetzner CX23, Nuremberg DE)
                            ↓ public IPv4
                            116.203.85.174
```

## Provisioned resources

- **Hetzner Cloud project**: Default
- **Server**: `egress-pdx` (CPX11, Ubuntu 24.04, Hillsboro/us-west)
- **Primary IPv4**: `5.78.100.55` — delete-protected, auto-delete OFF
- **Primary IPv6**: `2a01:4ff:1f0:ddab::/64`
- **Tailscale node**: `egress-pdx` (key expiry disabled)
- **Note**: IPv6 default route removed (2026-09) because some v6
  destinations black-hole past Hetzner Hillsboro; see netplan backup
  `/root/50-cloud-init.yaml.bak-20260904` on the box.

- **Server**: `egress-nue` (CX23, Ubuntu 24.04, Nuremberg/nbg1, label
  `role=egress`). CPX11 is deprecated in EU locations; CX23 is the
  cheapest current x86 type (~$6.49/mo + $0.60 IPv4).
- **Primary IPv4**: `116.203.85.174` (`egress-nue-v4`) — delete-protected,
  auto-delete OFF
- **Primary IPv6**: `2a01:4f8:1c16:eed2::/64` (v6 egress verified working)
- **Tailscale node**: `egress-nue` (key expiry disabled)

If a VM is ever rebuilt, reattach the same Primary IPv4 so the SFDC
allowlist stays valid.

## Day-to-day

```bash
# turn exit node on (route all egress through Hetzner)
tailscale set --exit-node=egress-pdx --exit-node-allow-lan-access

# from Europe
tailscale set --exit-node=egress-nue --exit-node-allow-lan-access

# verify
curl -4 ifconfig.me   # → 5.78.100.55 (pdx) or 116.203.85.174 (nue)

# turn it off (back to home ISP)
tailscale set --exit-node=
```

`--exit-node-allow-lan-access` keeps the home printer/AirPlay reachable
while exit node is on.

SSH to the box (no public SSH; tailnet only):

```bash
tailscale ssh root@egress-pdx   # or root@egress-nue
```

Unattended-upgrades installs security updates but does not reboot, so
kernels pile up unused (egress-pdx ran 187 days on its original kernel).
Every few months: `apt full-upgrade`, `autoremove --purge`, reboot.
Do it while the laptop is on the *other* exit node (or none).

## What's allowlisted at SFDC

`5.78.100.55` and `116.203.85.174` are added to:

- Setup → Network Access (org-level trusted IPs)
- Connected App / External Client App IP restrictions (any integration
  using static IPs)
- The local-scripts service account's profile login IP ranges (JWT
  bearer grant from `scripts/op-dev.sh GTM_WORKFLOWS`)

Verified 2026-11-13: JWT grant + SOQL query succeed through egress-nue.

## Rebuild from scratch

If the VM is ever lost, here's the exact recreate path:

egress-nue was built with cloud-init doing steps 2-3
(`hcloud server create --user-data-from-file ...`, template below), then
steps 4-6 by hand.

```bash
# 1. Provision Hetzner (CPX11 in hil, CX23 in nbg1), Ubuntu 24.04,
#    attach existing Primary IPv4, add SSH key vieko@phyrexia.

# 2. Harden
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo ufw allow 22/tcp                # remove after step 4 verifies
sudo ufw allow 41641/udp
sudo ufw --force enable

# 3. Tailscale + IP forwarding
curl -fsSL https://tailscale.com/install.sh | sh
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# 4. Bring up as exit node (opens browser auth URL)
sudo tailscale up --advertise-exit-node --ssh --hostname=egress-pdx

# 5. In Tailscale admin console:
#    - Machines → egress-pdx → Edit route settings → enable "Use as exit node"
#    - Machines → egress-pdx → Disable key expiry

# 6. Lock down public SSH after verifying `tailscale ssh` works
sudo ufw delete allow 22/tcp
```

cloud-init template for steps 2-3:

```yaml
#cloud-config
package_update: true
package_upgrade: true
packages: [unattended-upgrades, ufw]
write_files:
  - path: /etc/sysctl.d/99-tailscale.conf
    content: |
      net.ipv4.ip_forward = 1
      net.ipv6.conf.all.forwarding = 1
  - path: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
runcmd:
  - sysctl -p /etc/sysctl.d/99-tailscale.conf
  - ufw allow 22/tcp
  - ufw allow 41641/udp
  - ufw --force enable
  - curl -fsSL https://tailscale.com/install.sh | sh
```

## Teardown

```bash
hcloud server delete egress-pdx        # or egress-nue
# In Tailscale admin: Machines → <node> → delete
# In Hetzner: optionally release the Primary IPv4 (only if SFDC
#   allowlist no longer references it)
```

## Why Hetzner CPX11 specifically

- CX line is EU-only — not available in Hillsboro.
- CCX is dedicated-vCPU (~$14/mo), overkill for packet forwarding.
- CPX11 (~$4.59/mo) gives 2 shared vCPU / 2GB RAM / 20TB egress.
  Exit node does basically zero CPU work; this is the cheapest
  capable tier.
