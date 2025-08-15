#!/usr/bin/env python3
"""
Verify Render.com Environment Configuration
This script validates that all required environment variables are properly configured
for deployment to Render.com with AWS S3 integration.
"""

import os
import sys
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.append(str(backend_dir))

from env_config import env_config

def check_render_environment():
    """Check if environment is properly configured for Render.com deployment"""
    print("🔍 Verifying Render.com Environment Configuration")
    print("=" * 60)
    
    # Check if running in production-like environment (no .env file)
    env_file_exists = os.path.exists(env_config.env_file)
    if env_file_exists:
        print("⚠️  Local .env file detected - this check simulates Render.com environment")
        print("   In production, Render.com will use environment variables directly")
    else:
        print("✅ No local .env file - using environment variables only (production mode)")
    
    print()
    
    # Database Configuration
    print("📊 Database Configuration:")
    db_vars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'DB_PORT']
    for var in db_vars:
        value = env_config.get_config(var)
        if var == 'DB_PASSWORD':
            status = "✅ Set" if value else "❌ Missing"
            print(f"  {var}: {status}")
        else:
            print(f"  {var}: {value or '❌ Missing'}")
    
    print()
    
    # AWS S3 Configuration
    print("☁️  AWS S3 Configuration:")
    s3_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'S3_BUCKET']
    s3_config_valid = True
    
    for var in s3_vars:
        value = env_config.get_config(var)
        if var in ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']:
            if value:
                masked_value = f"{value[:8]}...{value[-4:]}" if len(value) > 12 else "***"
                print(f"  {var}: {masked_value} ✅")
            else:
                print(f"  {var}: ❌ Missing")
                s3_config_valid = False
        else:
            if value:
                print(f"  {var}: {value} ✅")
            else:
                print(f"  {var}: ❌ Missing")
                s3_config_valid = False
    
    print()
    
    # Storage Backend Configuration
    storage_backend = env_config.get_config('STORAGE_BACKEND', 'local')
    print("📁 Storage Configuration:")
    print(f"  STORAGE_BACKEND: {storage_backend}")
    
    if storage_backend == 's3':
        if s3_config_valid:
            print("  Status: ✅ S3 backend properly configured")
        else:
            print("  Status: ❌ S3 backend selected but configuration incomplete")
            print("  Note: Application will fall back to local storage")
    else:
        print("  Status: ✅ Local storage configured (S3 variables optional)")
    
    print()
    
    # Security Configuration
    print("🔐 Security Configuration:")
    security_vars = ['JWT_SECRET', 'API_SECRET_KEY']
    for var in security_vars:
        value = env_config.get_config(var)
        if value:
            print(f"  {var}: ✅ Set ({len(value)} characters)")
        else:
            print(f"  {var}: ❌ Missing (required for production)")
    
    print()
    
    # API Configuration
    print("🌐 API Configuration:")
    api_vars = ['API_HOST', 'API_PORT', 'CORS_ORIGINS']
    for var in api_vars:
        value = env_config.get_config(var)
        print(f"  {var}: {value or 'Using default'}")
    
    print()
    
    # Environment Detection
    environment = env_config.get_config('ENVIRONMENT', 'development')
    print("🏷️  Environment Detection:")
    print(f"  ENVIRONMENT: {environment}")
    print(f"  Is Production: {env_config.is_production()}")
    print(f"  Debug Mode: {env_config.get_config('DEBUG', False)}")
    
    print()
    
    # Validation Summary
    print("📋 Validation Summary:")
    print("=" * 30)
    
    # Database validation
    db_valid = env_config.validate_database_connection()
    print(f"Database Configuration: {'✅ Valid' if db_valid else '❌ Invalid'}")
    
    # S3 validation (if S3 backend selected)
    if storage_backend == 's3':
        s3_valid = env_config.validate_s3_configuration()
        print(f"S3 Configuration: {'✅ Valid' if s3_valid else '❌ Invalid'}")
    
    # Security validation (for production)
    if environment == 'production':
        security_valid = all(env_config.get_config(var) for var in security_vars)
        print(f"Security Configuration: {'✅ Valid' if security_valid else '❌ Invalid'}")
    
    print()
    
    # Render.com Specific Checks
    print("🚀 Render.com Deployment Readiness:")
    print("=" * 40)
    
    issues = []
    
    if not db_valid:
        issues.append("Database configuration incomplete")
    
    if storage_backend == 's3' and not s3_config_valid:
        issues.append("S3 configuration incomplete (will use local storage)")
    
    if environment == 'production' and not all(env_config.get_config(var) for var in security_vars):
        issues.append("Security configuration incomplete for production")
    
    if not issues:
        print("✅ Ready for Render.com deployment!")
        print("✅ All required environment variables are properly configured")
        if storage_backend == 's3':
            print("✅ S3 integration will work correctly")
        return True
    else:
        print("⚠️  Issues found:")
        for issue in issues:
            print(f"   - {issue}")
        print()
        print("Please set the missing environment variables in Render.com")
        return False

def test_s3_connection():
    """Test S3 connection if S3 backend is configured"""
    storage_backend = env_config.get_config('STORAGE_BACKEND', 'local')
    
    if storage_backend != 's3':
        print("ℹ️  S3 connection test skipped (local storage backend)")
        return True
    
    if not env_config.validate_s3_configuration():
        print("❌ S3 connection test skipped (configuration invalid)")
        return False
    
    print()
    print("🧪 Testing S3 Connection...")
    print("=" * 30)
    
    try:
        from s3_storage import S3StorageManager
        
        s3_config = env_config.get_s3_config()
        s3_manager = S3StorageManager(
            bucket_name=s3_config['bucket_name'],
            region_name=s3_config['region_name']
        )
        
        # Test bucket access
        stats = s3_manager.get_bucket_stats()
        print(f"✅ S3 connection successful!")
        print(f"   Bucket: {s3_config['bucket_name']}")
        print(f"   Region: {s3_config['region_name']}")
        print(f"   Files: {stats['total_files']}")
        print(f"   Size: {stats['total_size_human']}")
        
        return True
        
    except Exception as e:
        print(f"❌ S3 connection failed: {e}")
        print("   Please check your AWS credentials and bucket configuration")
        return False

def main():
    """Main verification function"""
    config_valid = check_render_environment()
    s3_valid = test_s3_connection()
    
    print()
    print("🎯 Final Status:")
    print("=" * 20)
    
    if config_valid and s3_valid:
        print("🎉 Your application is ready for Render.com deployment!")
        print("   All environment variables are properly configured")
        print("   S3 integration is working correctly")
        return True
    elif config_valid:
        print("✅ Basic configuration is valid")
        print("⚠️  S3 integration needs attention (will use local storage)")
        print("   Check AWS credentials and bucket permissions")
        return True
    else:
        print("❌ Configuration issues found")
        print("   Please fix the issues above before deploying")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)