# Tailscale Exit Node — Static Egress IP

A small Hetzner VM running Tailscale as an exit node, used to give the
laptop a stable public IP for vendor allowlists (currently Salesforce).

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

## Provisioned resources

- **Hetzner Cloud project**: Default
- **Server**: `egress-pdx` (CPX11, Ubuntu 24.04, Hillsboro/us-west)
- **Primary IPv4**: `5.78.100.55` — delete-protected, auto-delete OFF
- **Primary IPv6**: `2a01:4ff:1f0:ddab::/64`
- **Tailscale node**: `egress-pdx` (key expiry disabled)

If the VM is ever rebuilt, reattach the same Primary IPv4 so the SFDC
allowlist stays valid.

## Day-to-day

```bash
# turn exit node on (route all egress through Hetzner)
tailscale set --exit-node=egress-pdx --exit-node-allow-lan-access

# verify
curl -4 ifconfig.me   # → 5.78.100.55

# turn it off (back to home ISP)
tailscale set --exit-node=
```

`--exit-node-allow-lan-access` keeps the home printer/AirPlay reachable
while exit node is on.

SSH to the box (no public SSH; tailnet only):

```bash
tailscale ssh root@egress-pdx
```

## What's allowlisted at SFDC

`5.78.100.55` is added to:

- Setup → Network Access (org-level trusted IPs)
- Connected App / External Client App IP restrictions (any integration
  using static IPs)

## Rebuild from scratch

If the VM is ever lost, here's the exact recreate path:

```bash
# 1. Provision Hetzner CPX11 in us-west (Hillsboro), Ubuntu 24.04,
#    attach existing Primary IPv4, add SSH key vieko-mbp.

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

## Teardown

```bash
hcloud server delete egress-pdx
# In Tailscale admin: Machines → egress-pdx → delete
# In Hetzner: optionally release the Primary IPv4 (only if SFDC
#   allowlist no longer references it)
```

## Why Hetzner CPX11 specifically

- CX line is EU-only — not available in Hillsboro.
- CCX is dedicated-vCPU (~$14/mo), overkill for packet forwarding.
- CPX11 (~$4.59/mo) gives 2 shared vCPU / 2GB RAM / 20TB egress.
  Exit node does basically zero CPU work; this is the cheapest
  capable tier.
