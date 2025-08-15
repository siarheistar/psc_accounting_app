# Render.com Deployment Guide for PSC Accounting

This guide provides complete instructions for deploying the PSC Accounting application to Render.com with AWS S3 integration.

## Environment Variables Configuration

Your Render.com environment variables are correctly configured. Here's how they map to the application:

### ✅ Required AWS S3 Variables (Already Set)

| Render.com Variable | Application Usage | Status |
|-------------------|------------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS S3 authentication | ✅ Set |
| `AWS_SECRET_ACCESS_KEY` | AWS S3 authentication | ✅ Set |
| `AWS_REGION` | S3 bucket region | ✅ Set |
| `AWS_S3_BUCKET` | S3 bucket name | ✅ Set |

### 📋 Additional Required Variables

Add these environment variables to your Render.com service:

#### Database Configuration
```env
DB_HOST=your-postgres-host
DB_NAME=your-database-name
DB_USER=your-database-user
DB_PASSWORD=your-database-password
DB_PORT=5432
DB_SSL_MODE=require
```

#### Application Configuration
```env
ENVIRONMENT=production
STORAGE_BACKEND=s3
API_HOST=0.0.0.0
API_PORT=8000
```

#### Security (Generate secure keys)
```env
JWT_SECRET=your-jwt-secret-key
API_SECRET_KEY=your-api-secret-key
```

#### CORS (Adjust for your domain)
```env
CORS_ORIGINS=https://your-frontend-domain.com,https://your-app.onrender.com
```

## Render.com Service Configuration

### 1. Web Service Settings
```yaml
# render.yaml (if using Infrastructure as Code)
services:
  - type: web
    name: psc-accounting-api
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: ENVIRONMENT
        value: production
      - key: STORAGE_BACKEND
        value: s3
      # Add all other environment variables here
```

### 2. Manual Setup (Web Interface)
1. **Service Type**: Web Service
2. **Build Command**: `pip install -r backend/requirements.txt`
3. **Start Command**: `cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT`
4. **Environment**: Python 3
5. **Root Directory**: Leave empty (or set to `backend` if needed)

## Application Features

### ✅ S3 Integration Ready
- **Unicode filename support**: Files with international characters work correctly
- **Automatic fallback**: Falls back to local storage if S3 fails
- **Secure metadata handling**: Non-ASCII filenames encoded properly for S3
- **Environment variable detection**: Automatically uses Render.com environment variables

### ✅ Database Support
- **PostgreSQL integration**: Works with Render.com PostgreSQL
- **Connection pooling**: Optimized for production
- **SSL support**: Secure database connections

### ✅ Production Ready
- **Environment detection**: Automatically detects production mode
- **Security features**: Proper CORS, secret management
- **Error handling**: Graceful degradation and error recovery
- **Logging**: Comprehensive logging for debugging

## Deployment Checklist

### Before Deployment
- [ ] Set all required environment variables in Render.com
- [ ] Verify AWS S3 bucket `psc-accounting` exists and is accessible
- [ ] Ensure PostgreSQL database is created and accessible
- [ ] Generate secure JWT and API secret keys

### After Deployment
- [ ] Test health endpoint: `GET /health`
- [ ] Verify S3 connection: `GET /storage/status`
- [ ] Test file upload with Unicode filename
- [ ] Check application logs for any errors

## Testing S3 Integration

### Test Endpoints
```bash
# Health check
curl https://your-app.onrender.com/health

# Storage status
curl https://your-app.onrender.com/storage/status

# Upload test (replace with actual company_id)
curl -X POST "https://your-app.onrender.com/attachments/upload?entity_type=invoice&entity_id=1&company_id=1" \
  -F "file=@test.pdf" \
  -F "description=Test upload"
```

### Expected Responses
```json
// Health check
{
  "status": "healthy",
  "storage_backend": "s3"
}

// Storage status
{
  "storage_backend": "s3",
  "s3_bucket": "psc-accounting",
  "s3_region": "us-west-2",
  "connection_status": "connected"
}
```

## Security Best Practices

### ✅ Already Implemented
- AWS credentials never stored in code
- Environment variables used for all secrets
- S3 server-side encryption enabled
- CORS properly configured
- Input validation and sanitization

### ⚠️ Additional Recommendations
1. **Rotate AWS keys** every 90 days
2. **Monitor S3 usage** and costs
3. **Set up bucket policies** for additional security
4. **Enable S3 versioning** for backup
5. **Configure CloudTrail** for audit logs

## Troubleshooting

### Common Issues

#### S3 Connection Failed
```
❌ [S3 Storage] Failed to initialize: NoCredentialsError
```
**Solution**: Check AWS environment variables are set correctly

#### Bucket Access Denied
```
❌ [S3 Storage] Access denied to bucket psc-accounting
```
**Solution**: Verify AWS user has proper S3 permissions

#### Application Won't Start
```
❌ Missing required environment variables: ['DB_HOST', 'DB_PASSWORD']
```
**Solution**: Set all required database environment variables

### Debug Commands
```bash
# Check environment variables (in Render.com shell)
env | grep AWS
env | grep DB_

# Test AWS credentials
python -c "import boto3; print(boto3.client('s3').list_buckets())"

# Check S3 bucket access
python -c "import boto3; s3=boto3.client('s3'); print(s3.head_bucket(Bucket='psc-accounting'))"
```

## Monitoring

### Key Metrics to Monitor
- **Application health**: `/health` endpoint status
- **S3 upload success rate**: Check logs for upload failures
- **Database connections**: Monitor connection pool usage
- **Response times**: API endpoint performance
- **Error rates**: Application and S3 error logs

### Render.com Monitoring
- Use Render.com's built-in metrics dashboard
- Set up log alerts for critical errors
- Monitor resource usage (CPU, memory)

## Environment Variable Reference

### Complete List
```env
# Application
ENVIRONMENT=production
DEBUG=false
API_HOST=0.0.0.0
API_PORT=8000

# Storage
STORAGE_BACKEND=s3
UPLOAD_DIR=uploads

# AWS S3
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-west-2
AWS_S3_BUCKET=psc-accounting
S3_BUCKET=psc-accounting

# Database
DB_HOST=dpg-xxxxxxxxxxxxx-a.oregon-postgres.render.com
DB_NAME=pscdb
DB_USER=pscdb_user
DB_PASSWORD=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DB_PORT=5432
DB_SSL_MODE=require

# Security
JWT_SECRET=your-secure-jwt-secret-here
API_SECRET_KEY=your-secure-api-secret-here
CORS_ORIGINS=https://your-frontend.com,https://your-app.onrender.com

# Optional
LOG_LEVEL=INFO
```

## Success Indicators

When deployment is successful, you should see:
- ✅ Health endpoint returns `{"status": "healthy", "storage_backend": "s3"}`
- ✅ Application logs show S3 connection successful
- ✅ File uploads work with Unicode filenames
- ✅ Database operations complete successfully
- ✅ No error messages in Render.com logs

Your application is now ready for production use with full S3 integration! 🚀