# Rundeck Streamlit Deployment System

A comprehensive CI/CD platform for deploying Streamlit applications from GitHub repositories to Google Cloud Run with automatic webhook-based redeployment.

## Features

- **One-Click Deployment**: Deploy Streamlit apps from GitHub to Cloud Run through Rundeck web interface
- **Automatic CI/CD**: GitHub webhooks trigger automatic redeployments on code pushes
- **Multi-Branch Support**: Deploy different branches as separate services
- **Flexible Branch Detection**: Auto-detect default branch or specify custom branch
- **Secure Secrets Management**: Secure secrets file upload via Rundeck
- **Resource Configuration**: DevOps-managed memory and CPU defaults
- **Access Control**: Role-based permissions for data scientists and administrators
- **Audit Trail**: Complete deployment history and logging

## Documentation

📚 **[User Guide](docs/user-guide.md)** - Complete step-by-step guide for deploying Streamlit applications (with screenshots)

📋 **Setup Guides:**
- [Google Cloud Setup](docs/google-cloud-setup.md) - Service account and API configuration
- [GitHub Setup](docs/github-setup.md) - Personal access token creation
- [Webhook Setup](docs/WEBHOOK-SETUP.md) - Automatic redeployment configuration

## Quick Start

### Prerequisites

1. **Google Cloud Project** with enabled APIs (Cloud Run, Artifact Registry, Container Registry)
2. **Google Cloud Service Account** with required permissions
3. **GitHub Personal Access Token** with webhook and repository access

> 📋 See the setup guides above for detailed configuration instructions

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd streamlit-rundeck
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your Google Cloud and GitHub configuration
   ```

3. **Start the system**:
   ```bash
   ./start.sh -d
   ```
   
   **Alternative**: Use Docker Compose directly (requires manual Docker group ID setup):
   ```bash
   DOCKER_GID=$(getent group docker | cut -d: -f3) docker compose up -d
   ```

4. **Access Rundeck**:
   - URL: http://localhost:4440
   - Default credentials: admin/admin

5. **Create the Streamlit project**:
   - Click the "+" button or "New Project" link on the Rundeck home page
   - Project Name: `streamlit-deployments`
   - Description: `Streamlit Application Deployment Pipeline for Data Scientists`
   - Click "Create"

6. **Import job definitions**:
   - Navigate to the `streamlit-deployments` project
   - In the Jobs section, click **"Upload a Job definition"**
   - Upload `rundeck-config/streamlit-deploy-job.yml`
   - Repeat to upload `rundeck-config/webhook-streamlit-redeploy.yml`

7. **Configure webhooks** (optional):
   - Follow the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md) to enable automatic redeployment
   - This allows GitHub code pushes to trigger automatic app updates

### Updating Job Definitions

When you modify job definition files (e.g., `rundeck-config/streamlit-deploy-job.yml`), you need to update them in Rundeck:

#### Option 1: Re-import through Rundeck Web UI (Recommended)
1. **Access Rundeck**: http://localhost:4440
2. **Navigate to Project**: Go to the `streamlit-deployments` project
3. **Jobs Section**: Click on "Jobs" in the left sidebar
4. **Find Existing Job**: Locate the job you want to update (e.g., "Deploy Streamlit App")
5. **Job Actions**: Click the gear icon → "Upload Definition"
6. **Upload File**: Select your updated job definition file
7. **Update Strategy**: Choose "Update" to replace the existing job

#### Option 2: Use Rundeck CLI (if available)
```bash
# From within the Rundeck container
docker compose exec rundeck rd jobs load -f /rundeck-config/streamlit-deploy-job.yml --project streamlit-deployments
```

#### Option 3: Delete and Re-create
1. **Delete existing job** through Rundeck UI (gear icon → "Delete this Job")
2. **Re-import** the updated job definition file using the upload process

**Note**: Option 1 is recommended as it preserves job execution history and is safer for production environments.

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Google Cloud Configuration
GCP_PROJECT_ID=your-gcp-project-id
ARTIFACT_REGISTRY_URL=your-region-docker.pkg.dev/your-project/your-repo

# GitHub Configuration  
GITHUB_API_TOKEN=your-github-token

# Rundeck Configuration
RUNDECK_WEBHOOK_SECRET=your-webhook-secret
RUNDECK_ADMIN_PASSWORD=your-admin-password
BASE_URL=http://localhost:4440
WEBHOOK_URL=https://your-domain.com/api/53/webhook/your-auth-key#streamlit-redeploy

# Database Configuration (optional - uses defaults if not specified)
DB_HOST=db
DB_NAME=rundeck
DB_USER=rundeck
DB_PASSWORD=rundeckpassword

# Infrastructure Defaults (DevOps Configuration)
DEFAULT_REGION=us-central1
DEFAULT_MEMORY=1Gi
DEFAULT_CPU=1
```

## Usage

### For End Users (Data Scientists)

📚 **[Complete User Guide](docs/user-guide.md)** provides step-by-step instructions with screenshots for:
- Deploying your first Streamlit application
- Multi-branch deployments (production, staging, feature branches)
- Understanding automatic redeployment
- Troubleshooting common issues
- System limitations and workarounds

### Quick Reference

**Deploy a Streamlit App:**
1. Access Rundeck → `streamlit-deployments` project → Jobs → "Deploy Streamlit App"
2. Fill required parameters: GitHub URL, App Name, Main File (default: `app.py`)
3. Optional: Target Branch, Secrets File upload
4. Run job and monitor logs for deployment URL

**Key Features:**
- **One-Click Deployment**: Simple web interface for non-technical users
- **Multi-Branch Support**: Deploy different branches as separate services
- **Automatic CI/CD**: GitHub webhooks trigger redeployments on code pushes
- **Secure Secrets**: Upload sensitive configuration files safely

### For Administrators

**Webhook Setup**: Follow the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md) to configure automatic redeployment.

**Important**: When configuring webhooks in Rundeck UI, use `-webhook_payload ${raw}` in the Options field for proper JSON payload handling.

## Architecture

### Components

- **Rundeck**: Job orchestration and web interface
- **PostgreSQL**: Deployment metadata storage
- **Docker**: Container runtime for builds
- **Google Cloud SDK**: Cloud Run and Artifact Registry integration
- **Git**: Repository cloning and branch management

### File Structure

```
streamlit-rundeck/
├── compose.yml                    # Docker Compose configuration
├── Dockerfile.rundeck             # Extended Rundeck image
├── start.sh                       # Portable startup script (auto-detects Docker GID)
├── get-docker-gid.sh             # Docker group ID detection utility
├── scripts/                       # Deployment and management scripts
│   ├── deploy-streamlit.sh        # Main deployment logic
│   ├── create-webhook.sh          # GitHub webhook creation
│   ├── webhook-redeploy.sh        # Webhook-triggered redeployment
│   ├── store-deployment.sh        # Metadata storage
│   ├── get-deployment.sh          # Metadata retrieval
│   └── validate-*.sh              # Input validation scripts
├── templates/                     # Dockerfile templates
├── rundeck-config/                # Rundeck job and access control
├── docs/                         # Documentation including webhook setup guide
├── sql/                          # Database schema
└── gcloud/                       # Service account keys
```

### Database Schema

The system uses PostgreSQL tables for deployment tracking:

- **deployments**: Main deployment metadata
- **deployment_history**: Audit trail for all deployments

## Production Deployment

### Infrastructure

Production runs on VM `10.0.0.3` with a different architecture than the repo's `compose.yml`:

- **Rundeck** uses the vanilla `rundeck/rundeck:5.8.0` image (not the custom Dockerfile).
- **Scripts execute on the host VM** via SSH, not inside the Rundeck container.
- Rundeck SSHs into `streamlit-rundeck@10.0.0.3` using a stored private key.
- All required tools (`gcloud`, `docker`, `git`, `psql`, `jq`) are installed on the host.

```
┌─ VM 10.0.0.3 ────────────────────────────────────────────────┐
│                                                                │
│  Docker containers:                                            │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  rundeck          (rundeck/rundeck:5.8.0, port 4440)    │ │
│  │  rundeck-postgres-1  (postgres, port 5432)              │ │
│  │  nginx-proxy-manager (ports 80, 81, 443)                │ │
│  └──────────────────────────────────────────────────────────┘ │
│       │                                                        │
│       │ SSH (streamlit-rundeck@10.0.0.3)                       │
│       ▼                                                        │
│  Host: /home/streamlit-rundeck/streamlit-rundeck/              │
│    scripts/deploy-streamlit.sh                                 │
│    scripts/webhook-redeploy.sh                                 │
│    Tools: gcloud, docker, git, psql, jq                        │
│       │                              │                         │
│       ▼                              ▼                         │
│  GitHub (clone + webhooks)    GCP Cloud Run (europe-west1)     │
└────────────────────────────────────────────────────────────────┘
```

### Prod vs Repo Differences

| Aspect | Repo (compose.yml) | Production |
|--------|-------------------|------------|
| Rundeck image | Custom `Dockerfile.rundeck` (tools baked in) | Vanilla `rundeck/rundeck:5.8.0` |
| Script execution | Local (inside container) | SSH to host `streamlit-rundeck@10.0.0.3` |
| Rundeck version | 5.14.1 | 5.8.0 |
| DB credentials | `rundeck` / `rundeck` / `rundeckpassword` | `akvo-rundeck` / `akvo-rundeck-db` / custom |
| Reverse proxy | None | Nginx Proxy Manager |
| URL | `http://localhost:4440` | `https://rundeck.internal.akvo.org` |

### Rundeck Node Configuration

Rundeck has two nodes configured:

| Node | Hostname | User | Auth Method |
|------|----------|------|-------------|
| Rundeck server (local) | container ID | rundeck | local |
| vm-streamlit-deployment | 10.0.0.3 | streamlit-rundeck | SSH key (`keys/project/streamlit-deployments/streamlit-vm-key`) |

### Access

- **Rundeck UI**: `https://rundeck.internal.akvo.org`
- **VM SSH**: `ssh akvo@10.0.0.3` then `sudo -u streamlit-rundeck -i`
- **DB query**: `docker exec rundeck-postgres-1 psql -U akvo-rundeck -d akvo-rundeck-db`

### Deployed Apps

All apps run on Cloud Run in `europe-west1` with 1Gi memory / 1 CPU.

| App Name | GitHub Repo | Branch | Custom Domain | Last Updated |
|----------|-------------|--------|---------------|--------------|
| agriconnect-stats | akvo/agriconnect-stats | main | - | 2026-04-07 |
| acorn-dqm-test | akvo/acorn-dqm-streamlit | version-two | - | 2026-04-06 |
| crop-monitor | akvo/spamApp | main | crop-monitor.data.akvotest.org | 2026-04-05 |
| nbd-maps | akvo/nbd-streamlit | main | - | 2026-03-31 |
| zhdl-secrets-test | akvo/spamApp | use-pytorch-non-gpu | zhdl-secrets-test.data.akvotest.org | 2026-03-30 |
| aswa-rmi-streamlit | akvo/aswa-rmi-steamlit | main | - | 2026-03-02 |
| nbd-data | akvo/nbd-streamlit | main | - | 2026-01-21 |
| idh-mock-streamlit | akvo/idh-mock-streamlit | main | - | 2025-12-17 |
| acorn-backup | akvo/acorn-dqm-streamlit | backup | - | 2025-11-10 |
| new-streamlit-ok | akvo/streamlit-test-app | main | - | 2025-10-02 |
| oak-wash-sb | akvo/oak-india-streamlit | main | - | 2025-09-13 |
| test-the-streamlit | akvo/streamlit-test-app | main | - | 2025-09-11 |

## Security

### Access Control

- **Data Scientists**: Execute-only permissions for deployment jobs
- **Administrators**: Full system access
- **Webhook User**: Limited to webhook job execution

### Security Features

- Webhook authentication via Rundeck auth keys
- GitHub API token with minimal permissions
- Service account principle of least privilege
- Secure secrets handling through Rundeck
- Input validation and sanitization

## Monitoring

### Deployment Tracking

- Real-time deployment logs
- Success/failure metrics
- Deployment history
- Resource utilization monitoring

### Health Checks

- Cloud Run service health monitoring
- Database connectivity checks
- Webhook delivery verification

## Troubleshooting

### Common Issues

1. **Docker build failures**: Check requirements.txt and Dockerfile generation
2. **Cloud Run deployment errors**: Verify service account permissions
3. **Webhook not triggering**: Check GitHub token permissions and webhook configuration
   - See the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md) for detailed troubleshooting
4. **Database connection errors**: Ensure PostgreSQL is running and accessible

### Logs

- Rundeck logs: `docker compose logs rundeck`
- Database logs: `docker compose logs db`
- Deployment logs: Available in Rundeck web interface

## Development

### Adding New Features

1. Create scripts in `scripts/` directory
2. Update job definitions in `rundeck-config/`
3. Modify database schema if needed
4. Update documentation

### Testing

1. Deploy a sample Streamlit application
2. Verify webhook creation and functionality
3. Test multi-branch deployment scenarios
4. Validate access control permissions

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs for error details
3. Verify configuration and permissions
4. Test with a simple Streamlit application first

## License

This project is licensed under the MIT License - see the LICENSE file for details.
