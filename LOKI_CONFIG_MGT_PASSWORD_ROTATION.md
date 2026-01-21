# Loki Configuration Management & Password Rotation Guide
This guide covers setting up automated config generation for Loki using host-side templates and rotating MinIO credentials safely without data loss.

# Part 1: Initial Setup - Config Generation Script
Project Structure
Create the following structure:
```
monitor/
├── .env                          # gitignored
├── loki/
│   ├── config.yml.template       # committed to git
│   ├── config.yml                # generated, gitignored
│   └── generate-config.sh        # committed to git
└── docker-compose.yml
```
## Step 1: Update .gitignore
Add these lines to your .gitignore:
```
.env
loki/config.yml
```
## Step 2: Create the Config Template
Create loki/config.yml.template with your Loki configuration, using environment variable placeholders:
yaml
```
common:
  path_prefix: /loki
  storage:
    s3:
      endpoint: minio:9000
      bucketnames: loki-data
      access_key_id: ${LOKI_S3_ACCESS_KEY}
      secret_access_key: ${LOKI_S3_SECRET_KEY}
      s3forcepathstyle: true
      insecure: true

# ... rest of your Loki config

```
Important: The s3forcepathstyle: true setting is required for MinIO compatibility.
## Step 3: Create the Generation Script
Create loki/generate-config.sh:
```
bash#!/bin/bash
set -e

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "❌ .env file not found"
  exit 1
fi

# Load env safely
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Sanity check
: "${LOKI_S3_ACCESS_KEY:?Missing}"
: "${LOKI_S3_SECRET_KEY:?Missing}"

echo "🔧 Generating Loki config..."
envsubst < loki/config.yml.template > loki/config.yml

echo "✅ Loki config generated"
```

Make it executable:
bash
```chmod +x loki/generate-config.sh```

## Step 4: Configure .env
Create your .env file:
bash
```
# MinIO Root Credentials
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-strong-password

# Loki MinIO Access (dedicated user)
LOKI_S3_ACCESS_KEY=loki
LOKI_S3_SECRET_KEY=your-loki-password
```

## Step 5: Update docker-compose.yml
Configure Loki to use the generated config:
yaml
```
loki:
  image: grafana/loki:latest
  container_name: loki
  command: -config.file=/etc/loki/local-config.yaml
  volumes:
    - ./loki/config.yml:/etc/loki/local-config.yaml:ro
    - loki-data:/loki
  ports:
    - "3100:3100"
  depends_on:
    minio:
      condition: service_healthy
  restart: unless-stopped
```
Note: No environment: block needed - credentials come from the mounted config file.
## Step 6: Generate Config and Start Services
bash
```
# Generate the config
./loki/generate-config.sh

# Start services
docker-compose up -d
```
Verify Config Generation
Check that credentials were properly substituted:
bash
```grep -n "access_key_id\|secret_access_key" loki/config.yml```

# Part 2: Production-Safe Password Rotation
This procedure rotates credentials without data loss by creating a dedicated MinIO user for Loki instead of changing the root password.
Why This Approach?

Root password changes require wiping MinIO data
Dedicated service accounts follow best practices
Credentials can be rotated anytime without downtime
Follows AWS IAM patterns

## Step 1: Create Dedicated Loki User in MinIO
bash
```
# Exec into MinIO container
docker exec -it minio sh

# Configure mc alias with root credentials
mc alias set local http://localhost:9000 minioadmin <current-root-password>

# Create dedicated Loki user
mc admin user add local loki
# You'll be prompted to enter Access Key (loki) and Secret Key (choose a strong password)

# Attach read/write permissions
mc admin policy attach local readwrite --user loki

# Verify user was created
mc admin user list local
# Should show: loki enabled

# Exit container
exit
```
## Step 2: Update Environment Variables
Update .env with the new Loki user credentials:
bash
```
# MinIO Root Credentials (unchanged)
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-root-password

# Loki MinIO Access (new dedicated user)
LOKI_S3_ACCESS_KEY=loki
LOKI_S3_SECRET_KEY=your-new-loki-password
```

## Step 3: Regenerate Loki Config
bash ``` ./loki/generate-config.sh```

Verify the new credentials are in the config:
bash ```grep access_key_id -n loki/config.yml```

## Step 4: Restart Loki Only
bash ```docker-compose restart loki```
Important: Do NOT restart MinIO - the user already exists and is active.

## Step 5: Verify Everything Works
Check Loki logs for successful S3 operations:
bash```docker-compose logs loki | grep -i s3```
Good signs (healthy operation):

Messages about uploading/compacting tables
Index shipping operations
No error messages

Bad signs (needs troubleshooting):

```SignatureDoesNotMatch```
```AccessDenied```
```InvalidAccessKeyId```

Watch live logs to see normal operation:
bash```docker-compose logs -f loki```
You should see info-level messages like:

```uploading table index_XXXXX```
```finished uploading table index_XXXXX```
```compacting table```
```handing over indexes to shipper```


# Troubleshooting
### Issue: SignatureDoesNotMatch Error
Cause: Usually clock skew between Loki and MinIO containers
Fix:
bash
```
# Check time in each container
docker exec -it minio date -u
docker exec -it loki date -u
date -u  # host time

# If times differ, fix host NTP
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd

# Restart both containers to pick up correct time
docker-compose restart minio loki
```
### Issue: Credentials Don't Update
Checklist:

Did you regenerate config? ```./loki/generate-config.sh```
Did you restart Loki? ```docker-compose restart loki```
Are credentials in .env correct?
Does generated config have new values? ```grep access_key_id loki/config.yml```

### Issue: Config File Not Found
Verify mount:
bash```docker inspect loki | grep local-config.yaml```

## Operational Workflow
When Changing Credentials

Update MinIO user password (if using dedicated user)
Update ```.env```
Regenerate config: ```./loki/generate-config.sh```
Restart Loki: ```docker-compose restart loki```

## Important Notes

Never edit ```loki/config.yml``` manually - it will be overwritten
Always regenerate after .env changes
The generated config is a build artifact (like compiled code)
Keep ```config.yml.template``` in git, keep ```config.yml``` gitignored


Best Practices
✅ Use dedicated service accounts (not root) for applications
✅ Keep secrets in .env only
✅ Keep templates in version control
✅ Regenerate configs before deployments
✅ Mount configs read-only in containers
✅ Enable NTP on your host system
❌ Never commit .env or generated configs
❌ Never bake secrets into Docker images
❌ Never use root MinIO credentials for services
❌ Never edit generated files manually
