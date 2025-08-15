"""
AWS S3 Storage Manager for PSC Accounting
Handles file uploads, downloads, and management in S3
"""

import os
import boto3
import uuid
import mimetypes
import base64
import unicodedata
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
from botocore.exceptions import ClientError, NoCredentialsError
import logging

logger = logging.getLogger(__name__)

class S3StorageManager:
    """Manages file attachments with AWS S3 storage"""
    
    def __init__(self, bucket_name: str = "psc-accounting", 
                 aws_access_key_id: Optional[str] = None,
                 aws_secret_access_key: Optional[str] = None,
                 region_name: str = "us-east-1"):
        """
        Initialize S3 storage manager
        
        Args:
            bucket_name: S3 bucket name (default: psc-accounting)
            aws_access_key_id: AWS access key ID (will use env var if not provided)
            aws_secret_access_key: AWS secret key (will use env var if not provided)
            region_name: AWS region (default: us-east-1)
        """
        self.bucket_name = bucket_name
        self.region_name = region_name
        
        # Initialize S3 client
        try:
            session_config = {}
            if aws_access_key_id and aws_secret_access_key:
                session_config = {
                    'aws_access_key_id': aws_access_key_id,
                    'aws_secret_access_key': aws_secret_access_key,
                    'region_name': region_name
                }
            else:
                # Use environment variables or IAM role
                session_config = {'region_name': region_name}
            
            self.s3_client = boto3.client('s3', **session_config)
            
            # Test connection and bucket access
            self._verify_bucket_access()
            
            print(f"✅ [S3 Storage] Connected to bucket: {bucket_name}")
            
        except Exception as e:
            print(f"❌ [S3 Storage] Failed to initialize: {e}")
            raise
    
    def _verify_bucket_access(self):
        """Verify that we can access the S3 bucket"""
        try:
            # Try to head the bucket to verify access
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"✅ [S3 Storage] Bucket access verified: {self.bucket_name}")
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                # Bucket doesn't exist, try to create it
                print(f"🔧 [S3 Storage] Bucket {self.bucket_name} not found, attempting to create...")
                self._create_bucket()
            elif error_code == '403':
                raise Exception(f"Access denied to bucket {self.bucket_name}. Check your AWS credentials and permissions.")
            else:
                raise Exception(f"Error accessing bucket {self.bucket_name}: {e}")
        except NoCredentialsError:
            raise Exception("AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables or use IAM roles.")
    
    def _create_bucket(self):
        """Create the S3 bucket if it doesn't exist"""
        try:
            if self.region_name == 'us-east-1':
                # us-east-1 doesn't require location constraint
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            else:
                self.s3_client.create_bucket(
                    Bucket=self.bucket_name,
                    CreateBucketConfiguration={'LocationConstraint': self.region_name}
                )
            
            # Set up CORS for web access
            cors_configuration = {
                'CORSRules': [
                    {
                        'AllowedHeaders': ['*'],
                        'AllowedMethods': ['GET', 'POST', 'PUT', 'DELETE'],
                        'AllowedOrigins': ['*'],
                        'ExposeHeaders': ['Content-Length', 'Content-Type'],
                        'MaxAgeSeconds': 3600
                    }
                ]
            }
            
            self.s3_client.put_bucket_cors(
                Bucket=self.bucket_name,
                CORSConfiguration=cors_configuration
            )
            
            print(f"✅ [S3 Storage] Bucket created successfully: {self.bucket_name}")
            
        except Exception as e:
            raise Exception(f"Failed to create bucket {self.bucket_name}: {e}")
    
    def _sanitize_for_s3_metadata(self, value: str) -> str:
        """
        Sanitize string for S3 metadata (ASCII only)
        Non-ASCII characters are encoded using base64
        """
        try:
            # Try to encode as ASCII - if it works, return as-is
            value.encode('ascii')
            return value
        except UnicodeEncodeError:
            # If non-ASCII characters, encode the string as base64
            encoded_bytes = value.encode('utf-8')
            encoded_str = base64.b64encode(encoded_bytes).decode('ascii')
            return f"base64:{encoded_str}"
    
    def _decode_s3_metadata(self, value: str) -> str:
        """
        Decode S3 metadata that may have been base64 encoded
        """
        if value.startswith('base64:'):
            try:
                encoded_str = value[7:]  # Remove 'base64:' prefix
                decoded_bytes = base64.b64decode(encoded_str)
                return decoded_bytes.decode('utf-8')
            except Exception:
                return value  # Return as-is if decoding fails
        return value

    def generate_s3_key(self, entity_type: str, company_id: int, original_filename: str) -> str:
        """
        Generate S3 object key with organized structure
        Format: attachments/{entity_type}/company_{company_id}/{date}/{timestamp}_{uuid}_{filename}
        """
        current_date = datetime.now().strftime("%Y-%m-%d")
        timestamp = datetime.now().strftime("%H%M%S")
        unique_id = uuid.uuid4().hex[:8]
        
        # Sanitize filename for S3 (keep original characters for the key)
        # S3 keys can contain Unicode, but metadata cannot
        # Remove problematic characters but preserve the original name structure
        safe_filename = "".join(c for c in original_filename if c not in ['/', '\\', '?', '*', ':', '|', '<', '>', '"']).strip()
        if not safe_filename:
            safe_filename = f"file_{unique_id}.bin"
        
        s3_key = f"attachments/{entity_type}/company_{company_id}/{current_date}/{timestamp}_{unique_id}_{safe_filename}"
        
        return s3_key
    
    def upload_file(self, file_content: bytes, entity_type: str, company_id: int, 
                   original_filename: str, description: Optional[str] = None) -> Dict[str, Any]:
        """
        Upload file to S3
        
        Returns:
            Dict containing file information and S3 metadata
        """
        try:
            # Generate S3 key
            s3_key = self.generate_s3_key(entity_type, company_id, original_filename)
            
            # Determine content type
            content_type = mimetypes.guess_type(original_filename)[0] or 'application/octet-stream'
            
            # Prepare metadata (S3 metadata must be ASCII-only)
            metadata = {
                'entity_type': self._sanitize_for_s3_metadata(entity_type),
                'company_id': str(company_id),
                'original_filename': self._sanitize_for_s3_metadata(original_filename),
                'upload_timestamp': datetime.now().isoformat(),
            }
            
            if description:
                metadata['description'] = self._sanitize_for_s3_metadata(description)
            
            # Upload to S3
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_key,
                Body=file_content,
                ContentType=content_type,
                Metadata=metadata,
                ServerSideEncryption='AES256'  # Enable server-side encryption
            )
            
            print(f"✅ [S3 Storage] File uploaded: {s3_key}")
            
            return {
                's3_key': s3_key,
                'bucket_name': self.bucket_name,
                'content_type': content_type,
                'file_size': len(file_content),
                'metadata': metadata,
                's3_url': f"s3://{self.bucket_name}/{s3_key}"
            }
            
        except Exception as e:
            print(f"❌ [S3 Storage] Upload failed: {e}")
            raise Exception(f"S3 upload failed: {str(e)}")
    
    def download_file(self, s3_key: str) -> Tuple[bytes, Dict[str, Any]]:
        """
        Download file from S3
        
        Returns:
            Tuple of (file_content, metadata)
        """
        try:
            # Get object from S3
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=s3_key)
            
            file_content = response['Body'].read()
            
            # Decode any base64-encoded metadata
            raw_metadata = response.get('Metadata', {})
            decoded_metadata = {}
            for key, value in raw_metadata.items():
                decoded_metadata[key] = self._decode_s3_metadata(value)
            
            metadata = {
                'content_type': response.get('ContentType', 'application/octet-stream'),
                'content_length': response.get('ContentLength', 0),
                'last_modified': response.get('LastModified'),
                'metadata': decoded_metadata,
                'etag': response.get('ETag', '').strip('"')
            }
            
            print(f"✅ [S3 Storage] File downloaded: {s3_key}")
            
            return file_content, metadata
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                raise FileNotFoundError(f"File not found in S3: {s3_key}")
            else:
                raise Exception(f"S3 download failed: {e}")
        except Exception as e:
            print(f"❌ [S3 Storage] Download failed: {e}")
            raise Exception(f"S3 download failed: {str(e)}")
    
    def delete_file(self, s3_key: str) -> bool:
        """Delete file from S3"""
        try:
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=s3_key)
            print(f"✅ [S3 Storage] File deleted: {s3_key}")
            return True
            
        except Exception as e:
            print(f"❌ [S3 Storage] Delete failed: {e}")
            return False
    
    def list_files(self, prefix: str = "", max_keys: int = 1000) -> List[Dict[str, Any]]:
        """List files in S3 bucket with optional prefix filter"""
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix,
                MaxKeys=max_keys
            )
            
            files = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    files.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'],
                        'etag': obj['ETag'].strip('"'),
                        'storage_class': obj.get('StorageClass', 'STANDARD')
                    })
            
            print(f"✅ [S3 Storage] Listed {len(files)} files with prefix: {prefix}")
            
            return files
            
        except Exception as e:
            print(f"❌ [S3 Storage] List failed: {e}")
            raise Exception(f"S3 list failed: {str(e)}")
    
    def get_file_info(self, s3_key: str) -> Dict[str, Any]:
        """Get file metadata without downloading the content"""
        try:
            response = self.s3_client.head_object(Bucket=self.bucket_name, Key=s3_key)
            
            # Decode any base64-encoded metadata
            raw_metadata = response.get('Metadata', {})
            decoded_metadata = {}
            for key, value in raw_metadata.items():
                decoded_metadata[key] = self._decode_s3_metadata(value)
            
            info = {
                'key': s3_key,
                'size': response.get('ContentLength', 0),
                'content_type': response.get('ContentType', 'application/octet-stream'),
                'last_modified': response.get('LastModified'),
                'etag': response.get('ETag', '').strip('"'),
                'metadata': decoded_metadata,
                'server_side_encryption': response.get('ServerSideEncryption'),
                'storage_class': response.get('StorageClass', 'STANDARD')
            }
            
            return info
            
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                raise FileNotFoundError(f"File not found in S3: {s3_key}")
            else:
                raise Exception(f"S3 head_object failed: {e}")
        except Exception as e:
            print(f"❌ [S3 Storage] Get info failed: {e}")
            raise Exception(f"S3 get info failed: {str(e)}")
    
    def generate_presigned_url(self, s3_key: str, expiration: int = 3600, 
                              http_method: str = 'GET') -> str:
        """
        Generate a presigned URL for secure file access
        
        Args:
            s3_key: S3 object key
            expiration: URL expiration time in seconds (default: 1 hour)
            http_method: HTTP method ('GET', 'PUT', 'DELETE')
        
        Returns:
            Presigned URL string
        """
        try:
            url = self.s3_client.generate_presigned_url(
                'get_object' if http_method == 'GET' else f"{http_method.lower()}_object",
                Params={'Bucket': self.bucket_name, 'Key': s3_key},
                ExpiresIn=expiration
            )
            
            print(f"✅ [S3 Storage] Presigned URL generated for: {s3_key}")
            
            return url
            
        except Exception as e:
            print(f"❌ [S3 Storage] Presigned URL generation failed: {e}")
            raise Exception(f"Presigned URL generation failed: {str(e)}")
    
    def get_bucket_stats(self, prefix: str = "") -> Dict[str, Any]:
        """Get storage statistics for the bucket or prefix"""
        try:
            total_size = 0
            total_files = 0
            
            # Use paginator for large buckets
            paginator = self.s3_client.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)
            
            for page in pages:
                if 'Contents' in page:
                    for obj in page['Contents']:
                        total_size += obj['Size']
                        total_files += 1
            
            stats = {
                'total_files': total_files,
                'total_size_bytes': total_size,
                'total_size_human': self._format_file_size(total_size),
                'bucket_name': self.bucket_name,
                'prefix': prefix,
                'region': self.region_name
            }
            
            print(f"📊 [S3 Storage] Bucket stats: {total_files} files, {stats['total_size_human']}")
            
            return stats
            
        except Exception as e:
            print(f"❌ [S3 Storage] Stats failed: {e}")
            raise Exception(f"S3 stats failed: {str(e)}")
    
    def _format_file_size(self, size_bytes: int) -> str:
        """Format file size in human readable format"""
        if size_bytes == 0:
            return "0 B"
        
        size_names = ["B", "KB", "MB", "GB", "TB"]
        i = 0
        while size_bytes >= 1024 and i < len(size_names) - 1:
            size_bytes /= 1024.0
            i += 1
        
        return f"{size_bytes:.1f} {size_names[i]}"
    
    def migrate_from_local(self, local_file_path: str, s3_key: str) -> bool:
        """Migrate a file from local storage to S3"""
        try:
            with open(local_file_path, 'rb') as f:
                file_content = f.read()
            
            # Determine content type
            content_type = mimetypes.guess_type(local_file_path)[0] or 'application/octet-stream'
            
            # Upload to S3
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_key,
                Body=file_content,
                ContentType=content_type,
                ServerSideEncryption='AES256'
            )
            
            print(f"✅ [S3 Storage] Migrated from local: {local_file_path} → {s3_key}")
            return True
            
        except Exception as e:
            print(f"❌ [S3 Storage] Migration failed: {e}")
            return False
