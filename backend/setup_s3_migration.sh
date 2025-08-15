#!/bin/bash

# PSC Accounting - S3 Migration Script
# This script helps migrate your attachment system to use AWS S3

set -e

echo "🚀 PSC Accounting - S3 Migration Setup"
echo "======================================"

# Check if running from correct directory
if [ ! -f "main.py" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "📋 Checking dependencies..."

if ! command_exists python3; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

if ! command_exists pip; then
    echo "❌ pip is required but not installed"
    exit 1
fi

echo "✅ Dependencies check passed"

# Install required packages with error handling
echo "📦 Installing AWS dependencies..."

# Check if we're in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    echo "🐍 Using virtual environment: $VIRTUAL_ENV"
    PYTHON_CMD="python"
    PIP_CMD="pip"
elif [ -f "../.venv/bin/python" ]; then
    echo "🐍 Found virtual environment in parent directory"
    PYTHON_CMD="../.venv/bin/python"
    PIP_CMD="../.venv/bin/pip"
elif [ -f ".venv/bin/python" ]; then
    echo "🐍 Found virtual environment in current directory"
    PYTHON_CMD=".venv/bin/python"
    PIP_CMD=".venv/bin/pip"
else
    echo "🐍 Using system Python"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
fi

# Function to install packages with fallback methods
install_with_fallback() {
    local package=$1
    echo "Installing $package..."
    
    # Try normal pip install first
    if $PIP_CMD install "$package"; then
        echo "✅ Successfully installed $package"
        return 0
    fi
    
    echo "⚠️ Normal pip install failed, trying alternatives..."
    
    # Try with --force-reinstall
    if $PIP_CMD install --force-reinstall "$package"; then
        echo "✅ Successfully installed $package with force-reinstall"
        return 0
    fi
    
    # Try with --no-deps
    if $PIP_CMD install --no-deps "$package"; then
        echo "✅ Successfully installed $package without dependencies"
        return 0
    fi
    
    # Try with user install (only if not in venv)
    if [ -z "$VIRTUAL_ENV" ] && [ ! -f "../.venv/bin/python" ] && [ ! -f ".venv/bin/python" ]; then
        if $PIP_CMD install --user "$package"; then
            echo "✅ Successfully installed $package with --user"
            return 0
        fi
    fi
    
    echo "❌ Failed to install $package with all methods"
    return 1
}

# Try to fix pip issues first
echo "🔧 Attempting to fix pip environment..."
$PYTHON_CMD -m pip install --upgrade pip setuptools wheel || echo "⚠️ Pip upgrade failed, continuing..."

# Install AWS packages
install_with_fallback "boto3"
install_with_fallback "botocore"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚙️ Creating .env file from template..."
    cp env_template.txt .env
    echo "📝 Please edit .env file with your AWS credentials"
else
    echo "✅ .env file already exists"
fi

# Check AWS credentials
echo "🔐 Checking AWS configuration..."

read -p "Do you have AWS credentials configured? (y/n): " has_credentials

if [ "$has_credentials" = "y" ] || [ "$has_credentials" = "Y" ]; then
    # Test AWS connection
    echo "🧪 Testing AWS connection..."
    
    # Get S3 bucket from environment or prompt
    if [ -z "$S3_BUCKET" ]; then
        read -p "Enter your S3 bucket name (default: psc-accounting): " bucket_name
        S3_BUCKET=${bucket_name:-psc-accounting}
    fi
    
    if [ -z "$AWS_REGION" ]; then
        read -p "Enter AWS region (default: us-east-1): " region
        AWS_REGION=${region:-us-east-1}
    fi
    
    # Update .env file with S3 configuration
    echo "📝 Updating .env configuration..."
    
    if grep -q "STORAGE_BACKEND=" .env; then
        sed -i.bak "s/^STORAGE_BACKEND=.*/STORAGE_BACKEND=s3/" .env
    else
        echo "STORAGE_BACKEND=s3" >> .env
    fi
    
    if grep -q "S3_BUCKET=" .env; then
        sed -i.bak "s/^S3_BUCKET=.*/S3_BUCKET=$S3_BUCKET/" .env
    else
        echo "S3_BUCKET=$S3_BUCKET" >> .env
    fi
    
    if grep -q "AWS_REGION=" .env; then
        sed -i.bak "s/^AWS_REGION=.*/AWS_REGION=$AWS_REGION/" .env
    else
        echo "AWS_REGION=$AWS_REGION" >> .env
    fi
    
    echo "✅ Configuration updated"
else
    echo "⚠️ Please configure AWS credentials before proceeding:"
    echo "   1. Create an AWS account"
    echo "   2. Create an S3 bucket"
    echo "   3. Create IAM user with S3 permissions"
    echo "   4. Update .env file with credentials"
    exit 1
fi

# Run database migration
echo "🗄️ Running database migration..."
if command_exists psql; then
    read -p "Enter PostgreSQL database name (default: psc_accounting): " db_name
    db_name=${db_name:-psc_accounting}
    
    read -p "Run database migration now? (y/n): " run_migration
    if [ "$run_migration" = "y" ] || [ "$run_migration" = "Y" ]; then
        psql -d "$db_name" -f migration_s3_support.sql
        echo "✅ Database migration completed"
    else
        echo "⚠️ Remember to run: psql -d $db_name -f migration_s3_support.sql"
    fi
else
    echo "⚠️ psql not found. Please run the database migration manually:"
    echo "   psql -d your_database -f migration_s3_support.sql"
fi

# Test S3 connection
echo "🧪 Testing S3 connection..."
$PYTHON_CMD -c "
import sys
sys.path.append('.')
try:
    from s3_storage import S3StorageManager
    import os
    
    bucket = os.getenv('S3_BUCKET', '$S3_BUCKET')
    region = os.getenv('AWS_REGION', '$AWS_REGION')
    
    print(f'Testing connection to bucket: {bucket} in region: {region}')
    s3_manager = S3StorageManager(bucket_name=bucket, region_name=region)
    print('✅ S3 connection successful!')
    
except Exception as e:
    print(f'❌ S3 connection failed: {e}')
    print('Please check your AWS credentials and bucket configuration')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ S3 connection test passed"
else
    echo "❌ S3 connection test failed"
    echo "Please check your AWS credentials and try again"
    exit 1
fi

# Offer to start migration
if [ -d "uploads/attachments" ] && [ "$(ls -A uploads/attachments 2>/dev/null)" ]; then
    echo "📁 Found existing local attachments"
    read -p "Would you like to migrate local files to S3 now? (y/n): " migrate_now
    
    if [ "$migrate_now" = "y" ] || [ "$migrate_now" = "Y" ]; then
        echo "🚀 Starting server for migration..."
        
        # Start server in background
        $PYTHON_CMD main.py &
        SERVER_PID=$!
        
        # Wait for server to start
        echo "⏳ Waiting for server to start..."
        sleep 10
        
        # Run migration
        echo "📦 Starting file migration..."
        curl -X POST "http://localhost:8000/storage/migrate-to-s3" || echo "Migration API call failed"
        
        # Stop server
        kill $SERVER_PID 2>/dev/null || true
        
        echo "✅ Migration process completed"
        echo "Check the server logs for detailed migration results"
    else
        echo "⚠️ You can migrate files later using:"
        echo "   curl -X POST 'http://localhost:8000/storage/migrate-to-s3'"
    fi
else
    echo "ℹ️ No local attachments found to migrate"
fi

echo ""
echo "🎉 S3 integration setup completed!"
echo ""
echo "Next steps:"
echo "1. Start your server: $PYTHON_CMD main.py"
echo "2. Verify S3 configuration: curl http://localhost:8000/storage/info"
echo "3. Test file upload through your application"
echo ""
echo "For help and documentation, see README_S3_INTEGRATION.md"
echo ""

# Create backup of original attachment manager
if [ -f "attachment_manager.py" ] && [ ! -f "attachment_manager.py.backup" ]; then
    echo "💾 Creating backup of original attachment manager..."
    cp attachment_manager.py attachment_manager.py.backup
    echo "✅ Backup created: attachment_manager.py.backup"
fi

echo "✅ Setup completed successfully!"
