# CLAUDE.md — monitor-stack

## What this system is

`monitor-stack` is a standalone Debian VM running a metrics-only Prometheus /
Grafana / Alertmanager stack via Docker Compose. It's Justyn's personal
**meta-monitor** — external visibility into Irin Observability's production
infrastructure, plus full monitoring of his homelab and the RBI project.

It intentionally tracks metrics that don't belong in the Irin SaaS product
itself — CPU/drive temperature, SMART/drive health, and other hardware-level
signals that are operator concerns, not customer-facing monitoring data.

This stack predates Irin's dedicated production hardware and was originally
a multi-tenant prototype. As of the June 2026 overhaul, it's been reduced to
exactly what its current role needs: metrics only, three tenants, six
dashboards. Log aggregation was deliberately removed — see "Architecture
decisions" below.

---

## Host

| | |
|---|---|
| Hostname | `monitor-stack` |
| OS | Debian |
| User | `stack-user` |
| Working dir | `~/monitor` |
| NIC `ens18` | `192.168.0.36/24`, gateway `192.168.0.1` (homelab LAN) |
| NIC `ens19` | `192.168.10.106/24`, no gateway (directly attached to Irin production LAN) |

---

## Architecture decisions (settled — do not revisit without explicit direction)

**Metrics-only. No log aggregation on this stack.** Loki, MinIO, and Promtail
were fully removed in the June 2026 overhaul. This was a deliberate tradeoff:
hosts covered by Irin's own managed Alloy (see below) have their logs there;
everything else has none. This is accepted, not a gap to fix.

**Irin's managed Alloy is off-limits — hard rule.** A subset of the fleet
(confirmed: pbsBlack, pbsRed, pveBlack, pveGreen, pveRed; likely also
irin-svr01/02/dev01 and mtg-webserver, unconfirmed due to permissions) runs
Grafana Alloy under Irin Observability's own centrally-managed onboarding
pipeline — the same system used for real paying tenants. Configs live at
`/etc/alloy/config.alloy`, wrapped in `### IRIN_BEGIN ### / ### IRIN_END ###`
blocks, and authenticate to `monitor.irinobservability.com` /
`replica.irinobservability.com` using embedded Cloudflare Access service
tokens.

**Never read, edit, or otherwise touch `/etc/alloy/config.alloy` on any host,
for any reason, from this stack.** It is not this stack's system to manage.
A mistake there is a mistake in Irin's production security boundary, not
just monitor-stack's. If a task seems to require touching it, stop and ask
rather than proceeding.

**Homelab is dogfooded as a real Irin tenant.** The Proxmox nodes
(pveBlack/Green/Red) are intentionally onboarded into Irin's actual
commercial backend under `tenant: phoenix-lab` — this is deliberate
self-testing of the product, not leftover test data.

**Metrics collection is plain exporters, not Alloy, from this stack's side.**
Every host in the tenant tables below is scraped directly via
`node_exporter` (and `smartctl_exporter` on physical hardware), independent
of whatever Alloy is or isn't doing on that host for Irin's own purposes.

---

## Directory structure

```
monitor/
├── CLIENT_ONBOARDING.md            # Legacy — from the old client-a/b/c prototype model
├── GRAFANA_DASHBOARDS.md
├── README.md
├── alertmanager/
│   └── config.yml                  # Slack removed; no active receiver currently configured
├── blackbox/
│   └── blackbox.yml                # 4 endpoint probes — see Blackbox targets below
├── docker-compose.yml              # prometheus, alertmanager, grafana, blackbox, nginx, cadvisor, node-exporter
├── grafana/
│   └── provisioning/
│       ├── dashboards/             # Intentionally empty — dashboards are edited live, not file-provisioned
│       └── datasources/
│           └── prometheus.yml      # Prometheus only — Loki datasource removed
├── nginx/
│   ├── Dockerfile
│   ├── conf.d/grafana.conf
│   └── nginx.conf
├── prometheus/
│   ├── file_sd/
│   │   ├── blackbox_addr.yml
│   │   ├── cpu_temp_exporter.yml
│   │   ├── docker-monitor.yml
│   │   ├── internal_monitoring.yml
│   │   ├── prom_nodes.yml          # Primary target inventory — see tenant tables below
│   │   ├── proxmox.yml             # pveBlack active; pveRed/pveGreen commented
│   │   │                          # out on purpose - see note below
│   │   └── smartctl_exporter.yml   # LAN IPs only, standardized
│   ├── prometheus.yml              # No federation job — direct scrape only
│   └── rules/
│       ├── alerts.yml              # NginxDown present but inert — no exporter; commented as such
│       ├── platform_alerts.yml
│       └── slis.yml
└── scripts/
    └── generate-loki-config.sh     # Dead — Loki removed; candidate for deletion
```

Note: `LOKI_CONFIG_MGT_PASSWORD_ROTATION.md`, `loki/`, `minio/`, `promtail/`,
and `alloy_nodes.yml` were deleted entirely in the overhaul — they documented
or configured systems that no longer exist here.

**Known stale file:** `scripts/generate-loki-config.sh` was not cleaned up
during the Loki removal pass — it's dead code. Safe to delete whenever
someone's next in this directory.

---

## Docker Compose services

- `prometheus` — metrics, file-based service discovery (`file_sd/`)
- `alertmanager` — alert routing (no active receiver — Slack removed, nothing
  replaced it yet)
- `grafana` — dashboards (live-edited, not file-provisioned), single
  Prometheus datasource
- `blackbox` — synthetic HTTP probing for the 4 tracked endpoints
- `cadvisor` — container metrics; runs on the `monitor_monitoring` network
  via Compose only (a competing standalone `cadvisor.service` systemd unit
  was found and disabled during the overhaul — don't recreate it)
- `node-exporter` — monitor-stack's own host metrics
- `nginx` — reverse proxy in front of Grafana

All image tags are pinned to exact running versions (see Pinned versions
below) — no floating `latest` tags.

---

## Tenant / target model

### Tenant: Irin
| Host | IP | Notes |
|---|---|---|
| irin-svr01 | 192.168.10.120 | node_exporter + smartctl |
| irin-svr02 | 192.168.10.130 | node_exporter + smartctl |
| irin-dev01 | 192.168.10.110 | node_exporter + smartctl |
| mtg-webserver | 192.168.0.120 | node_exporter only (VM) |

### Tenant: Phoenix-Lab
| Host | IP | Notes |
|---|---|---|
| nas01 | 192.168.0.56 | |
| shire | 192.168.0.195 | |
| monitor-stack | 192.168.0.36 | self-monitored |
| pbsBlack | 192.168.0.219 | |
| echoBase | 192.168.0.240 | |
| Heimdall | 192.168.0.137 | |
| pbsGreen | 192.168.0.222 | |
| pbsRed | 192.168.0.220 and 192.168.10.105 | confirmed dual-homed |
| pveblack | 192.168.0.217 | also an Irin tenant (dogfooding, see above) |
| pvegreen | 192.168.0.221 | also an Irin tenant (dogfooding, see above) |
| pvered | 192.168.0.218 | also an Irin tenant (dogfooding, see above) |

**Mandalore (192.168.0.168) is decommissioned** — it was the original
predecessor to this stack. Removed from all config and dashboards. Do not
re-add without explicit direction.

**proxmox.yml only scrapes pveBlack — pveRed and pveGreen are deliberately
commented out.** These three nodes are a Proxmox cluster, and the `/pve`
exporter endpoint reports metrics for the *entire cluster* from whichever
node you scrape, not just that one node. With all three configured, every
node's metrics showed up three times (once per scrape target). Justyn
commented out pveRed and pveGreen himself, leaving pveBlack as the single
scrape point for the whole cluster's Proxmox metrics. Don't uncomment
those two to "complete the coverage" — that reintroduces the triplication.
(smartctl_exporter.yml and cpu_temp_exporter.yml are unaffected by this —
those exporters run per-node and genuinely need all three configured.)

### Tenant: RBI
| Host | IP | Notes |
|---|---|---|
| Ledger-dev01 | 192.168.0.126 | node_exporter |
| rbi-hail01 | 192.168.0.128 | node_exporter |

---

## Blackbox targets (exactly these 4)

- `www.jlarrymortgages.com`
- `www.irinobservability.com`
- `monitor.irinobservability.com`
- `replica.irinobservability.com`

`api.irinobservability.com` was deliberately removed — it 404s at root with
no health-check path, and adding one was declined for now. Don't re-add it
without confirming Irin's API team has a proper endpoint to point at.

---

## Dashboards (exactly 6, live-edited in Grafana, no file provisioning)

1. **System Health** — tenant-variable, all three tenants
2. **Internal Monitoring Stack – Docker Health** — tenant-variable, cadvisor-based
3. **Monitor Stack – Internal** — monitor-stack only, no Loki panels (removed)
4. **Phoenix Homelab Health** — despite the name, this covers both
   `Phoenix-Lab` and `Irin` tenants. Justyn's intent is "all physical
   servers I own," not one tenant specifically — it's really a **Physical
   Machine State** dashboard (CPU/drive temp, SMART health, disk/memory)
   that happens to span both tenant labels because the same physical boxes
   (pveBlack/Green/Red) carry both. **Layout is frozen** — changes here
   should be additive links only, never structural, unless explicitly
   requested
5. **Alert-Manager** — tenant-variable; other dashboards link to this one
6. **Website/Endpoint Status** — the 4 blackbox targets above

Note: the tenant-variable dropdown may still show stale `client-a`/`client-b`
options until that historical Prometheus data ages out past the retention
window — this is expected, not a bug to fix.

---

## Pinned image versions (as of 2026-07-01)

| Service | Version |
|---|---|
| Prometheus | v3.13.0 |
| Grafana | 13.1.0 |
| Alertmanager | v0.33.0 |
| blackbox-exporter | v0.28.0 |
| node-exporter | v1.11.1 |
| cadvisor | pinned by digest (v0.60.3, ghcr.io/google/cadvisor) |
| nginx | 1.31.2-alpine |

When bumping any of these, pin to an exact version — never float on
`latest`.

---

## Known gaps (accepted, not bugs)

- **No log aggregation** outside hosts covered by Irin's own Alloy (see
  Architecture decisions). Not being revisited.
- **NginxDown alert is inert** — no `nginx-prometheus-exporter` deployed, so
  it has no data and will never fire. Commented in `alerts.yml` accordingly.
  Accepted; add the exporter later only if this becomes a real priority.
- **`prometheus.yml` is a single-file bind mount.** Edits that replace the
  file via rename (most editors, including Claude's file-edit tools) won't
  reach the running container until it's recreated — `docker compose
  restart` isn't enough; use `docker compose up -d --force-recreate` (or
  `down && up`) after hand-editing this specific file.

---

## Conventions to preserve (from Irin production practice)

- Audit/inventory passes should be **read-only first** — confirm current
  state before changing anything, don't trust prior docs or memory.
- Pin all Docker image tags to exact versions.
- Commit config/IP/credential changes to git with a clear message — don't
  hand-edit silently in the working tree.
- Never touch `/etc/alloy/config.alloy` on any host from this stack (see
  Architecture decisions).
