# PSC Accounting - AWS S3 Integration

## Overview

The PSC Accounting app now supports both local file storage and AWS S3 cloud storage for file attachments. You can configure which storage backend to use via environment variables, making it easy to switch between local storage for development/testing and S3 for production deployments.

## Features

### 🌟 **Dual Storage Support**
- **Local Storage**: Files stored in local `uploads/` directory (default for development)
- **AWS S3 Storage**: Files stored in AWS S3 bucket with organized structure
- **Seamless Switching**: Change storage backend via environment variables
- **Migration Tools**: Built-in endpoints to migrate between storage systems

### 🛡️ **Security & Organization**
- **Company Isolation**: Files organized by company ID for multi-tenant security
- **Entity-based Structure**: Files organized by transaction type (invoice, expense, payroll, bank_statement)
- **Date Organization**: Files organized by upload date for easy browsing
- **Server-side Encryption**: S3 files encrypted at rest with AES256
- **Secure Access**: S3 presigned URLs for secure file access

### 📊 **Management & Monitoring**
- **Storage Statistics**: View usage by company, storage backend, and file category
- **Migration Tools**: Migrate existing local files to S3 with progress tracking
- **Cleanup Tools**: Remove orphaned files and optimize storage usage
- **Connection Testing**: Verify S3 connectivity and permissions

## Configuration

### Environment Variables

Create a `.env` file in the backend directory with your configuration:

```bash
# Storage Backend Configuration
STORAGE_BACKEND=s3              # "local" or "s3"

# AWS S3 Configuration (required for S3 backend)
S3_BUCKET=psc-accounting        # Your S3 bucket name
AWS_REGION=us-east-1           # AWS region
AWS_ACCESS_KEY_ID=your_key     # AWS access key
AWS_SECRET_ACCESS_KEY=your_secret # AWS secret key

# Alternative: Use IAM roles (recommended for production)
# Don't set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
# if using IAM roles or EC2 instance profiles
```

### AWS S3 Setup

#### 1. Create S3 Bucket

```bash
# Using AWS CLI
aws s3 mb s3://psc-accounting --region us-east-1

# Or use the AWS Console to create bucket
```

#### 2. Set Bucket Permissions

The application requires the following S3 permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::psc-accounting",
                "arn:aws:s3:::psc-accounting/*"
            ]
        }
    ]
}
```

#### 3. CORS Configuration (for web access)

```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "POST", "PUT", "DELETE"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": ["Content-Length", "Content-Type"],
        "MaxAgeSeconds": 3600
    }
]
```

## File Organization

### S3 Structure

Files in S3 are organized with the following structure:

```
s3://psc-accounting/
└── attachments/
    ├── invoice/
    │   └── company_1/
    │       └── 2025-08-15/
    │           ├── 143022_a1b2c3d4_receipt.pdf
    │           └── 143055_e5f6g7h8_invoice.pdf
    ├── expense/
    │   └── company_1/
    │       └── 2025-08-15/
    │           └── 144012_i9j0k1l2_receipt.jpg
    ├── payroll/
    │   └── company_2/
    │       └── 2025-08-15/
    │           └── 145033_m3n4o5p6_payslip.pdf
    └── bank_statement/
        └── company_1/
            └── 2025-08-15/
                └── 146044_q7r8s9t0_statement.pdf
```

### Local Structure (for testing)

```
uploads/
└── attachments/
    ├── invoice/
    │   └── company_1/
    │       └── 2025-08-15/
    │           └── 143022_a1b2c3d4.pdf
    ├── expense/
    │   └── company_1/
    │       └── 2025-08-15/
    │           └── 144012_i9j0k1l2.jpg
    └── ...
```

## Usage

### Basic File Operations

The same API endpoints work for both storage backends:

```bash
# Upload attachment
curl -X POST "http://localhost:8000/attachments/upload" \
  -F "file=@receipt.pdf" \
  -F "description=Office supplies receipt" \
  "?entity_type=expense&entity_id=123&company_id=1"

# Download attachment
curl -X GET "http://localhost:8000/attachments/download/456?company_id=1" \
  --output downloaded_file.pdf

# List attachments
curl -X GET "http://localhost:8000/attachments/expense/123?company_id=1"

# Delete attachment
curl -X DELETE "http://localhost:8000/attachments/456?company_id=1"
```

### Storage Management

#### Check Storage Configuration

```bash
curl -X GET "http://localhost:8000/storage/info"
```

#### Test S3 Connection

```bash
curl -X GET "http://localhost:8000/storage/test-s3"
```

#### Migrate Local Files to S3

```bash
# Dry run (preview migration)
curl -X POST "http://localhost:8000/storage/migrate-to-s3?dry_run=true"

# Actual migration
curl -X POST "http://localhost:8000/storage/migrate-to-s3"

# Migrate specific company
curl -X POST "http://localhost:8000/storage/migrate-to-s3?company_id=1"
```

#### Storage Usage Statistics

```bash
# Overall statistics
curl -X GET "http://localhost:8000/attachments/stats"

# Usage by company
curl -X GET "http://localhost:8000/storage/usage-by-company"
```

#### Cleanup Storage

```bash
# Clean up orphaned local files
curl -X POST "http://localhost:8000/storage/cleanup?storage_backend=local&orphaned_only=true"

# Clean up specific company's orphaned files
curl -X POST "http://localhost:8000/storage/cleanup?storage_backend=local&company_id=1&orphaned_only=true"
```

## Database Schema Updates

The system includes database migrations to support S3:

```sql
-- Run the migration script
psql -d psc_accounting -f migration_s3_support.sql
```

New columns added to `attachments` table:
- `storage_backend`: 'local' or 's3'
- `s3_bucket`: S3 bucket name (for s3 backend)
- `s3_key`: S3 object key (for s3 backend)
- `updated_at`: Last modification timestamp

## Deployment

### Development (Local Storage)

```bash
# Set environment
export STORAGE_BACKEND=local

# Start the server
python main.py
```

### Production (S3 Storage)

```bash
# Set environment
export STORAGE_BACKEND=s3
export S3_BUCKET=psc-accounting
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# Start the server
python main.py
```

### Docker Deployment

```dockerfile
# In your Dockerfile
ENV STORAGE_BACKEND=s3
ENV S3_BUCKET=psc-accounting
ENV AWS_REGION=us-east-1
```

Or using docker-compose:

```yaml
# docker-compose.yml
services:
  api:
    environment:
      - STORAGE_BACKEND=s3
      - S3_BUCKET=psc-accounting
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
```

## Monitoring & Troubleshooting

### Health Checks

```bash
# Check S3 connection
curl -X GET "http://localhost:8000/storage/test-s3"

# Check storage statistics
curl -X GET "http://localhost:8000/storage/info"
```

### Common Issues

#### S3 Connection Failures
- Verify AWS credentials are correct
- Check bucket exists and is accessible
- Verify IAM permissions include required S3 actions
- Check network connectivity to AWS

#### Migration Issues
- Ensure sufficient S3 permissions
- Check local file permissions
- Monitor S3 costs during large migrations
- Use dry-run to estimate migration size

#### File Not Found Errors
- Check storage backend configuration
- Verify database records match file locations
- Run cleanup to remove orphaned database records

### Logging

The application provides detailed logging for storage operations:

```bash
# View logs for S3 operations
tail -f application.log | grep "S3 Storage"

# View logs for migration operations
tail -f application.log | grep "Migration"
```

## Cost Optimization

### S3 Storage Classes

Consider using different S3 storage classes for cost optimization:

- **Standard**: Frequently accessed files (recent uploads)
- **Standard-IA**: Infrequently accessed files (older attachments)
- **Glacier**: Long-term archival (compliance documents)

### Lifecycle Policies

Set up S3 lifecycle policies to automatically transition files:

```json
{
    "Rules": [
        {
            "Id": "PSCAccountingLifecycle",
            "Status": "Enabled",
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 365,
                    "StorageClass": "GLACIER"
                }
            ]
        }
    ]
}
```

## Security Best Practices

1. **Use IAM Roles**: Prefer IAM roles over access keys in production
2. **Bucket Policies**: Restrict bucket access to your application
3. **Encryption**: Enable S3 server-side encryption (done automatically)
4. **Access Logging**: Enable S3 access logging for audit trails
5. **Versioning**: Consider enabling S3 versioning for important documents
6. **Network Security**: Use VPC endpoints for private S3 access

## Support

For issues or questions:

1. Check the application logs for detailed error messages
2. Use the storage management endpoints to diagnose issues
3. Verify AWS credentials and permissions
4. Test S3 connectivity using the built-in test endpoint

## File Types Supported

The system supports all file types with appropriate size limits:

- **Documents**: PDF, DOC, DOCX, TXT, RTF, ODT (up to 50MB)
- **Spreadsheets**: XLS, XLSX, CSV, ODS (up to 50MB)
- **Images**: JPG, PNG, GIF, BMP, TIFF, WEBP (up to 20MB)
- **Archives**: ZIP, RAR, 7Z, TAR, GZ (up to 100MB)
- **Data**: XML, JSON (up to 10MB)
- **Other**: Any file type (up to 25MB default)

Dangerous file types (EXE, BAT, CMD, SCR, VBS, JS) are blocked for security.
