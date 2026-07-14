# Setup Guide

Current, metrics-only stack: Prometheus, Grafana, Alertmanager, Blackbox
Exporter, Node Exporter, cAdvisor, and Nginx as a reverse proxy in front of
Grafana. No log aggregation — see [ARCHIVE.md](ARCHIVE.md) for the retired
Loki/MinIO/Promtail setup this replaced.

## Prerequisites

- Docker Engine + Docker Compose plugin
- A host to run the stack on (this doesn't need to live on the machines it
  monitors — it scrapes exporters over the network)

## 1. Clone and configure

```bash
git clone https://github.com/justynlarry/metric-stack.git
cd metric-stack
cp .env.example .env   # then edit with your own admin credentials
```

`.env` holds `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` and
`PROMETHEUS_RETENTION`. It's gitignored — never commit it.

## 2. Start the stack

```bash
docker compose up -d --build
docker compose ps
```

Grafana is reverse-proxied through Nginx; Prometheus, Alertmanager, and
Blackbox are also reachable directly on their default ports (9090, 9093,
9115) if you need to hit them without the proxy.

## 3. Add a scrape target

Targets are file-based service discovery — no restart needed, Prometheus
picks up changes on its own refresh interval.

**A node (node_exporter):** add an entry to
`prometheus/file_sd/prom_nodes.yml`:

```yaml
- targets:
    - <host-ip>:9100
  labels:
    tenant: <tenant-name>
    instance: <display-name>
    environment: production
    role: node
    host: <hostname>
    exporter: node
```

**A website/endpoint (blackbox probe):** add an entry to
`prometheus/file_sd/blackbox_addr.yml`:

```yaml
- targets:
    - https://example.com
  labels:
    tenant: <tenant-name>
    instance: <display-name>
    role: website
    environment: production
```

Both files support multiple tenants side by side — the `tenant` label is
what Grafana's dashboard variable filters on.

## 4. Verify

- Prometheus targets: `http://<host>:9090/targets` — all should show `UP`.
- Grafana: reachable through Nginx, single Prometheus datasource
  pre-provisioned via `grafana/provisioning/datasources/prometheus.yml`.
- Alertmanager: `http://<host>:9093` — routing rules live in
  `prometheus/rules/`.

## Maintenance

- Image tags are pinned to exact versions in `docker-compose.yml` — bump
  deliberately, don't float on `latest`.
- `prometheus.yml` is bind-mounted read-only. If you hand-edit it, a plain
  `docker compose restart prometheus` isn't enough if your editor replaces
  the file via rename instead of in-place write — use
  `docker compose up -d --force-recreate prometheus` (or `down && up`) to
  be sure the new file is picked up.
