#!/usr/bin/env python3
"""
Test script for the new attachment management system
"""

import requests
import sys
import os
from pathlib import Path

# Configuration
BASE_URL = "http://localhost:8000"
COMPANY_ID = 1
ENTITY_TYPE = "invoice"
ENTITY_ID = 1

def test_upload_attachment():
    """Test uploading a file attachment"""
    
    print("📎 Testing file upload...")
    
    # Create a test file
    test_content = b"This is a test document for PSC Accounting attachment system."
    test_filename = "test_document.txt"
    
    files = {
        'file': (test_filename, test_content, 'text/plain')
    }
    
    data = {
        'description': 'Test attachment uploaded via API test script'
    }
    
    params = {
        'entity_type': ENTITY_TYPE,
        'entity_id': ENTITY_ID,
        'company_id': COMPANY_ID
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/attachments/upload",
            files=files,
            data=data,
            params=params,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Upload successful!")
            print(f"   Attachment ID: {result['id']}")
            print(f"   Original filename: {result['original_filename']}")
            print(f"   File size: {result['file_size_human']}")
            print(f"   Category: {result['category']}")
            print(f"   MIME type: {result['mime_type']}")
            return result['id']
        else:
            print(f"❌ Upload failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Upload error: {e}")
        return None

def test_list_attachments():
    """Test listing attachments for an entity"""
    
    print("\\n📋 Testing attachment listing...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/attachments/{ENTITY_TYPE}/{ENTITY_ID}",
            params={'company_id': COMPANY_ID},
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ List successful!")
            print(f"   Total attachments: {result['total_count']}")
            print(f"   Total size: {result['total_size_human']}")
            
            if result['attachments']:
                print(f"   Attachments:")
                for att in result['attachments']:
                    print(f"     - {att['original_filename']} ({att['category']}) - {att['file_size_human']}")
            
            return result['attachments']
        else:
            print(f"❌ List failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return []
            
    except Exception as e:
        print(f"❌ List error: {e}")
        return []

def test_download_attachment(attachment_id):
    """Test downloading an attachment"""
    
    print(f"\\n📥 Testing attachment download (ID: {attachment_id})...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/attachments/download/{attachment_id}",
            params={'company_id': COMPANY_ID},
            timeout=10
        )
        
        if response.status_code == 200:
            print(f"✅ Download successful!")
            print(f"   Content length: {len(response.content)} bytes")
            print(f"   Content type: {response.headers.get('content-type', 'unknown')}")
            
            # Check if content matches what we uploaded
            if b"This is a test document" in response.content:
                print(f"   Content verification: ✅ Matches uploaded content")
            else:
                print(f"   Content verification: ❌ Content doesn't match")
            
            return True
        else:
            print(f"❌ Download failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Download error: {e}")
        return False

def test_attachment_stats():
    """Test getting attachment statistics"""
    
    print(f"\\n📊 Testing attachment statistics...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/attachments/stats",
            params={'company_id': COMPANY_ID},
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Stats successful!")
            print(f"   Total attachments: {result['total_attachments']}")
            print(f"   Total size: {result['total_size_human']}")
            print(f"   Categories: {', '.join(result['by_category'].keys())}")
            print(f"   Supported types: {len(result['supported_types'])} file types")
            return True
        else:
            print(f"❌ Stats failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Stats error: {e}")
        return False

def test_delete_attachment(attachment_id):
    """Test deleting an attachment"""
    
    print(f"\\n🗑️ Testing attachment deletion (ID: {attachment_id})...")
    
    try:
        response = requests.delete(
            f"{BASE_URL}/attachments/{attachment_id}",
            params={'company_id': COMPANY_ID},
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Delete successful!")
            print(f"   Message: {result['message']}")
            return True
        else:
            print(f"❌ Delete failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Delete error: {e}")
        return False

def test_server_health():
    """Test if the server is running"""
    
    print("🔍 Checking server health...")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ Server is running")
            return True
        else:
            print(f"❌ Server returned {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Server not reachable: {e}")
        return False

def main():
    """Run all attachment system tests"""
    
    print("🧪 PSC Accounting - Attachment System Test")
    print("==========================================")
    print(f"Target server: {BASE_URL}")
    print(f"Test entity: {ENTITY_TYPE} #{ENTITY_ID} (company {COMPANY_ID})")
    print("")
    
    # Check server health
    if not test_server_health():
        print("\\n❌ Cannot continue - server is not running")
        print("   Make sure the backend server is started:")
        print("   cd backend && python -m uvicorn main:app --reload")
        return 1
    
    # Run test sequence
    attachment_id = None
    success_count = 0
    total_tests = 5
    
    # Test 1: Upload
    attachment_id = test_upload_attachment()
    if attachment_id:
        success_count += 1
    
    # Test 2: List
    attachments = test_list_attachments()
    if attachments:
        success_count += 1
    
    # Test 3: Download (only if upload succeeded)
    if attachment_id and test_download_attachment(attachment_id):
        success_count += 1
    
    # Test 4: Stats
    if test_attachment_stats():
        success_count += 1
    
    # Test 5: Delete (only if upload succeeded)
    if attachment_id and test_delete_attachment(attachment_id):
        success_count += 1
    
    # Summary
    print(f"\\n📊 Test Results")
    print("================")
    print(f"Tests passed: {success_count}/{total_tests}")
    
    if success_count == total_tests:
        print("✅ All tests passed! Attachment system is working correctly.")
        return 0
    else:
        print(f"❌ {total_tests - success_count} tests failed. Check the errors above.")
        return 1

if __name__ == "__main__":
    exit(main())
