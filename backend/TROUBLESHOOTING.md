# PSC Accounting - Troubleshooting Guide

## Common Installation Issues

### 1. Pip Package Conflicts Error

**Error Message:**
```
ERROR: Error while checking for conflicts. Please file an issue on pip's issue tracker
TypeError: expected string or bytes-like object, got 'NoneType'
```

**Root Cause:** Corrupted package metadata in your Python environment.

**Solutions (in order of preference):**

#### Option A: Use Virtual Environment (Recommended)
```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate     # On Windows

# Install packages
pip install boto3 botocore
```

#### Option B: Force Reinstall Packages
```bash
pip install --force-reinstall boto3 botocore
```

#### Option C: Use User Installation
```bash
pip install --user boto3 botocore
```

#### Option D: Reset Pip Cache
```bash
pip cache purge
pip install boto3 botocore
```

#### Option E: Use conda (if available)
```bash
conda install boto3 botocore
```

### 2. AWS Credentials Issues

**Error Message:**
```
NoCredentialsError: Unable to locate credentials
```

**Solutions:**

#### Option A: Environment Variables
```bash
export AWS_ACCESS_KEY_ID=your_key_here
export AWS_SECRET_ACCESS_KEY=your_secret_here
export AWS_REGION=us-east-1
```

#### Option B: AWS Credentials File
Create `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = your_key_here
aws_secret_access_key = your_secret_here

[psc-accounting]
aws_access_key_id = your_key_here
aws_secret_access_key = your_secret_here
```

Create `~/.aws/config`:
```ini
[default]
region = us-east-1

[profile psc-accounting]
region = us-east-1
```

#### Option C: IAM Roles (Production)
Use IAM roles for EC2 instances or ECS tasks instead of access keys.

### 3. S3 Bucket Access Issues

**Error Message:**
```
AccessDenied: Access Denied
```

**Solutions:**

#### Check Bucket Policy
Ensure your IAM user/role has these permissions:
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

#### Verify Bucket Exists
```bash
aws s3 ls s3://psc-accounting
```

### 4. Database Connection Issues

**Error Message:**
```
Connection refused / Could not connect to database
```

**Solutions:**

#### Check Database Configuration
Verify your `.env` file has correct database settings:
```bash
DATABASE_URL=postgresql://username:password@host:port/database
```

#### Test Database Connection
```bash
psql -h your_host -U your_user -d your_database -c "SELECT 1;"
```

#### Run Database Migrations
```bash
psql -d your_database -f migration_s3_support.sql
```

### 5. Import Errors

**Error Message:**
```
ModuleNotFoundError: No module named 'xxx'
```

**Solutions:**

#### Check Python Path
```python
import sys
print(sys.path)
```

#### Install Missing Dependencies
```bash
pip install -r requirements.txt
```

#### Verify Virtual Environment
```bash
which python
which pip
```

### 6. File Permission Issues

**Error Message:**
```
PermissionError: [Errno 13] Permission denied
```

**Solutions:**

#### Check File Permissions
```bash
ls -la uploads/
chmod 755 uploads/
```

#### Check Directory Ownership
```bash
sudo chown -R $USER:$USER uploads/
```

### 7. Network/Firewall Issues

**Error Message:**
```
ConnectTimeoutError / EndpointConnectionError
```

**Solutions:**

#### Check Internet Connection
```bash
ping s3.amazonaws.com
```

#### Check Corporate Firewall
- Ensure ports 443 (HTTPS) and 80 (HTTP) are open
- Check if proxy settings are needed

#### Test with Different Region
Try a different AWS region:
```bash
export AWS_REGION=us-west-2
```

## Testing Commands

### Quick Health Check
```bash
# Test S3 integration
python test_s3_integration.py

# Test API endpoints
curl http://localhost:8000/storage/info
curl http://localhost:8000/storage/test-s3
```

### Detailed Diagnostics
```bash
# Check Python environment
python -c "import sys; print(sys.version); print(sys.executable)"

# Check installed packages
pip list | grep boto

# Check AWS CLI (if installed)
aws configure list
aws s3 ls
```

### Environment Verification
```bash
# Check environment variables
env | grep AWS
env | grep STORAGE

# Check file structure
ls -la uploads/attachments/
```

## Getting Help

### Log Files
Check application logs for detailed error messages:
```bash
tail -f application.log
```

### Debug Mode
Enable debug logging in your `.env`:
```bash
DEBUG=true
VERBOSE_LOGGING=true
```

### API Testing
Use the built-in test endpoints:
```bash
# Storage configuration
curl http://localhost:8000/storage/info

# S3 connection test
curl http://localhost:8000/storage/test-s3

# Storage statistics
curl http://localhost:8000/attachments/stats
```

### Contact Support
If issues persist:
1. Run the test script: `python test_s3_integration.py`
2. Check the error logs
3. Verify AWS credentials and permissions
4. Test with a simple file upload through the API

## Prevention

### Best Practices
1. Always use virtual environments for Python projects
2. Keep AWS credentials secure and rotate them regularly
3. Use IAM roles instead of access keys in production
4. Set up proper monitoring and logging
5. Test in development before deploying to production

### Regular Maintenance
1. Update dependencies regularly: `pip install --upgrade -r requirements.txt`
2. Monitor S3 costs and usage
3. Clean up orphaned files periodically
4. Backup important configurations
