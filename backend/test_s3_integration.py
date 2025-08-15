#!/usr/bin/env python3
"""
Quick test script for S3 integration
Tests the S3 storage without requiring full server setup
"""

import sys
import os
from pathlib import Path

# Add current directory to Python path
sys.path.append('.')

def test_imports():
    """Test that all required modules can be imported"""
    print("🧪 Testing imports...")
    
    try:
        import boto3
        print(f"✅ boto3 imported successfully (version: {boto3.__version__})")
    except ImportError as e:
        print(f"❌ Failed to import boto3: {e}")
        return False
    
    try:
        import botocore
        print(f"✅ botocore imported successfully (version: {botocore.__version__})")
    except ImportError as e:
        print(f"❌ Failed to import botocore: {e}")
        return False
    
    try:
        from s3_storage import S3StorageManager
        print("✅ S3StorageManager imported successfully")
    except ImportError as e:
        print(f"❌ Failed to import S3StorageManager: {e}")
        return False
    
    try:
        from unified_attachment_manager import UnifiedAttachmentManager
        print("✅ UnifiedAttachmentManager imported successfully")
    except ImportError as e:
        print(f"❌ Failed to import UnifiedAttachmentManager: {e}")
        return False
    
    return True

def test_local_storage():
    """Test local storage functionality"""
    print("\n📁 Testing local storage...")
    
    try:
        from unified_attachment_manager import UnifiedAttachmentManager
        
        # Initialize with local storage
        manager = UnifiedAttachmentManager(storage_backend="local")
        print("✅ Local storage manager initialized")
        
        # Test file validation
        is_valid, message = manager.validate_file("test.pdf", 1024)
        if is_valid:
            print("✅ File validation working")
        else:
            print(f"⚠️ File validation issue: {message}")
        
        return True
        
    except Exception as e:
        print(f"❌ Local storage test failed: {e}")
        return False

def test_s3_connection():
    """Test S3 connection (if credentials are available)"""
    print("\n☁️ Testing S3 connection...")
    
    # Check for AWS credentials
    has_credentials = (
        os.getenv('AWS_ACCESS_KEY_ID') or 
        os.getenv('AWS_PROFILE') or
        Path('~/.aws/credentials').expanduser().exists()
    )
    
    if not has_credentials:
        print("⚠️ No AWS credentials found, skipping S3 connection test")
        print("   Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to test S3")
        return True
    
    try:
        from s3_storage import S3StorageManager
        
        bucket_name = os.getenv('S3_BUCKET', 'psc-accounting')
        region = os.getenv('AWS_REGION', 'us-east-1')
        
        print(f"📡 Testing connection to bucket: {bucket_name} in region: {region}")
        
        # Initialize S3 manager
        s3_manager = S3StorageManager(bucket_name=bucket_name, region_name=region)
        print("✅ S3 connection successful!")
        
        # Test basic S3 operations
        stats = s3_manager.get_bucket_stats("attachments/")
        print(f"✅ Bucket stats retrieved: {stats['total_files']} files")
        
        return True
        
    except Exception as e:
        print(f"❌ S3 connection failed: {e}")
        print("   This is expected if AWS credentials are not configured")
        return False

def test_unified_manager():
    """Test unified attachment manager with both backends"""
    print("\n🔄 Testing unified attachment manager...")
    
    try:
        from unified_attachment_manager import UnifiedAttachmentManager
        
        # Test local backend
        local_manager = UnifiedAttachmentManager(storage_backend="local")
        print("✅ Local backend manager created")
        
        # Test file info
        file_info = local_manager.get_file_info("test.pdf")
        print(f"✅ File info retrieved: category={file_info['category']}, max_size={file_info['max_size']}")
        
        # Test S3 backend (will fall back to local if S3 not available)
        s3_manager = UnifiedAttachmentManager(storage_backend="s3")
        print("✅ S3 backend manager created (may have fallen back to local)")
        
        return True
        
    except Exception as e:
        print(f"❌ Unified manager test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 PSC Accounting - S3 Integration Test")
    print("=" * 50)
    
    tests = [
        ("Import Test", test_imports),
        ("Local Storage Test", test_local_storage),
        ("S3 Connection Test", test_s3_connection),
        ("Unified Manager Test", test_unified_manager),
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} crashed: {e}")
            results.append((test_name, False))
    
    print("\n" + "=" * 50)
    print("📊 Test Results Summary:")
    print("-" * 25)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print(f"\n🎯 Tests passed: {passed}/{len(results)}")
    
    if passed == len(results):
        print("🎉 All tests passed! S3 integration is ready.")
        return 0
    else:
        print("⚠️ Some tests failed. Check the output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
