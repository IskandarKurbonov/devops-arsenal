# DevOps Arsenal

> Powerful automation scripts and tools for DevOps engineers

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)

## Overview

DevOps Arsenal is a comprehensive collection of battle-tested automation scripts and tools designed to streamline DevOps workflows. From server management to deployment automation, this arsenal has everything you need.

## Features

- **Production Ready**: Scripts tested in real-world environments
- **Modular Design**: Use scripts independently or combine them
- **Well Documented**: Clear usage instructions and examples
- **Error Handling**: Robust error handling and logging
- **Cross-Platform**: Works on Linux, macOS, and WSL2

## Script Categories

### 🔧 Server Management

| Script | Description | Language |
|--------|-------------|----------|
| **server-health-check.sh** | Complete server health monitoring | Bash |
| **disk-cleanup.sh** | Automated disk space cleanup | Bash |
| **log-rotation.sh** | Smart log rotation and archiving | Bash |
| **ssl-certificate-checker.sh** | Monitor SSL certificate expiry | Bash |
| **port-scanner.sh** | Network port availability checker | Bash |

### 🐳 Docker & Containers

| Script | Description | Language |
|--------|-------------|----------|
| **docker-cleanup.sh** | Clean unused containers, images, volumes | Bash |
| **docker-backup.sh** | Backup Docker volumes and configs | Bash |
| **container-monitor.py** | Monitor container resources | Python |
| **image-scanner.sh** | Security scan Docker images | Bash |
| **compose-deployer.sh** | Deploy multiple compose stacks | Bash |

### 🚀 Deployment & CI/CD

| Script | Description | Language |
|--------|-------------|----------|
| **zero-downtime-deploy.sh** | Blue-green deployment automation | Bash |
| **rollback-deployment.sh** | Automated rollback mechanism | Bash |
| **health-check-monitor.sh** | Post-deployment health checks | Bash |
| **artifact-uploader.py** | Upload build artifacts | Python |
| **env-sync.sh** | Sync environment configurations | Bash |

### 📊 Monitoring & Alerting

| Script | Description | Language |
|--------|-------------|----------|
| **resource-monitor.py** | CPU, RAM, disk monitoring | Python |
| **service-checker.sh** | Monitor service availability | Bash |
| **alert-sender.py** | Send alerts (Slack, Email, Telegram) | Python |
| **log-analyzer.sh** | Parse and analyze log files | Bash |
| **metrics-collector.py** | Collect custom metrics | Python |

### 🔒 Security & Compliance

| Script | Description | Language |
|--------|-------------|----------|
| **security-audit.sh** | Server security audit | Bash |
| **fail2ban-manager.sh** | Manage fail2ban rules | Bash |
| **user-audit.sh** | Audit user accounts and permissions | Bash |
| **vulnerability-scanner.sh** | Scan for vulnerabilities | Bash |
| **secret-scanner.py** | Detect secrets in code | Python |

### 💾 Backup & Recovery

| Script | Description | Language |
|--------|-------------|----------|
| **database-backup.sh** | Automated database backups | Bash |
| **s3-sync-backup.sh** | Sync backups to S3 | Bash |
| **restore-manager.sh** | Restore from backups | Bash |
| **backup-validator.py** | Validate backup integrity | Python |
| **snapshot-creator.sh** | Create system snapshots | Bash |

## Quick Start

### Installation

```bash
git clone https://github.com/IskandarKurbonov/devops-arsenal.git
cd devops-arsenal

# Make scripts executable
chmod +x scripts/**/*.sh
```

### Basic Usage

```bash
# Server health check
./scripts/server-management/server-health-check.sh

# Docker cleanup
./scripts/docker/docker-cleanup.sh

# Database backup
./scripts/backup/database-backup.sh --database myapp --output /backups
```

## Featured Scripts

### 1. Server Health Check

Comprehensive server health monitoring with detailed reporting.

```bash
#!/bin/bash
# scripts/server-management/server-health-check.sh

# Usage: ./server-health-check.sh [--email admin@example.com]
```

**Features:**
- CPU, RAM, Disk usage monitoring
- Network connectivity checks
- Service status verification
- SSL certificate expiry alerts
- Email/Slack notifications

**Output:**
```
=== Server Health Check Report ===
Timestamp: 2026-01-04 15:30:00
Hostname: production-server-01

✓ CPU Usage: 45% (OK)
✓ Memory Usage: 62% (OK)
✗ Disk Usage: 89% (WARNING)
✓ Network: Connected
✓ SSL Certificate: Valid (90 days remaining)

Services Status:
✓ nginx: running
✓ mysql: running
✓ redis: running
```

### 2. Docker Cleanup

Automated Docker cleanup to free up disk space.

```bash
#!/bin/bash
# scripts/docker/docker-cleanup.sh

# Usage: ./docker-cleanup.sh [--dry-run] [--force]
```

**What it cleans:**
- Stopped containers (>24h old)
- Unused images (dangling)
- Unused volumes
- Build cache
- Networks

**Safety features:**
- Dry-run mode
- Confirmation prompts
- Excludes running resources
- Detailed logging

### 3. Zero Downtime Deployment

Blue-green deployment automation for web applications.

```bash
#!/bin/bash
# scripts/deployment/zero-downtime-deploy.sh

# Usage: ./zero-downtime-deploy.sh --app myapp --version 1.2.3
```

**Process:**
1. Deploy to inactive environment (blue/green)
2. Run health checks
3. Switch traffic gradually
4. Monitor error rates
5. Automatic rollback on failure

### 4. Database Backup

Automated database backup with compression and encryption.

```bash
#!/bin/bash
# scripts/backup/database-backup.sh

# Usage: ./database-backup.sh --database myapp --encrypt
```

**Features:**
- Multiple database support (MySQL, PostgreSQL, MongoDB)
- Compression (gzip, bzip2)
- Encryption (GPG)
- S3 upload
- Retention policy
- Backup verification

### 5. Resource Monitor

Real-time resource monitoring with alerting.

```python
# scripts/monitoring/resource-monitor.py

# Usage: python3 resource-monitor.py --interval 60 --alert-threshold 80
```

**Monitors:**
- CPU usage per core
- Memory (RAM + Swap)
- Disk I/O
- Network traffic
- Process list

**Alerts:**
- Slack notifications
- Email alerts
- Telegram messages
- Webhook integration

## Configuration

### Global Configuration

Create `config/global.conf`:

```bash
# Email settings
EMAIL_ENABLED=true
EMAIL_TO="admin@example.com"
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT=587

# Slack settings
SLACK_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Backup settings
BACKUP_DIR="/var/backups"
BACKUP_RETENTION_DAYS=30
S3_BUCKET="my-backup-bucket"

# Monitoring thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
```

### Script-Specific Configuration

Each script can have its own config file:

```bash
# config/docker-cleanup.conf
CLEANUP_OLDER_THAN="24h"
KEEP_LATEST_IMAGES=5
EXCLUDED_CONTAINERS="mysql,redis"
```

## Usage Examples

### Daily Server Maintenance

```bash
#!/bin/bash
# Daily maintenance cron job

# Health check
/opt/devops-arsenal/scripts/server-management/server-health-check.sh

# Cleanup logs
/opt/devops-arsenal/scripts/server-management/log-rotation.sh

# Docker cleanup
/opt/devops-arsenal/scripts/docker/docker-cleanup.sh --force

# Database backup
/opt/devops-arsenal/scripts/backup/database-backup.sh --all
```

Add to crontab:
```bash
0 2 * * * /root/daily-maintenance.sh >> /var/log/maintenance.log 2>&1
```

### Deployment Pipeline Integration

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  script:
    - ./devops-arsenal/scripts/deployment/zero-downtime-deploy.sh \
        --app $CI_PROJECT_NAME \
        --version $CI_COMMIT_TAG \
        --environment production
    - ./devops-arsenal/scripts/deployment/health-check-monitor.sh \
        --url https://myapp.com/health \
        --timeout 300
```

### Monitoring Setup

```bash
# Install as systemd service
cat > /etc/systemd/system/resource-monitor.service <<EOF
[Unit]
Description=Resource Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/devops-arsenal/scripts/monitoring/resource-monitor.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable resource-monitor
systemctl start resource-monitor
```

## Advanced Features

### Parallel Execution

Run multiple health checks in parallel:

```bash
#!/bin/bash
# Parallel server checks

servers=("web1" "web2" "db1" "cache1")

for server in "${servers[@]}"; do
    (
        ssh $server "/opt/devops-arsenal/scripts/server-management/server-health-check.sh"
    ) &
done

wait
echo "All checks completed"
```

### Integration with Ansible

```yaml
# playbook.yml
- name: Run health check on all servers
  hosts: all
  tasks:
    - name: Execute health check script
      script: scripts/server-management/server-health-check.sh
      register: health_check

    - name: Send results to Slack
      slack:
        token: "{{ slack_token }}"
        msg: "{{ health_check.stdout }}"
```

### Custom Alerts

```python
# scripts/monitoring/alert-sender.py

from alerts import send_slack, send_email, send_telegram

def send_alert(message, severity='warning'):
    if severity == 'critical':
        send_slack(message, channel='#alerts-critical')
        send_email(message, to='oncall@example.com')
        send_telegram(message, chat_id='123456')
    else:
        send_slack(message, channel='#alerts')
```

## Best Practices

1. **Always test in staging first**
2. **Use dry-run mode** when available
3. **Review logs** after execution
4. **Set up monitoring** for critical scripts
5. **Keep backups** before running destructive operations
6. **Use version control** for script customizations
7. **Document modifications** in comments
8. **Implement proper error handling**

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/**/*.sh
```

### Python Dependencies Missing

```bash
pip3 install -r requirements.txt
```

### Cron Job Not Running

```bash
# Check cron logs
grep CRON /var/log/syslog

# Verify crontab
crontab -l
```

## Contributing

Contributions are welcome! To add a new script:

1. Fork the repository
2. Create feature branch
3. Add script to appropriate category
4. Include comprehensive documentation
5. Add usage examples
6. Submit pull request

## Support

- **Issues**: [GitHub Issues](https://github.com/IskandarKurbonov/devops-arsenal/issues)
- **Email**: kurbonoviskandar23@gmail.com
- **Telegram**: [@iskandar2318](https://t.me/iskandar2318)

## License

MIT License - see [LICENSE](LICENSE) file

## Author

**Iskandar Kurbonov**
- DevOps Engineer
- Automation Specialist
- Location: Tashkent, Uzbekistan

---

⭐ Star this repository if you find it useful!

**"Automate everything that can be automated"**
