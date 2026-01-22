# Client Node Onboarding Guide

**Metrics & Log Collection (Prometheus + Promtail)**

## Overview

This process installs and configures monitoring agents on a client-owned Linux server.
Once completed, the node will:

* Export system metrics via **node_exporter**
* Ship logs via **Promtail**
* Appear automatically in centralized dashboards
* Be logically isolated using a **tenant label**

---

## 1. Download the Installation Script (Client Server)

On the **client machine**, download the appropriate script:

* **`prometheus-promtail-exporter.sh`**
  → Use this if `node_exporter` is **not already installed**

* **`promtail-exporter.sh`**
  → Use this if `node_exporter` is **already running**

> ⚠️ These scripts assume:
>
> * systemd is available
> * outbound HTTPS access is allowed
> * ports `9100` (node_exporter) and `9080` (promtail) are open locally

---

## 2. Run the Script on the Client Server

```bash
chmod +x <script-name>.sh
sudo ./<script-name>.sh
```

### During Execution

You will be prompted to enter:

* **Client Name**
  → This value becomes the **tenant label** used across all metrics and logs
  → Example: `Client-A`

### What the Script Does

* Installs required binaries (if missing)
* Creates systemd services for:

  * `node_exporter`
  * `promtail`
* Configures Promtail with:

  * tenant label
  * host metadata
  * log paths
* Enables and starts all services

---

## 3. Verify Services on the Client Server

### 3.1 Verify node_exporter Metrics

```bash
curl http://localhost:9100/metrics | head
```

✅ Expected:

* Prometheus-style metric output
* `go_gc_duration_seconds`, `go_goroutines`, etc.

> A `curl: (23) Failure writing output to destination` message is normal when piping large output to `head`.

---

### 3.2 Verify Promtail Metrics

```bash
curl http://localhost:9080/metrics | head
```

✅ Expected:

* Promtail internal metrics
* No connection or parsing errors

---

### 3.3 Verify node_exporter Service

```bash
sudo systemctl status node_exporter.service
```

✅ Expected:

* `Active: active (running)`
* Listening on port `9100`
* No crash loops or permission errors

---

### 3.4 Verify Promtail Service

```bash
sudo systemctl status promtail.service
```

✅ Expected:

* `Active: active (running)`
* Listening on port `9080`
* Log lines similar to:

```text
Adding target "/var/log/syslog"
tenant="Client-A"
```

This confirms logs are being labeled and shipped correctly.

---

## 4. Register the Node on the Monitoring Server (Metrics)

On the **central monitoring server**, edit:

```bash
/home/monitor/prometheus/file_sd/prom_nodes.yml
```

Add a new entry:

```yaml
- targets:
    - <CLIENT_IP>:9100
  labels:
    tenant: <client_name>          # Must match script input
    instance: <display_name>
    environment: production        # Adjust if needed
    role: client
    host: <server_hostname>
    exporter: node
```

> 🔁 Prometheus will automatically reload this via file-based service discovery.

---

## 5. Register Website / Endpoint Monitoring (Optional)

If the client has a public service or website to probe, edit:

```bash
/home/monitor/prometheus/file_sd/blackbox_addr.yml
```

Add:

```yaml
- targets:
    - <web_address_or_ip>
  labels:
    tenant: <client_name>
    instance: <display_name>
    role: <website_job>
    environment: production
```

Examples for `role`:

* `http`
* `https`
* `api`
* `landing-page`

---

## 6. Logs (No Monitoring Server Changes Required)

Promtail ships logs **directly** to the centralized Loki instance.

✅ No configuration changes are required on the monitoring server
✅ Logs will automatically appear under the correct tenant
✅ Dashboards and alerts will populate without manual intervention

---

## 7. Post-Onboarding Validation (Internal)

After ~60 seconds, confirm:

* Node appears in Prometheus targets
* Metrics populate in Grafana under the correct tenant
* Logs appear in Loki with:

  * `tenant=<client_name>`
  * `host=<hostname>`

---

## Final Notes (Operational Reality)

* Client onboarding is **agent-only** — no invasive access required
* All isolation is label-based (multi-tenant safe)
* Removal is clean:

  * disable services
  * delete config entries
* This workflow scales cleanly from **1 → 100+ nodes**

---

If you want, next logical upgrades would be:

* a **“Client Prerequisites”** section
* a **one-command verification script**
* or a **sanitized client-facing PDF version**

Just say the word.
