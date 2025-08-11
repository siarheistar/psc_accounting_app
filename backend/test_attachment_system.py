#!/usr/bin/env python3
"""
Test script for attachment upload system
"""

import os
import sys
import json
import requests
from pathlib import Path

# Add backend path to sys.path
backend_path = Path(__file__).parent
sys.path.append(str(backend_path))

def test_attachment_upload():
    """Test the attachment upload endpoint"""
    
    # API base URL
    base_url = "http://localhost:8000"
    
    # Test parameters
    company_id = 1
    entity_type = "invoice"
    entity_id = 1
    
    # Create a simple test file
    test_file_content = b"This is a test PDF content for attachment upload testing."
    test_filename = "test_invoice.pdf"
    
    # Prepare the multipart form data
    files = {
        'file': (test_filename, test_file_content, 'application/pdf')
    }
    
    data = {
        'entity_type': entity_type,
        'entity_id': entity_id,
        'company_id': company_id,
        'description': 'Test attachment upload'
    }
    
    try:
        # Test upload
        print(f"🧪 Testing attachment upload...")
        print(f"📋 URL: {base_url}/attachments/upload")
        print(f"📋 Data: {data}")
        print(f"📋 File: {test_filename} ({len(test_file_content)} bytes)")
        
        response = requests.post(
            f"{base_url}/attachments/upload",
            files=files,
            data=data
        )
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"📊 Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Upload successful!")
            print(f"📎 Attachment ID: {result.get('id')}")
            print(f"📁 File Path: {result.get('file_path')}")
            print(f"📊 Response: {json.dumps(result, indent=2)}")
            
            # Test list attachments
            list_response = requests.get(
                f"{base_url}/attachments/list/{entity_type}/{entity_id}?company_id={company_id}"
            )
            
            if list_response.status_code == 200:
                attachments = list_response.json()
                print(f"📋 Listed {len(attachments)} attachments:")
                for att in attachments:
                    print(f"   - {att['original_filename']} ({att['file_size_human']})")
            
            return result.get('id')
            
        else:
            print(f"❌ Upload failed!")
            print(f"📊 Response: {response.text}")
            return None
            
    except requests.exceptions.ConnectionError:
        print(f"❌ Connection failed! Is the server running on {base_url}?")
        return None
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return None

def test_file_storage():
    """Test the file storage structure"""
    
    uploads_dir = Path("uploads/attachments")
    
    print(f"📁 Checking storage structure...")
    print(f"📁 Base directory: {uploads_dir.absolute()}")
    
    if uploads_dir.exists():
        print(f"✅ Attachments directory exists")
        
        # List categories
        categories = [d.name for d in uploads_dir.iterdir() if d.is_dir()]
        print(f"📂 Categories found: {categories}")
        
        # Check for any files
        total_files = 0
        for category_dir in uploads_dir.iterdir():
            if category_dir.is_dir():
                files_in_category = sum(1 for f in category_dir.rglob('*') if f.is_file())
                total_files += files_in_category
                if files_in_category > 0:
                    print(f"📁 {category_dir.name}: {files_in_category} files")
        
        print(f"📊 Total files in storage: {total_files}")
        
    else:
        print(f"❌ Attachments directory not found!")

if __name__ == "__main__":
    print("🧪 PSC Accounting - Attachment System Test")
    print("=" * 50)
    
    # Test file storage structure
    test_file_storage()
    print()
    
    # Test API endpoint
    attachment_id = test_attachment_upload()
    print()
    
    if attachment_id:
        print(f"✅ All tests completed successfully!")
        print(f"📎 Created attachment ID: {attachment_id}")
    else:
        print(f"❌ Some tests failed!")
