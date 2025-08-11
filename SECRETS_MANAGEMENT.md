# 🔐 Secrets Management Guide for PSC Accounting App

This guide explains how to securely manage database credentials and other sensitive configuration for the PSC Accounting application.

## 🚨 Security Overview

**NEVER commit the following to version control:**
- `.env` files containing actual credentials
- Database passwords, API keys, or secrets
- Service account keys or certificates
- Any file containing production credentials

## 📁 File Structure

```
backend/
├── .env                 # Your actual secrets (NEVER commit)
├── .env.example         # Template file (safe to commit)
├── env_config.py        # Configuration management
└── database.py          # Database connection logic
```

## 🔧 Setup Instructions

### 1. Create Your Environment File

```bash
# Navigate to backend directory
cd backend/

# Copy the example file
cp .env.example .env

# Edit with your actual credentials
nano .env  # or use your preferred editor
```

### 2. Configure Database Credentials

Edit your `.env` file:

```bash
# Database Configuration
DB_HOST=your-actual-database-host.amazonaws.com
DB_PORT=5432
DB_NAME=your-database-name
DB_USER=your-database-username
DB_PASSWORD=your-actual-secure-password
```

### 3. Generate Secure Keys

For production, generate strong secret keys:

```bash
# Generate JWT secret (32+ characters)
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate API secret key
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

## 🔒 Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | Database hostname | `mydb.rds.amazonaws.com` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `psc_accounting` |
| `DB_USER` | Database username | `postgres` |
| `DB_PASSWORD` | Database password | `SecurePassword123!` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_HOST` | API host binding | `0.0.0.0` |
| `API_PORT` | API port | `8000` |
| `DEBUG` | Enable debug mode | `true` |
| `ENVIRONMENT` | Environment type | `development` |
| `STORAGE_MODE` | File storage mode | `local` |
| `JWT_SECRET` | JWT signing key | *Required in production* |

## 🌍 Environment-Specific Configuration

### Development Environment

```bash
# .env file for development
ENVIRONMENT=development
DEBUG=true
DB_HOST=localhost
DB_PASSWORD=dev_password_123
```

### Production Environment

```bash
# .env file for production
ENVIRONMENT=production
DEBUG=false
DB_HOST=prod-db.amazonaws.com
DB_PASSWORD=ultra_secure_production_password_xyz789
JWT_SECRET=generated_32_char_secret_key
API_SECRET_KEY=another_generated_secret_key
```

### Staging Environment

```bash
# .env.staging file
ENVIRONMENT=staging
DEBUG=false
DB_HOST=staging-db.amazonaws.com
DB_PASSWORD=staging_password_abc456
```

## 📊 Using Environment Configuration in Code

### Backend Python Usage

```python
from env_config import env_config

# Get database configuration
db_host = env_config.get_config('DB_HOST')
db_password = env_config.get_config('DB_PASSWORD')

# Check environment
if env_config.is_production():
    # Production-specific logic
    pass

# Get database URL
db_url = env_config.get_database_url()
```

### Validation and Error Handling

The system automatically validates required environment variables:

```python
# This will exit with error if required vars are missing
from env_config import env_config

# Manual validation
if not env_config.validate_database_connection():
    print("❌ Database configuration is invalid")
```

## 🚀 Deployment Best Practices

### 1. Local Development

```bash
# Use .env file (never commit)
cp .env.example .env
# Edit .env with local database credentials
```

### 2. Docker Deployment

```dockerfile
# Dockerfile - use environment variables
FROM python:3.9
# Don't copy .env file
# Pass environment variables at runtime
ENV DB_HOST=${DB_HOST}
ENV DB_PASSWORD=${DB_PASSWORD}
```

```bash
# Run with environment variables
docker run -e DB_HOST=prod-host -e DB_PASSWORD=secret myapp
```

### 3. Cloud Deployment (AWS, GCP, Azure)

#### AWS Elastic Beanstalk
```bash
# Set via EB console or CLI
eb setenv DB_PASSWORD=your-secret-password
```

#### Docker Compose
```yaml
# docker-compose.yml
version: '3.8'
services:
  backend:
    build: .
    environment:
      - DB_HOST=${DB_HOST}
      - DB_PASSWORD=${DB_PASSWORD}
    env_file:
      - .env  # For local development only
```

#### Kubernetes
```yaml
# secrets.yaml (encrypted at rest)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  password: <base64-encoded-password>
```

### 4. CI/CD Pipeline

```yaml
# GitHub Actions example
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        env:
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
        run: |
          # Deploy with secrets from GitHub Secrets
```

## 🔍 Security Checklist

### ✅ Development
- [ ] `.env` file is in `.gitignore`
- [ ] Never commit actual credentials
- [ ] Use `.env.example` for templates
- [ ] Different passwords for each environment

### ✅ Production  
- [ ] Strong, unique passwords (20+ characters)
- [ ] Environment variables set via deployment platform
- [ ] No `.env` files on production servers
- [ ] Database uses SSL/TLS encryption
- [ ] Regular credential rotation
- [ ] Monitoring for credential exposure

### ✅ Team Collaboration
- [ ] Share `.env.example` template only
- [ ] Use secure channels for sharing actual credentials
- [ ] Document credential storage locations
- [ ] Regular access reviews

## 🚨 Emergency Procedures

### If Credentials Are Accidentally Committed

1. **Immediately rotate all exposed credentials**
2. **Remove from git history:**
   ```bash
   git filter-branch --force --index-filter \
   'git rm --cached --ignore-unmatch backend/.env' \
   --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push to remove from remote:**
   ```bash
   git push origin --force --all
   ```
4. **Notify team and update all environments**

### If Production Database Is Compromised

1. **Change database password immediately**
2. **Update all deployment configurations**  
3. **Restart all application instances**
4. **Review access logs**
5. **Consider database migration if needed**

## 📞 Support

- For credential issues: Check logs via `python -m env_config`
- For database connection issues: Verify credentials and network access
- For deployment issues: Ensure environment variables are set correctly

## 🔗 Additional Resources

- [12-Factor App Methodology](https://12factor.net/config)
- [OWASP Secrets Management](https://owasp.org/www-community/vulnerabilities/Insufficiently_Protected_Credentials)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)