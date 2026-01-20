# Grafana Dashboard Configuration Guide

Complete guide for building production-ready Grafana dashboards for your monitoring stack.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Dashboard Variables Setup](#dashboard-variables-setup)
- [Dashboard 1: Client System Health](#dashboard-1-client-system-health)
- [Dashboard 2: Client Website/Endpoint Status](#dashboard-2-client-websiteendpoint-status)
- [Dashboard 3: Alert History & Incident Log](#dashboard-3-alert-history--incident-log)
- [Dashboard 4: Internal Monitoring Stack Health](#dashboard-4-internal-monitoring-stack-health)
- [Dashboard 5: Log Explorer](#dashboard-5-log-explorer)
- [Launch Readiness Checklist](#launch-readiness-checklist)

---

## Prerequisites

Before creating dashboards, ensure:
- ✅ Your monitoring stack is running (`docker-compose ps` shows all services up)
- ✅ Prometheus is scraping targets successfully (check `http://your-ip:9090/targets`)
- ✅ Loki is receiving logs (check `http://your-ip:3100/ready`)
- ✅ Grafana data sources are configured (Prometheus and Loki in Grafana UI)
- ✅ At least one client server has node_exporter and promtail running

---

## Dashboard Variables Setup

**IMPORTANT:** Create these variables FIRST before building any dashboards. They enable filtering across all panels.

### How to Create Variables
1. Open Grafana
2. Create a new dashboard (or open existing)
3. Click ⚙️ **Dashboard Settings** (gear icon, top right)
4. Click **Variables** in left sidebar
5. Click **Add variable** (or **New variable**)

---

### Variable 1: Client Selector

Allows users to select which tenant/client to view.

| Setting | Value |
|---------|-------|
| **Variable type** | Query |
| **Name** | `client` |
| **Label** | Client |
| **Description** | Select client to view |
| **Show on dashboard** | Label and value |

**Query Options:**

| Setting | Value |
|---------|-------|
| **Data source** | Prometheus |
| **Query type** | Label values |
| **Label** | `tenant` |
| **Metric** | `up` |
| **Refresh** | On time range change |

**Selection Options:**

| Setting | Value |
|---------|-------|
| **Multi-value** | ☐ Unchecked |
| **Include All option** | ☑ Checked |
| **Custom all value** | `.*` |

**Sort:** Alphabetical (asc)

Click **Run query** to verify, then **Apply**.

---

### Variable 2: Log Job Selector (For Log Explorer)

Allows filtering logs by job type (syslog, auth, nginx, etc.).

| Setting | Value |
|---------|-------|
| **Variable type** | Query |
| **Name** | `job` |
| **Label** | Log Source |
| **Description** | Select log type |
| **Show on dashboard** | Label and value |

**Query Options:**

| Setting | Value |
|---------|-------|
| **Data source** | Loki |
| **Query type** | Label values |
| **Stream selector** | `{tenant="$client"}` |
| **Label** | `job` |
| **Refresh** | On time range change |

**Selection Options:**

| Setting | Value |
|---------|-------|
| **Multi-value** | ☐ Unchecked |
| **Include All option** | ☑ Checked |
| **Custom all value** | `.*` |

**Sort:** Alphabetical (asc)

---

### Variable 3: Search Term (For Log Explorer)

Free-text search for filtering log lines.

| Setting | Value |
|---------|-------|
| **Variable type** | Text box |
| **Name** | `search_term` |
| **Label** | Search |
| **Description** | Search for text in logs (leave blank to see all) |
| **Show on dashboard** | Label and value |
| **Default value** | *(leave empty)* |

Click **Apply** to save.

---

## Dashboard 1: Client System Health

**Purpose:** Daily operations view for client infrastructure monitoring.

### Dashboard Settings
- **Name:** `[Client Name] - System Health`
- **Tags:** `client`, `infrastructure`
- **Time range:** Last 24 hours
- **Refresh:** 30s
- **Variables:** Uses `$client` variable

---

### ROW 1: Critical Status Indicators

Three stat panels showing critical metrics at a glance.

#### Panel 1.1: Server Status

**Shows:** Whether the server is reachable by Prometheus.

**Visualization:** Stat

**Query:**
```promql
up{job="nodes", tenant="$client"}
```

**Panel Options:**
- **Title:** Server Status
- **Description:** Real-time server availability from Prometheus scraping

**Standard Options:**
- **Unit:** None
- **Decimals:** 0

**Value Mappings:**
- `1` → Display: `ONLINE` → Color: Green
- `0` → Display: `OFFLINE` → Color: Red

**Thresholds:**
- **Base:** Red
- **+Add threshold:** Value `1` → Green

**Display:**
- **Color mode:** Background solid
- **Show:** Value

---

#### Panel 1.2: Days Since Last Reboot (Uptime)

**Shows:** Time since server was last rebooted in days.

**Visualization:** Stat

**Query:**
```promql
(time() - node_boot_time_seconds{tenant="$client"}) / 86400
```

**Query Explanation:**
- `time()` = current Unix timestamp
- `node_boot_time_seconds` = when server booted
- Subtract = seconds of uptime
- Divide by 86400 = convert to days

**Panel Options:**
- **Title:** Uptime
- **Description:** Days since last reboot. Sudden drops indicate unplanned reboots.

**Standard Options:**
- **Unit:** None (or custom: `d`)
- **Decimals:** 1
- **Min:** 0

**Thresholds:**
- **Base:** Red (0 days)
- **+Add:** Value `0.1` → Yellow
- **+Add:** Value `1` → Green

**Display:**
- **Color mode:** Background gradient
- **Show:** Value and name

---

#### Panel 1.3: Active Alerts

**Shows:** Number of currently firing alerts for this client.

**Visualization:** Stat

**Query:**
```promql
count(ALERTS{tenant="$client", alertstate="firing"}) OR vector(0)
```

**Query Explanation:**
- `ALERTS{}` = Prometheus internal alert tracking
- `alertstate="firing"` = only active alerts
- `count()` = how many are firing
- `OR vector(0)` = show 0 if no alerts (instead of "No Data")

**Panel Options:**
- **Title:** Active Alerts
- **Description:** Number of active alerts requiring attention

**Standard Options:**
- **Unit:** Short
- **Decimals:** 0
- **Min:** 0

**Thresholds:**
- **Base:** Green
- **+Add:** Value `1` → Yellow
- **+Add:** Value `3` → Red

**Display:**
- **Color mode:** Background solid
- **Show:** Value

---

### ROW 2: Resource Utilization Gauges

Four gauge panels showing current resource usage.

#### Panel 2.1: CPU Usage

**Shows:** Current CPU utilization as percentage (0-100%).

**Visualization:** Gauge

**Query:**
```promql
100 - (avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle", tenant="$client"}[5m])
) * 100)
```

**Query Explanation:**
- `node_cpu_seconds_total{mode="idle"}` = time CPU spent idle
- `rate(...[5m])` = rate over 5 minutes (0.0 to 1.0)
- Multiply by 100 = percentage idle
- `100 - (...)` = flip to get percentage USED

**Panel Options:**
- **Title:** CPU Usage
- **Description:** Average CPU utilization across all cores over last 5 minutes

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100
- **Decimals:** 1

**Gauge:**
- **Show threshold labels:** Yes
- **Show threshold markers:** Yes

**Thresholds:**
- **Base:** Green
- **+Add:** Value `60` → Yellow
- **+Add:** Value `80` → Red

---

#### Panel 2.2: Memory Usage

**Shows:** RAM usage as percentage, accounting for available memory (not just free).

**Visualization:** Gauge

**Query:**
```promql
100 * (1 - (
  node_memory_MemAvailable_bytes{tenant="$client"} /
  node_memory_MemTotal_bytes{tenant="$client"}
))
```

**Query Explanation:**
- `MemTotal` = total RAM
- `MemAvailable` = RAM available (includes cache that can be freed)
- Divide = fraction available (0.0 to 1.0)
- `1 - (...)` = fraction USED
- Multiply by 100 = percentage

**Panel Options:**
- **Title:** Memory Usage
- **Description:** Percentage of RAM in use. Includes application memory and filesystem cache.

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100
- **Decimals:** 1

**Thresholds:**
- **Base:** Green
- **+Add:** Value `70` → Yellow
- **+Add:** Value `85` → Red

---

#### Panel 2.3: Disk Usage (Worst Filesystem)

**Shows:** The fullest disk/partition as a percentage.

**Visualization:** Gauge

**Query:**
```promql
max by (instance) (
  100 * (1 - (
    node_filesystem_avail_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"} /
    node_filesystem_size_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"}
  ))
)
```

**Query Explanation:**
- `fstype!~"tmpfs|fuse.*"` = exclude temporary/virtual filesystems
- Calculate percentage used for each filesystem
- `max by (instance)` = show the worst (fullest) one

**Panel Options:**
- **Title:** Disk Usage (Worst)
- **Description:** Percentage of disk space used on fullest partition

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100
- **Decimals:** 1

**Thresholds:**
- **Base:** Green
- **+Add:** Value `75` → Yellow
- **+Add:** Value `90` → Red

---

#### Panel 2.4: Swap Usage

**Shows:** Percentage of swap space being used (memory pressure indicator).

**Visualization:** Gauge

**Query:**
```promql
(100 * (
  (node_memory_SwapTotal_bytes{tenant="$client"} -
   node_memory_SwapFree_bytes{tenant="$client"}) /
  node_memory_SwapTotal_bytes{tenant="$client"}
)) OR vector(0)
```

**Query Explanation:**
- Total swap - free swap = used swap
- Divide by total = percentage
- `OR vector(0)` = return 0 if no swap configured

**Panel Options:**
- **Title:** Swap Usage
- **Description:** Percentage of swap space in use. Any swap usage indicates memory pressure.

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100
- **Decimals:** 1

**Thresholds:**
- **Base:** Green
- **+Add:** Value `10` → Yellow
- **+Add:** Value `25` → Red

---

### ROW 3: Performance Trends (Time Series)

Four time series panels showing metrics over 24 hours.

#### Panel 3.1: CPU Usage Over Time

**Shows:** CPU percentage as line graph over last 24 hours.

**Visualization:** Time series

**Query:**
```promql
100 - (avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle", tenant="$client"}[5m])
) * 100)
```

**Panel Options:**
- **Title:** CPU Usage (24h)
- **Description:** CPU utilization over time. Red line = 80% threshold.

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100
- **Decimals:** 1

**Graph Styles:**
- **Style:** Line
- **Line width:** 2
- **Fill opacity:** 20
- **Show points:** Auto
- **Point size:** 5

**Legend:**
- **Mode:** List
- **Placement:** Bottom
- **Values:** Min, Max, Current

**Thresholds:**
- **+Add:** Value `80` → Red
- **Threshold display:** Dashed line

**Tooltip:**
- **Mode:** All
- **Sort:** Descending

---

#### Panel 3.2: Memory Usage Over Time

**Visualization:** Time series

**Query:**
```promql
100 * (1 - (
  node_memory_MemAvailable_bytes{tenant="$client"} /
  node_memory_MemTotal_bytes{tenant="$client"}
))
```

**Panel Options:**
- **Title:** Memory Usage (24h)
- **Description:** Memory utilization over time. Red line = 85% threshold.

**Settings:** Same as CPU panel above, except:
- **Threshold line:** Value `85` → Red

---

#### Panel 3.3: Disk I/O Utilization

**Shows:** Percentage of time disk is busy handling I/O requests.

**Visualization:** Time series

**Query:**
```promql
rate(node_disk_io_time_seconds_total{tenant="$client"}[5m]) * 100
```

**Query Explanation:**
- `node_disk_io_time_seconds_total` = cumulative seconds disk was busy
- `rate(...[5m])` = seconds per second over 5min (0.0 to 1.0)
- Multiply by 100 = percentage

**Panel Options:**
- **Title:** Disk I/O Utilization
- **Description:** Percentage of time disk is actively processing I/O. High values indicate disk bottleneck.

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100

**Legend:**
- **Display:** `{{instance}} - {{device}}`

**Thresholds:**
- **+Add line:** Value `80` → Red

---

#### Panel 3.4: CPU I/O Wait Time

**Shows:** CPU time spent waiting for disk I/O.

**Visualization:** Time series

**Query:**
```promql
avg by (instance) (
  rate(node_cpu_seconds_total{mode="iowait", tenant="$client"}[5m])
) * 100
```

**Query Explanation:**
- `mode="iowait"` = time CPU spent waiting for disk
- High iowait with low CPU usage = disk is the bottleneck

**Panel Options:**
- **Title:** CPU I/O Wait Time
- **Description:** CPU time spent waiting for disk I/O. High values indicate disk is bottleneck, not CPU.

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Decimals:** 1

**Graph Styles:**
- **Fill opacity:** 30
- **Fill gradient:** Bottom to top

**Thresholds:**
- **+Add:** Value `10` → Yellow
- **+Add:** Value `20` → Red

---

### ROW 4: System Load & Network

#### Panel 4.1: Load Average

**Shows:** System load (processes waiting for CPU) over 1, 5, and 15 minutes, compared to CPU core count.

**Visualization:** Time series

**Multiple Queries:**

**Query A (Label: "1-min"):**
```promql
node_load1{tenant="$client"}
```

**Query B (Label: "5-min"):**
```promql
node_load5{tenant="$client"}
```

**Query C (Label: "15-min"):**
```promql
node_load15{tenant="$client"}
```

**Query D (Label: "CPU Cores"):**
```promql
count(count(node_cpu_seconds_total{mode="idle", tenant="$client"}) by (cpu))
```

**Panel Options:**
- **Title:** Load Average
- **Description:** Number of processes waiting for CPU. Should stay below CPU core count (dashed line).

**Standard Options:**
- **Unit:** Short
- **Min:** 0

**Graph Styles:**
- **Query A-C:** Normal lines
- **Query D:** 
  - Click query → Options → Line style → Dash
  - Line width → 1

**Legend:**
- **Shows all 4 queries**

---

#### Panel 4.2: Network Throughput

**Shows:** Bytes per second received and transmitted (mirror graph).

**Visualization:** Time series

**Query A (Label: "Received"):**
```promql
rate(node_network_receive_bytes_total{tenant="$client", device!~"lo|veth.*"}[5m])
```

**Query B (Label: "Transmitted"):**
```promql
rate(node_network_transmit_bytes_total{tenant="$client", device!~"lo|veth.*"}[5m])
```

**Transform Tab - CRITICAL:**
1. **Add transformation** → **Calculate field**
2. **Mode:** Binary operation
3. **Operation:** Multiply
4. **Field:** Select "Transmitted" (Query B)
5. **Value:** `-1`

*This creates the mirror effect (transmit shows below X-axis)*

**Panel Options:**
- **Title:** Network Traffic
- **Description:** Network receive (up) and transmit (down). Measured in bytes per second.

**Standard Options:**
- **Unit:** Bytes/sec
- **Decimals:** 2

**Graph Styles:**
- **Fill opacity:** 30
- **Line width:** 2

**Legend:**
- **Display:** `{{instance}} - {{device}}`

---

#### Panel 4.3: Network Errors

**Shows:** Rate of network packet errors.

**Visualization:** Time series

**Query:**
```promql
rate(node_network_receive_errs_total{tenant="$client"}[5m]) +
rate(node_network_transmit_errs_total{tenant="$client"}[5m])
```

**Panel Options:**
- **Title:** Network Errors
- **Description:** Network packet errors. Should always be zero. Any errors indicate hardware or network issues.

**Standard Options:**
- **Unit:** Short (errors/sec)
- **Min:** 0
- **Decimals:** 3

**Thresholds:**
- **Base:** Green
- **+Add line:** Value `0.1` → Yellow

**Graph Styles:**
- **Style:** Bars
- **Fill opacity:** 100

---

#### Panel 4.4: Clock Drift

**Shows:** How far server's clock has drifted from real time.

**Visualization:** Time series

**Query:**
```promql
abs(
  node_time_seconds{tenant="$client"} -
  timestamp(node_time_seconds{tenant="$client"})
)
```

**Query Explanation:**
- `node_time_seconds` = server's current time
- `timestamp()` = Prometheus's current time (authoritative)
- `abs()` = absolute difference

**Panel Options:**
- **Title:** Clock Drift
- **Description:** Time drift from NTP. >1 second causes TLS and distributed system failures.

**Standard Options:**
- **Unit:** seconds (s)
- **Decimals:** 3
- **Min:** 0

**Thresholds:**
- **+Add:** Value `0.5` → Yellow
- **+Add:** Value `1.0` → Red

---

### ROW 5: Detailed Disk Information (Table)

#### Panel 5.1: Filesystem Status Table

**Shows:** All mounted filesystems with size, usage, and percentages.

**Visualization:** Table

**Query Type:** Set all queries to **Instant** (not Range)

**Query A:**
```promql
node_filesystem_size_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"}
```

**Query B:**
```promql
node_filesystem_size_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"} -
node_filesystem_avail_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"}
```

**Query C:**
```promql
node_filesystem_avail_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"}
```

**Query D:**
```promql
100 * (1 - (
  node_filesystem_avail_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"} /
  node_filesystem_size_bytes{tenant="$client", fstype!~"tmpfs|fuse.*"}
))
```

**Transform Tab:**

1. **Add transformation** → **Merge** (combines all queries)
2. **Add transformation** → **Organize fields**
   - Rename:
     - `Value #A` → `Total Size`
     - `Value #B` → `Used`
     - `Value #C` → `Available`
     - `Value #D` → `Used %`
   - Hide: `job`, `tenant`, `Time`
   - Column order: `instance`, `mountpoint`, `Total Size`, `Used`, `Available`, `Used %`

**Field Overrides:**

**Override 1 - Size columns:**
- **Select fields:** Total Size, Used, Available
- **+Add override:**
  - **Standard options → Unit** → Bytes (IEC)
  - **Standard options → Decimals** → 1

**Override 2 - Percentage column:**
- **Select field:** Used %
- **+Add override:**
  - **Standard options → Unit** → Percent (0-100)
  - **Standard options → Decimals** → 1
  - **Cell display mode** → Color background (gradient)
  - **Thresholds:**
    - Base: Green
    - 75: Yellow
    - 90: Red

**Panel Options:**
- **Title:** Disk Space Details
- **Description:** All filesystems with current usage and available space

**Table Settings:**
- **Show header:** Yes
- **Cell height:** Auto

---

#### Panel 5.2: Read-Only Filesystem Detection

**Shows:** Detects if any filesystem has become read-only (critical failure).

**Visualization:** Stat

**Query:**
```promql
sum(node_filesystem_readonly{tenant="$client", fstype!~"tmpfs|fuse.*|overlay|squashfs"})
```

**Panel Options:**
- **Title:** Read-Only Filesystems
- **Description:** Detects filesystems in read-only state (hardware failure). Any value > 0 = critical.

**Value Mappings:**
- `0` → Text: `All OK` → Color: Green
- `>0` → Text: `READ-ONLY DETECTED` → Color: Red

**Thresholds:**
- **Base:** Green
- **+Add:** Value `1` → Red

**Display:**
- **Color mode:** Background solid

---

## Dashboard 2: Client Website/Endpoint Status

**Purpose:** External monitoring - what customers see.

### Dashboard Settings
- **Name:** `[Client Name] - Website Status`
- **Tags:** `client`, `website`, `external-monitoring`
- **Time range:** Last 24 hours
- **Refresh:** 30s

---

### ROW 1: High-Level Status

Three stat panels for quick overview.

#### Panel 1.1a: Total Endpoints

**Visualization:** Stat

**Query:**
```promql
count(probe_success{tenant="$client"})
```

**Panel Options:**
- **Title:** Total Endpoints

**Display:**
- **Color mode:** Background solid
- **Color:** Blue

---

#### Panel 1.1b: Endpoints Online

**Visualization:** Stat

**Query:**
```promql
count(probe_success{tenant="$client"} == 1)
```

**Panel Options:**
- **Title:** Online

**Thresholds:**
- Always green

---

#### Panel 1.1c: Endpoints Offline

**Visualization:** Stat

**Query:**
```promql
count(probe_success{tenant="$client"} == 0) OR vector(0)
```

**Panel Options:**
- **Title:** OFFLINE

**Value Mappings:**
- `0` → `All OK`

**Thresholds:**
- **Base:** Green
- **+Add:** Value `1` → Red

---

#### Panel 1.2: Average Response Time (24h)

**Visualization:** Stat

**Query:**
```promql
avg_over_time(
  avg(probe_duration_seconds{tenant="$client"})[24h:]
) * 1000
```

**Panel Options:**
- **Title:** Average Response Time (24h)

**Standard Options:**
- **Unit:** milliseconds (ms)
- **Decimals:** 0

**Thresholds:**
- **Base:** Green
- **+Add:** Value `500` → Yellow
- **+Add:** Value `2000` → Red

**Display:**
- **Color mode:** Background gradient

---

### ROW 2: Per-Endpoint Status Table

#### Panel 2.1: Endpoint Details Table

**Shows:** Current status, response time, HTTP code, and SSL expiry for all endpoints.

**Visualization:** Table

**Query Type:** Set all to **Instant**

**Query A (Status):**
```promql
probe_success{tenant="$client"}
```

**Query B (Response Time):**
```promql
probe_duration_seconds{tenant="$client"} * 1000
```

**Query C (HTTP Status):**
```promql
probe_http_status_code{tenant="$client"}
```

**Query D (SSL Days):**
```promql
(probe_ssl_earliest_cert_expiry{tenant="$client"} - time()) / 86400
```

**Transform Tab:**

1. **Add transformation** → **Merge**
2. **Add transformation** → **Organize fields**
   - Rename:
     - `instance` → `URL`
     - `Value #A` → `Status`
     - `Value #B` → `Response (ms)`
     - `Value #C` → `HTTP Code`
     - `Value #D` → `SSL Days`
   - Hide: `job`, `tenant`, `Time`
   - Column order: URL, Status, Response (ms), HTTP Code, SSL Days

**Field Overrides:**

**Override 1 - Status:**
- **Select field:** Status
- **+Add override:**
  - **Unit** → None
  - **Decimals** → 0
  - **Value mappings:**
    - `1` → Text: `✓ UP` → Green
    - `0` → Text: `✗ DOWN` → Red
  - **Cell display mode** → Color background (solid)

**Override 2 - Response (ms):**
- **Select field:** Response (ms)
- **+Add override:**
  - **Unit** → milliseconds (ms)
  - **Decimals** → 0
  - **Cell display mode** → Color background (gradient)
  - **Thresholds:**
    - Base: Green
    - 500: Yellow
    - 2000: Red

**Override 3 - HTTP Code:**
- **Select field:** HTTP Code
- **+Add override:**
  - **Decimals** → 0
  - **Cell display mode** → Color background (solid)
  - **Value mappings:**
    - `200` → Green
    - `301` → Green
    - `302` → Green
    - Range `400-499` → Orange
    - Range `500-599` → Red

**Override 4 - SSL Days:**
- **Select field:** SSL Days
- **+Add override:**
  - **Unit** → None
  - **Decimals** → 0
  - **Cell display mode** → Color background (gradient)
  - **Thresholds:**
    - Base: Red
    - 15: Yellow
    - 30: Green
  - **No value** → `N/A`

**Panel Options:**
- **Title:** Endpoint Status
- **Description:** Current status of all monitored endpoints. Updates every 30 seconds.

**Table Options:**
- **Show header:** Yes
- **Cell height:** Comfortable

---

### ROW 3: Response Time Trends

#### Panel 3.1: Response Time by Endpoint

**Shows:** Response time for each endpoint over 24 hours.

**Visualization:** Time series

**Query:**
```promql
probe_duration_seconds{tenant="$client"} * 1000
```

**Panel Options:**
- **Title:** Response Time by Endpoint
- **Description:** Response time for each monitored endpoint. Yellow line = 500ms (acceptable), Red line = 2000ms (slow).

**Standard Options:**
- **Unit:** milliseconds (ms)
- **Min:** 0
- **Decimals:** 0

**Graph Styles:**
- **Style:** Lines
- **Line width:** 2
- **Fill opacity:** 0 (no fill)
- **Show points:** Never

**Legend:**
- **Mode:** List
- **Placement:** Bottom
- **Values:** Min, Max, Current
- **Display:** `{{instance}}`

**Thresholds:**
- **+Add:** Value `500` → Yellow (Dashed line)
- **+Add:** Value `2000` → Red (Dashed line)
- **Threshold display:** Dashed line

**Tooltip:**
- **Mode:** All
- **Sort:** Descending

---

### ROW 4: SSL Certificate Monitoring

#### Panel 4.1: SSL Certificate Expiry

**Shows:** Days until SSL certificate expires for each HTTPS endpoint.

**Visualization:** Bar gauge (horizontal)

**Query:**
```promql
(probe_ssl_earliest_cert_expiry{tenant="$client"} - time()) / 86400
```

**Panel Options:**
- **Title:** SSL Certificate Expiry
- **Description:** Days until SSL certificate expires. Red = urgent renewal needed, Yellow = schedule renewal soon.

**Standard Options:**
- **Unit:** None
- **Min:** 0
- **Max:** 90
- **Decimals:** 0

**Bar Gauge:**
- **Orientation:** Horizontal
- **Display mode:** Gradient
- **Show unfilled area:** Yes

**Thresholds:**
- **Base:** Red (0 days)
- **+Add:** Value `15` → Yellow
- **+Add:** Value `30` → Green

**Legend:**
- **Display:** `{{instance}}`
- **Placement:** Right

---

## Dashboard 3: Alert History & Incident Log

**Purpose:** Monthly reporting and alert pattern analysis.

### Dashboard Settings
- **Name:** `Alert History - [Client Name]`
- **Tags:** `alerts`, `reporting`, `incidents`
- **Time range:** Last 30 days
- **Refresh:** 5m

---

### ROW 1: Alert Summary Statistics

#### Panel 1.1: Total Alerts Fired (30 Days)

**Visualization:** Stat

**Query:**
```promql
count(
  count_over_time(
    ALERTS{tenant="$client", alertstate="firing"}[30d]
  )
)
```

**Panel Options:**
- **Title:** Total Alerts (30 Days)
- **Time range override:** Last 30 days

**Standard Options:**
- **Unit:** Short
- **Decimals:** 0

**Thresholds:**
- **Base:** Green
- **+Add:** Value `10` → Yellow
- **+Add:** Value `50` → Red

---

### ROW 2: Alert Timeline

#### Panel 2.1: Alert Activity Timeline

**Shows:** When alerts were active as colored blocks on a timeline.

**Visualization:** State timeline

**Query:**
```promql
ALERTS{tenant="$client"}
```

**Panel Options:**
- **Title:** Alert History
- **Description:** Timeline of alert activity. Red = alert was firing. Each row is a different alert.

**Value Mappings:**
- `0` → Text: `OK` → Green
- `1` → Text: `FIRING` → Red

**State Timeline Options:**
- **Show legend:** Yes
- **Legend placement:** Bottom

---

### ROW 3: Most Frequent Alerts

#### Panel 3.1: Alert Frequency Table

**Shows:** Ranks alerts by how many times they fired.

**Visualization:** Bar chart (horizontal)

**Query:**
```promql
topk(10,
  count(
    count_over_time(
      ALERTS{tenant="$client", alertstate="firing"}[30d]
    )
  ) by (alertname)
)
```

**Panel Options:**
- **Title:** Most Frequent Alerts (30 Days)
- **Description:** Top 10 most frequent alerts. Use to identify noisy alerts needing threshold tuning.

**Standard Options:**
- **Unit:** Short
- **Decimals:** 0

**Bar Chart:**
- **Orientation:** Horizontal
- **Show values:** On
- **Sort:** Descending by value

**Thresholds:**
- **Base:** Green (1-5 times)
- **+Add:** Value `6` → Yellow
- **+Add:** Value `20` → Red

---

## Dashboard 4: Internal Monitoring Stack Health

**Purpose:** Monitor YOUR infrastructure health. Check this before checking client dashboards.

### Dashboard Settings
- **Name:** `Internal - Monitoring Stack Health`
- **Tags:** `internal`, `infrastructure`, `monitoring`
- **Time range:** Last 24 hours
- **Refresh:** 30s

---

### ROW 1: Critical Service Status

Five stat panels showing each monitoring component's status.

#### Panel 1.1a: Prometheus Status

**Visualization:** Stat

**Query:**
```promql
up{service="prometheus"}
```

**Panel Options:**
- **Title:** Prometheus
- **Description:** Prometheus metrics collection service status

**Value Mappings:**
- `1` → Text: `RUNNING` → Green
- `0` → Text: `DOWN` → Red

**Display:**
- **Color mode:** Background solid

---

#### Panel 1.1b: Loki Status

**Visualization:** Stat

**Query:**
```promql
up{service="loki"}
```

**Panel Options:**
- **Title:** Loki
- **Description:** Loki log aggregation service status

**Settings:** Same as Prometheus panel

---

#### Panel 1.1c: Grafana Status

**Visualization:** Stat

**Query:**
```promql
up{service="grafana"}
```

**Panel Options:**
- **Title:** Grafana

**Settings:** Same as Prometheus panel

---

#### Panel 1.1d: MinIO Status

**Visualization:** Stat

**Query:**
```promql
up{service="minio"}
```

**Panel Options:**
- **Title:** MinIO
- **Description:** MinIO object storage (stores Loki logs)

**Settings:** Same as Prometheus panel

---

#### Panel 1.1e: Promtail Agents

**Shows:** How many promtail agents are healthy.

**Visualization:** Stat

**Query:**
```promql
count(up{job="promtail"} == 1)
```

**Panel Options:**
- **Title:** Promtail Agents
- **Description:** Number of healthy promtail log shippers

**Display:**
- **Show:** Value

---

### ROW 2: Monitoring Server Resources

Three gauge panels for the monitoring server itself.

#### Panel 2.1a: Monitoring Server - CPU

**Visualization:** Gauge

**Query:**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle", tenant="internal", role="control-plane"}[5m])) * 100)
```

**Panel Options:**
- **Title:** Monitoring Server - CPU

**Thresholds:**
- **Base:** Green
- **+Add:** Value `50` → Yellow (stricter than client thresholds)
- **+Add:** Value `70` → Red

**Standard Options:**
- **Unit:** Percent (0-100)
- **Min:** 0
- **Max:** 100

---

#### Panel 2.1b: Monitoring Server - Memory

**Visualization:** Gauge

**Query:**
```promql
100 * (1 - (
  node_memory_MemAvailable_bytes{tenant="internal", role="control-plane"} /
  node_memory_MemTotal_bytes{tenant="internal", role="control-plane"}
))
```

**Panel Options:**
- **Title:** Monitoring Server - Memory

**Thresholds:**
- **Base:** Green
- **+Add:** Value `60` → Yellow
- **+Add:** Value `75` → Red

---

#### Panel 2.1c: Monitoring Server - Disk

**Visualization:** Gauge

**Query:**
```promql
max(100 * (1 - (
  node_filesystem_avail_bytes{tenant="internal", role="control-plane", fstype!~"tmpfs|fuse.*"} /
  node_filesystem_size_bytes{tenant="internal", role="control-plane", fstype!~"tmpfs|fuse.*"}
)))
```

**Panel Options:**
- **Title:** Monitoring Server - Disk

**Thresholds:**
- **Base:** Green
- **+Add:** Value `70` → Yellow
- **+Add:** Value `85` → Red

---

### ROW 3: Prometheus Operational Metrics

#### Panel 3.1: Prometheus Sample Ingestion Rate

**Shows:** How many metric samples Prometheus is ingesting per second.

**Visualization:** Time series

**Query:**
```promql
rate(prometheus_tsdb_head_samples_appended_total[5m])
```

**Panel Options:**
- **Title:** Prometheus Ingestion Rate
- **Description:** Number of metric samples ingested per second. Sudden 2x spike indicates cardinality problem.

**Standard Options:**
- **Unit:** samples/sec
- **Decimals:** 0

**Graph Styles:**
- **Line width:** 2
- **Fill opacity:** 20

---

#### Panel 3.2: Prometheus Query Duration

**Shows:** Average time to execute queries.

**Visualization:** Time series

**Query:**
```promql
rate(prometheus_engine_query_duration_seconds_sum[5m]) /
rate(prometheus_engine_query_duration_seconds_count[5m])
```

**Panel Options:**
- **Title:** Prometheus Query Duration
- **Description:** Average time to execute queries. >5s indicates performance problems.

**Standard Options:**
- **Unit:** seconds (s)
- **Decimals:** 2

**Thresholds:**
- **+Add line:** Value `1.0` → Yellow
- **+Add line:** Value `5.0` → Red

---

#### Panel 3.3: Active Scrape Targets Summary

Three stat panels side-by-side.

**Panel A - Total Targets:**
```promql
count(up)
```

**Panel B - Healthy Targets:**
```promql
count(up == 1)
```

**Panel C - Down Targets:**
```promql
count(up == 0) OR vector(0)
```

**Formatting:**
- Panel A: Blue background
- Panel B: Green background
- Panel C: Red if > 0, Green if 0

---

### ROW 4: Loki Log Ingestion Health

#### Panel 4.1: Loki Ingestion by Client

**Shows:** Log data volume per client in bytes/second.

**Visualization:** Time series

**Data Source:** Loki (not Prometheus)

**Query Type:** Metrics

**Query:**
```logql
sum by (tenant) (rate({tenant=~".+"}[5m]))
```

**Panel Options:**
- **Title:** Loki Ingestion by Client
- **Description:** Log ingestion rate per client. Stacked to show total load.

**Standard Options:**
- **Unit:** Bytes/sec
- **Decimals:** 2

**Graph Styles:**
- **Style:** Stacked area
- **Fill opacity:** 70

**Legend:**
- **Display:** `{{tenant}}`
- **Values:** Current, Max

---

#### Panel 4.2: Log Rate by Tenant

**Shows:** Log entries per time period by client.

**Visualization:** Bar gauge (horizontal)

**Data Source:** Loki

**Query Type:** Range

**Query:**
```logql
sum by (tenant) (count_over_time({tenant=~".+"}[5m]))
```

**Panel Options:**
- **Title:** Log Rate by Tenant
- **Description:** Log entries per 5 minutes by client. High values may indicate verbose logging or errors.

**Standard Options:**
- **Unit:** Short
- **Decimals:** 0

**Bar Gauge:**
- **Orientation:** Horizontal
- **Display mode:** Gradient

**Thresholds:**
- **Base:** Green
- **+Add:** Value `5000` → Yellow
- **+Add:** Value `10000` → Red

---

## Dashboard 5: Log Explorer

**Purpose:** Troubleshooting dashboard for incident investigation.

### Dashboard Settings
- **Name:** `Log Explorer - [Client Name]`
- **Tags:** `logs`, `troubleshooting`, `debugging`
- **Time range:** Last 1 hour (adjustable)
- **Refresh:** 10s
- **Variables:** Uses `$client`, `$job`, and `$search_term`

---

### Panel 5.1: Log Stream Viewer

**Shows:** Live log stream with filtering and search.

**Visualization:** Logs

**Data Source:** Loki

**Query Type:** Range

**Query (Basic):**
```logql
{tenant="$client", job="$job"} |= "$search_term"
```

**Query (Advanced - if JSON logs):**
```logql
{tenant="$client", job="$job"}
  |= "$search_term"
  | json
  | line_format "{{.timestamp}} [{{.level}}] {{.message}}"
```

**Panel Options:**
- **Title:** Logs
- **Description:** Live log stream. Use filters above to narrow down. Click any line for details.

**Logs Display:**
- **Show time:** Yes
- **Show labels:** Yes
- **Show common labels:** No
- **Wrap lines:** Yes
- **Prettify JSON:** Yes
- **Enable log details:** Yes

**Order:**
- **Sort order:** Time (descending) - newest first

**Deduplication:**
- **Deduplication:** Signature

**Query Options:**
- **Show logs volume:** Yes (adds histogram above logs)
- **Max data points:** 1000

---

## Launch Readiness Checklist

Before deploying to clients, verify all dashboards:

### Visual Quality
- [ ] All panels have descriptive titles
- [ ] All panels have descriptions explaining what they show
- [ ] Colors make sense (green = good, yellow = warning, red = critical)
- [ ] Thresholds are visible as reference lines
- [ ] Legends show useful information (min/max/current)
- [ ] No "No Data" panels (indicates scraping issues)

### Functional Testing
- [ ] Dashboard variables work correctly
- [ ] Client selector filters all panels appropriately
- [ ] Time range changes affect all panels
- [ ] Can click on log lines to see full details
- [ ] Graphs show expected data ranges
- [ ] Tables display all columns correctly

### Data Validation
- [ ] Metrics align with your alert rules in `prometheus/rules/`
- [ ] Tenant labels match your `file_sd` configurations
- [ ] Log queries return results from existing logs
- [ ] SSL expiry only shows for HTTPS endpoints
- [ ] Filesystem table excludes virtual filesystems

### Documentation
- [ ] Dashboard has description at top
- [ ] Complex panels have helpful tooltips
- [ ] Alert thresholds match business requirements
- [ ] Color coding is consistent across dashboards

---

## Metrics Coverage Summary

### ✅ You Can Detect
1. Server down or unreachable
2. Unexpected reboots
3. CPU overload
4. Memory exhaustion
5. Swap pressure
6. Disk space filling up
7. Disk I/O bottlenecks
8. Network saturation or errors
9. Website/API down
10. Website/API slow response
11. SSL certificate expiring
12. Time synchronization issues
13. Filesystem read-only state (hardware failure)
14. System and application errors in logs
15. Authentication failures

### ⚠️ Phase 2 Additions (Future)
- Application-specific metrics (database, queues)
- Container/Kubernetes monitoring
- Business metrics (user counts, transactions)
- Distributed tracing
- Custom application instrumentation

---

## Dashboard Organization

| Dashboard | Purpose | Primary Users |
|-----------|---------|---------------|
| **Dashboard 1** | Client System Health | Daily ops, client review |
| **Dashboard 2** | Website Status | External monitoring, SLA reporting |
| **Dashboard 3** | Alert History | Monthly reports, pattern analysis |
| **Dashboard 4** | Stack Health | Internal ops, your monitoring |
| **Dashboard 5** | Log Explorer | Incident troubleshooting |

---

## Client Communication Templates

### Daily Status Check
*"Your monitoring dashboard shows all green indicators today:"*
- ✅ Server online for 45.3 days
- ✅ CPU usage averaging 35%
- ✅ Memory at 62% (healthy)
- ✅ Disk space 67% used (plenty of headroom)
- ✅ Website responding in 234ms
- ✅ SSL certificate valid for 67 days
- ✅ Zero active alerts

### When Issues Detected
*"Alert detected on your infrastructure:"*
- ⚠️ **Issue:** Disk space on /var partition reached 88%
- 📊 **Current state:** 44GB used of 50GB total
- 🎯 **Action needed:** Clean up old logs or expand storage
- ⏰ **Urgency:** Medium (will run out in ~2 weeks at current rate)
- 📈 **Trend:** Usage growing 2GB/week

---

## Troubleshooting Guide

### No Data in Panels

**Check:**
1. Is Prometheus scraping targets? → `http://your-ip:9090/targets`
2. Do labels match your `tenant="$client"` values?
3. Is time range appropriate for the data?
4. Are node_exporter and blackbox_exporter running?

**Fix:**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify labels exist
curl http://localhost:9090/api/v1/label/tenant/values

# Check if metrics exist
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Variables Not Updating

**Check:**
1. Variable created in correct order (client before job)
2. Refresh set to "On time range change"
3. Query returns values in variable editor

**Fix:**
- Delete and recreate variables in correct order
- Ensure data source is selected correctly (Prometheus vs Loki)

### Logs Not Appearing

**Check:**
1. Is Loki receiving logs? → `http://your-ip:3100/metrics`
2. Are promtail agents up? → `http://your-ip:9080/targets`
3. Do log labels match query `{tenant="$client"}`?

**Fix:**
```bash
# Check Loki ingestion
docker-compose logs loki | grep -i error

# Verify promtail is shipping
docker-compose logs promtail | tail -20

# Test Loki query directly
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={tenant="internal"}' | jq
```

### SSL Certificate Panels Empty

**Reason:** Only HTTPS endpoints have SSL certificates.

**Fix:**
- Verify blackbox is configured to check HTTPS URLs
- Check `prometheus/file_sd/blackbox_addr.yml` has `https://` URLs
- Non-HTTPS endpoints will show "N/A" correctly

---

## Best Practices

### Dashboard Design
1. **Use consistent colors** across all dashboards (green/yellow/red)
2. **Set realistic thresholds** based on actual capacity, not arbitrary numbers
3. **Show context** with reference lines (CPU cores, threshold limits)
4. **Group related metrics** in rows for easy scanning
5. **Use appropriate visualizations** (gauges for current state, time series for trends)

### Alert Tuning
1. Start with conservative thresholds (avoid alert fatigue)
2. Adjust based on actual patterns (what's normal for this client?)
3. Use `for: 5m` to avoid alerting on temporary spikes
4. Document why each threshold was chosen

### Documentation
1. Every panel should have a description
2. Complex queries should have comments
3. Thresholds should be explained (why 80%? why 5 seconds?)
4. Link to runbooks for common alerts

---

## Next Steps

1. **Build all 5 dashboards** following this guide
2. **Test with your homelab** (Client-A, Client-B, internal)
3. **Screenshot each dashboard** for your GitHub/portfolio
4. **Write blog post** showing your setup
5. **Create monthly report template** using Dashboard 3
6. **Document your SLAs** based on these metrics
7. **Reach out to first client** with confidence

---

## File Structure Reference

Your monitoring stack maps to these dashboards:

```
monitor/
├── prometheus/
│   ├── prometheus.yml              # Scrape configs
│   ├── file_sd/
│   │   ├── prom_nodes.yml          # → Dashboard 1 (System Health)
│   │   ├── blackbox_addr.yml       # → Dashboard 2 (Website Status)
│   │   └── internal_monitoring.yml # → Dashboard 4 (Stack Health)
│   └── rules/
│       ├── slis.yml                # → Dashboard 1, 2, 3 (Metrics)
│       ├── alerts.yml              # → Dashboard 3 (Alert History)
│       └── platform_alerts.yml     # → Dashboard 4 (Internal Alerts)
├── loki/
│   └── config.yml                  # → Dashboard 5 (Logs)
├── promtail/
│   └── file_sd/
│       ├── system.yml              # → Dashboard 5 (System Logs)
│       └── nginx.yml               # → Dashboard 5 (Nginx Logs)
└── grafana/
    └── provisioning/
        └── datasources/            # Configure before creating dashboards
            ├── prometheus.yml
            └── loki.yml
```

---

## Additional Resources

### Prometheus Query Language (PromQL)
- [Official Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

### LogQL (Loki Query Language)
- [Official Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Log Query Examples](https://grafana.com/docs/loki/latest/logql/log_queries/)

### Grafana Best Practices
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)
- [Visualization Guide](https://grafana.com/docs/grafana/latest/panels-visualizations/)

---

## License

This configuration guide is provided as-is for building monitoring dashboards based on the monitoring stack defined in this repository.

---

**Last Updated:** January 2026
**Version:** 1.0
**Author:** Stack Monitoring Project
