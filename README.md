# Metric Stack

Self-hosted, multi-tenant Prometheus/Grafana/Alertmanager monitoring stack
running on Docker Compose. Started as a combined metrics-and-logs stack;
as of a 2026 overhaul it's metrics-only — see [docs/ARCHIVE.md](docs/ARCHIVE.md)
for the retired Loki/MinIO/Promtail log-aggregation setup this replaced.

## Architecture

- **Prometheus** — metrics collection, file-based service discovery
  (no hardcoded target lists — add a host or endpoint by editing a file)
- **Grafana** — dashboards, single Prometheus datasource
- **Alertmanager** — alert routing
- **Blackbox Exporter** — synthetic HTTP probing for tracked endpoints
- **Node Exporter / cAdvisor** — host and container metrics
- **Nginx** — reverse proxy in front of Grafana

Targets are tagged with a `tenant` label so a single stack can monitor
multiple independent environments (e.g. homelab hardware alongside
production servers) with dashboards filterable per tenant.

## Quick start

```bash
git clone https://github.com/justynlarry/metric-stack.git
cd metric-stack
cp .env.example .env   # set your own admin credentials
docker compose up -d --build
```

Full walkthrough — directory layout, adding scrape targets, verification
steps, maintenance notes — is in [docs/SETUP.md](docs/SETUP.md).

## Repo layout

```
.
├── docker-compose.yml
├── prometheus/          # scrape config, alerting rules, file_sd targets
├── grafana/              # datasource provisioning
├── alertmanager/         # config.yml is gitignored (user-provided)
├── blackbox/             # HTTP probe module config
├── nginx/                # reverse proxy in front of Grafana
├── docs/
│   ├── SETUP.md          # full setup walkthrough
│   └── ARCHIVE.md        # retired Loki/MinIO/Promtail architecture
└── GRAFANA_DASHBOARDS.md # dashboard-building reference
```

## Status

Active. Metrics-only as of the 2026 overhaul; dashboards are live-edited
in Grafana rather than file-provisioned.
