"""
Unified Attachment Manager for PSC Accounting API
Supports both S3 and local storage with configurable backend
"""

import os
import uuid
import mimetypes
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
from database import execute_query
from s3_storage import S3StorageManager

class UnifiedAttachmentManager:
    """Manages file attachments with configurable storage backend (S3 or local)"""
    
    # Supported file types and their categories
    SUPPORTED_TYPES = {
        # Documents
        'pdf': {'category': 'document', 'max_size': 50 * 1024 * 1024},  # 50MB
        'doc': {'category': 'document', 'max_size': 50 * 1024 * 1024},
        'docx': {'category': 'document', 'max_size': 50 * 1024 * 1024},
        'txt': {'category': 'document', 'max_size': 10 * 1024 * 1024},   # 10MB
        'rtf': {'category': 'document', 'max_size': 10 * 1024 * 1024},
        'odt': {'category': 'document', 'max_size': 50 * 1024 * 1024},
        
        # Spreadsheets
        'xls': {'category': 'spreadsheet', 'max_size': 50 * 1024 * 1024},
        'xlsx': {'category': 'spreadsheet', 'max_size': 50 * 1024 * 1024},
        'csv': {'category': 'spreadsheet', 'max_size': 10 * 1024 * 1024},
        'ods': {'category': 'spreadsheet', 'max_size': 50 * 1024 * 1024},
        
        # Images
        'jpg': {'category': 'image', 'max_size': 20 * 1024 * 1024},      # 20MB
        'jpeg': {'category': 'image', 'max_size': 20 * 1024 * 1024},
        'png': {'category': 'image', 'max_size': 20 * 1024 * 1024},
        'gif': {'category': 'image', 'max_size': 10 * 1024 * 1024},
        'bmp': {'category': 'image', 'max_size': 20 * 1024 * 1024},
        'tiff': {'category': 'image', 'max_size': 20 * 1024 * 1024},
        'webp': {'category': 'image', 'max_size': 20 * 1024 * 1024},
        
        # Archive/Compressed
        'zip': {'category': 'archive', 'max_size': 100 * 1024 * 1024},   # 100MB
        'rar': {'category': 'archive', 'max_size': 100 * 1024 * 1024},
        '7z': {'category': 'archive', 'max_size': 100 * 1024 * 1024},
        'tar': {'category': 'archive', 'max_size': 100 * 1024 * 1024},
        'gz': {'category': 'archive', 'max_size': 100 * 1024 * 1024},
        
        # Other common types
        'xml': {'category': 'data', 'max_size': 10 * 1024 * 1024},
        'json': {'category': 'data', 'max_size': 10 * 1024 * 1024},
    }
    
    def __init__(self, storage_backend: str = "local", upload_dir: str = "uploads", 
                 s3_bucket: str = "psc-accounting", s3_region: str = "us-east-1"):
        """
        Initialize unified attachment manager
        
        Args:
            storage_backend: "s3" or "local" (default: "local")
            upload_dir: Local upload directory for local storage
            s3_bucket: S3 bucket name for S3 storage
            s3_region: AWS region for S3 storage
        """
        self.storage_backend = storage_backend.lower()
        self.upload_dir = Path(upload_dir)
        self.attachments_dir = self.upload_dir / "attachments"
        
        # Initialize storage backends
        if self.storage_backend == "s3":
            try:
                self.s3_manager = S3StorageManager(
                    bucket_name=s3_bucket,
                    region_name=s3_region
                )
                print(f"✅ [Unified Manager] S3 storage initialized (bucket: {s3_bucket})")
            except Exception as e:
                print(f"⚠️ [Unified Manager] S3 initialization failed: {e}")
                print(f"🔄 [Unified Manager] Falling back to local storage")
                self.storage_backend = "local"
                self._setup_local_storage()
        else:
            self._setup_local_storage()
        
        print(f"📁 [Unified Manager] Active backend: {self.storage_backend.upper()}")
    
    def _setup_local_storage(self):
        """Setup local storage directories"""
        self.attachments_dir.mkdir(parents=True, exist_ok=True)
        
        # Create entity type directories
        entity_types = ['invoice', 'expense', 'bank_statement', 'payroll']
        for entity_type in entity_types:
            entity_dir = self.attachments_dir / entity_type
            entity_dir.mkdir(exist_ok=True)
        
        print(f"📁 [Unified Manager] Local storage setup complete: {self.attachments_dir.absolute()}")
    
    def get_file_info(self, filename: str) -> Dict[str, Any]:
        """Get file information including category, max size, and MIME type"""
        file_ext = Path(filename).suffix.lower().lstrip('.')
        
        if file_ext in self.SUPPORTED_TYPES:
            file_info = self.SUPPORTED_TYPES[file_ext].copy()
            file_info['extension'] = file_ext
            file_info['mime_type'] = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
        else:
            # Default for unsupported types
            file_info = {
                'category': 'other',
                'max_size': 25 * 1024 * 1024,  # 25MB default
                'extension': file_ext,
                'mime_type': mimetypes.guess_type(filename)[0] or 'application/octet-stream'
            }
        
        return file_info
    
    def validate_file(self, filename: str, file_size: int) -> Tuple[bool, str]:
        """Validate file type and size"""
        if not filename:
            return False, "Filename is required"
        
        file_info = self.get_file_info(filename)
        
        # Check file size
        if file_size > file_info['max_size']:
            max_mb = file_info['max_size'] / (1024 * 1024)
            return False, f"File size ({file_size:,} bytes) exceeds maximum allowed size ({max_mb:.1f}MB) for {file_info['category']} files"
        
        # Check for potentially dangerous files
        dangerous_extensions = {'exe', 'bat', 'cmd', 'com', 'scr', 'vbs', 'js'}
        if file_info['extension'] in dangerous_extensions:
            return False, f"File type '.{file_info['extension']}' is not allowed for security reasons"
        
        return True, "File is valid"
    
    def save_attachment(self, file_content: bytes, entity_type: str, entity_id: int, 
                       company_id: int, original_filename: str, 
                       description: Optional[str] = None) -> Dict[str, Any]:
        """Save attachment file using configured storage backend"""
        
        file_size = len(file_content)
        
        # Validate file
        is_valid, error_message = self.validate_file(original_filename, file_size)
        if not is_valid:
            raise ValueError(error_message)
        
        # Get file information
        file_info = self.get_file_info(original_filename)
        print(f"📎 [Unified Manager] Saving with {self.storage_backend.upper()} backend: {original_filename}")
        
        if self.storage_backend == "s3":
            return self._save_to_s3(file_content, entity_type, entity_id, company_id, 
                                   original_filename, file_info, description)
        else:
            return self._save_to_local(file_content, entity_type, entity_id, company_id, 
                                      original_filename, file_info, description)
    
    def _save_to_s3(self, file_content: bytes, entity_type: str, entity_id: int, 
                   company_id: int, original_filename: str, file_info: Dict[str, Any],
                   description: Optional[str] = None) -> Dict[str, Any]:
        """Save attachment to S3"""
        try:
            # Upload to S3
            s3_result = self.s3_manager.upload_file(
                file_content, entity_type, company_id, original_filename, description
            )
            
            # Save metadata to database
            attachment_id = self._save_metadata_to_db(
                entity_type=entity_type,
                entity_id=entity_id,
                company_id=company_id,
                original_filename=original_filename,
                unique_filename=s3_result['s3_key'],  # Use S3 key as unique filename
                file_size=len(file_content),
                mime_type=file_info.get('mime_type', 'application/octet-stream'),
                category=file_info.get('category', 'other'),
                relative_path=s3_result['s3_key'],  # Store S3 key as path
                description=description,
                storage_backend="s3",
                s3_bucket=s3_result['bucket_name'],
                s3_key=s3_result['s3_key']
            )
            
            return {
                "id": attachment_id,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "company_id": company_id,
                "filename": s3_result['s3_key'],
                "original_filename": original_filename,
                "file_size": len(file_content),
                "mime_type": file_info.get('mime_type', 'application/octet-stream'),
                "category": file_info.get('category', 'other'),
                "file_path": s3_result['s3_key'],
                "description": description,
                "storage_backend": "s3",
                "s3_bucket": s3_result['bucket_name'],
                "s3_url": s3_result['s3_url'],
                "created_at": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ [Unified Manager] S3 save failed: {e}")
            raise e
    
    def _save_to_local(self, file_content: bytes, entity_type: str, entity_id: int, 
                      company_id: int, original_filename: str, file_info: Dict[str, Any],
                      description: Optional[str] = None) -> Dict[str, Any]:
        """Save attachment to local storage"""
        try:
            # Create storage directory
            storage_path = self._get_local_storage_path(entity_type, company_id)
            storage_path.mkdir(parents=True, exist_ok=True)
            
            # Generate unique filename
            timestamp = datetime.now().strftime("%H%M%S")
            file_ext = Path(original_filename).suffix
            unique_filename = f"{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
            file_path = storage_path / unique_filename
            
            # Save file to disk
            with open(file_path, 'wb') as f:
                f.write(file_content)
            
            # Calculate relative path for database
            relative_path = str(file_path.relative_to(self.attachments_dir))
            
            # Save metadata to database
            attachment_id = self._save_metadata_to_db(
                entity_type=entity_type,
                entity_id=entity_id,
                company_id=company_id,
                original_filename=original_filename,
                unique_filename=unique_filename,
                file_size=len(file_content),
                mime_type=file_info.get('mime_type', 'application/octet-stream'),
                category=file_info.get('category', 'other'),
                relative_path=relative_path,
                description=description,
                storage_backend="local"
            )
            
            return {
                "id": attachment_id,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "company_id": company_id,
                "filename": unique_filename,
                "original_filename": original_filename,
                "file_size": len(file_content),
                "mime_type": file_info.get('mime_type', 'application/octet-stream'),
                "category": file_info.get('category', 'other'),
                "file_path": relative_path,
                "description": description,
                "storage_backend": "local",
                "created_at": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ [Unified Manager] Local save failed: {e}")
            raise e
    
    def _get_local_storage_path(self, entity_type: str, company_id: int) -> Path:
        """Get the local storage path for a file"""
        current_date = datetime.now().strftime("%Y-%m-%d")
        return self.attachments_dir / entity_type / f"company_{company_id}" / current_date
    
    def get_attachment(self, attachment_id: int, company_id: Optional[int] = None) -> Tuple[bytes, str, str]:
        """Retrieve an attachment by ID from configured storage backend"""
        
        # Get attachment metadata from database
        query = """
            SELECT filename, original_filename, file_size, mime_type, 
                   file_path, company_id, storage_backend, s3_bucket, s3_key
            FROM public.attachments 
            WHERE id = %s
        """
        params = [attachment_id]
        
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            raise FileNotFoundError(f"Attachment {attachment_id} not found")
        
        attachment = result[0]
        storage_backend = attachment.get('storage_backend', 'local')
        
        if storage_backend == "s3":
            return self._get_from_s3(attachment)
        else:
            return self._get_from_local(attachment)
    
    def _get_from_s3(self, attachment: Dict[str, Any]) -> Tuple[bytes, str, str]:
        """Retrieve attachment from S3"""
        try:
            s3_key = attachment.get('s3_key') or attachment['file_path']
            file_content, metadata = self.s3_manager.download_file(s3_key)
            
            print(f"📎 [Unified Manager] Retrieved from S3: {s3_key}")
            
            return file_content, attachment['original_filename'], attachment['mime_type']
            
        except Exception as e:
            print(f"❌ [Unified Manager] S3 retrieval failed: {e}")
            raise FileNotFoundError(f"S3 file not found: {attachment.get('s3_key', attachment['file_path'])}")
    
    def _get_from_local(self, attachment: Dict[str, Any]) -> Tuple[bytes, str, str]:
        """Retrieve attachment from local storage"""
        try:
            file_path = self.attachments_dir / attachment['file_path']
            
            if not file_path.exists():
                raise FileNotFoundError(f"Local file not found: {file_path}")
            
            with open(file_path, 'rb') as f:
                file_content = f.read()
            
            print(f"📎 [Unified Manager] Retrieved from local: {attachment['file_path']}")
            
            return file_content, attachment['original_filename'], attachment['mime_type']
            
        except Exception as e:
            print(f"❌ [Unified Manager] Local retrieval failed: {e}")
            raise FileNotFoundError(f"Local file not found: {attachment['file_path']}")
    
    def list_attachments(self, entity_type: str, entity_id: int, company_id: int) -> List[Dict[str, Any]]:
        """List all attachments for a specific entity"""
        
        query = """
            SELECT id, filename, original_filename, file_size, mime_type, 
                   category, description, created_at, file_path, entity_type, entity_id,
                   storage_backend, s3_bucket, s3_key
            FROM public.attachments 
            WHERE entity_type = %s AND entity_id = %s AND company_id = %s
            ORDER BY created_at DESC
        """
        
        results = execute_query(query, (entity_type, entity_id, company_id), fetch=True)
        attachments = []
        result_list = results if isinstance(results, list) else [results] if results else []

        for row in result_list:
            if isinstance(row, tuple):
                attachment = {
                    'id': row[0], 'filename': row[1], 'original_filename': row[2],
                    'file_size': row[3], 'mime_type': row[4], 'category': row[5],
                    'description': row[6], 'created_at': row[7], 'file_path': row[8],
                    'entity_type': row[9], 'entity_id': row[10], 
                    'storage_backend': row[11] if len(row) > 11 else 'local',
                    's3_bucket': row[12] if len(row) > 12 else None,
                    's3_key': row[13] if len(row) > 13 else None
                }
            else:
                attachment = row
            
            # Verify file existence based on storage backend
            storage_backend = attachment.get('storage_backend', 'local')
            if storage_backend == "s3":
                # For S3, we'll assume file exists (can add S3 check if needed)
                attachment['file_exists'] = True
            else:
                # Check local file existence
                if attachment.get('file_path'):
                    file_path = self.attachments_dir / attachment['file_path']
                    attachment['file_exists'] = file_path.exists()
                else:
                    attachment['file_exists'] = False
            
            # Add file size in human readable format
            attachment['file_size_human'] = self._format_file_size(attachment['file_size'])
            
            attachments.append(attachment)
        
        print(f"📎 [Unified Manager] Listed {len(attachments)} attachments for {entity_type} {entity_id}")
        
        return attachments
    
    def delete_attachment(self, attachment_id: int, company_id: Optional[int] = None) -> bool:
        """Delete an attachment from storage and database"""
        
        # Get attachment info
        query = """
            SELECT file_path, company_id, storage_backend, s3_bucket, s3_key 
            FROM public.attachments WHERE id = %s
        """
        params = [attachment_id]
        
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            return False
        
        attachment_info = result[0]
        storage_backend = attachment_info.get('storage_backend', 'local')
        
        # Delete from storage
        if storage_backend == "s3":
            s3_key = attachment_info.get('s3_key') or attachment_info['file_path']
            try:
                self.s3_manager.delete_file(s3_key)
                print(f"📎 [Unified Manager] Deleted from S3: {s3_key}")
            except Exception as e:
                print(f"⚠️ [Unified Manager] S3 delete failed: {e}")
        else:
            # Delete from local storage
            local_file_path = self.attachments_dir / attachment_info['file_path']
            if local_file_path.exists():
                try:
                    local_file_path.unlink()
                    print(f"📎 [Unified Manager] Deleted from local: {attachment_info['file_path']}")
                except Exception as e:
                    print(f"⚠️ [Unified Manager] Local delete failed: {e}")
        
        # Delete metadata from database
        delete_query = "DELETE FROM public.attachments WHERE id = %s"
        delete_params = [attachment_id]
        
        if company_id is not None:
            delete_query += " AND company_id = %s"
            delete_params.append(company_id)
        
        execute_query(delete_query, delete_params, fetch=False)
        
        print(f"✅ [Unified Manager] Attachment {attachment_id} deleted")
        return True
    
    def _save_metadata_to_db(self, entity_type: str, entity_id: int, company_id: int,
                            original_filename: str, unique_filename: str, file_size: int,
                            mime_type: str, category: str, relative_path: str,
                            description: Optional[str] = None, storage_backend: str = "local",
                            s3_bucket: Optional[str] = None, s3_key: Optional[str] = None) -> int:
        """Save attachment metadata to database with storage backend info"""
        
        query = """
            INSERT INTO public.attachments 
            (entity_type, entity_id, company_id, filename, original_filename, 
             file_size, mime_type, category, file_path, description, created_at,
             storage_backend, s3_bucket, s3_key) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """
        
        params = (
            entity_type, entity_id, company_id, unique_filename, original_filename,
            file_size, mime_type, category, relative_path, description, datetime.now(),
            storage_backend, s3_bucket, s3_key
        )
        
        result = execute_query(query, params, fetch=True)
        
        print(f"📎 [Unified Manager] Metadata saved to DB: {original_filename} ({storage_backend})")
        
        if result:
            if isinstance(result, tuple):
                return result[0]
            elif isinstance(result, list) and len(result) > 0:
                if isinstance(result[0], dict):
                    return result[0]['id']
                elif isinstance(result[0], (list, tuple)):
                    return result[0][0]
                else:
                    return result[0]
        
        return None
    
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
    
    def get_attachment_stats(self, company_id: Optional[int] = None) -> Dict[str, Any]:
        """Get attachment storage statistics"""
        
        query = """
            SELECT 
                category,
                storage_backend,
                COUNT(*) as count,
                COALESCE(SUM(file_size), 0) as total_size
            FROM public.attachments
        """
        
        params = []
        if company_id is not None:
            query += " WHERE company_id = %s"
            params.append(company_id)
        
        query += " GROUP BY category, storage_backend"
        
        results = execute_query(query, params, fetch=True)
        result_list = results if isinstance(results, list) else [results] if results else []
        
        stats = {
            "total_attachments": 0,
            "total_size_bytes": 0,
            "by_category": {},
            "by_storage_backend": {},
            "supported_types": list(self.SUPPORTED_TYPES.keys()),
            "active_backend": self.storage_backend
        }
        
        for row in result_list:
            if isinstance(row, tuple):
                category, storage_backend, count, total_size = row
            else:
                category = row['category']
                storage_backend = row.get('storage_backend', 'local')
                count = row['count']
                total_size = row['total_size']
            
            # By category stats
            if category not in stats["by_category"]:
                stats["by_category"][category] = {
                    "count": 0,
                    "total_size_bytes": 0,
                    "total_size_human": "0 B"
                }
            
            stats["by_category"][category]["count"] += count
            stats["by_category"][category]["total_size_bytes"] += total_size
            stats["by_category"][category]["total_size_human"] = self._format_file_size(
                stats["by_category"][category]["total_size_bytes"]
            )
            
            # By storage backend stats
            if storage_backend not in stats["by_storage_backend"]:
                stats["by_storage_backend"][storage_backend] = {
                    "count": 0,
                    "total_size_bytes": 0,
                    "total_size_human": "0 B"
                }
            
            stats["by_storage_backend"][storage_backend]["count"] += count
            stats["by_storage_backend"][storage_backend]["total_size_bytes"] += total_size
            stats["by_storage_backend"][storage_backend]["total_size_human"] = self._format_file_size(
                stats["by_storage_backend"][storage_backend]["total_size_bytes"]
            )
            
            stats["total_attachments"] += count
            stats["total_size_bytes"] += total_size
        
        stats["total_size_human"] = self._format_file_size(stats["total_size_bytes"])
        
        return stats
    
    def migrate_to_s3(self, company_id: Optional[int] = None) -> Dict[str, Any]:
        """Migrate local attachments to S3"""
        if self.storage_backend != "s3":
            raise Exception("S3 backend not initialized")
        
        # Query for local attachments
        query = """
            SELECT id, entity_type, entity_id, company_id, original_filename, 
                   file_path, file_size, mime_type, category, description
            FROM public.attachments 
            WHERE storage_backend = 'local' OR storage_backend IS NULL
        """
        
        params = []
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        results = execute_query(query, params, fetch=True)
        result_list = results if isinstance(results, list) else [results] if results else []
        
        migration_stats = {
            "total_files": len(result_list),
            "migrated": 0,
            "failed": 0,
            "errors": []
        }
        
        for row in result_list:
            try:
                if isinstance(row, tuple):
                    attachment = {
                        'id': row[0], 'entity_type': row[1], 'entity_id': row[2],
                        'company_id': row[3], 'original_filename': row[4],
                        'file_path': row[5], 'file_size': row[6], 'mime_type': row[7],
                        'category': row[8], 'description': row[9]
                    }
                else:
                    attachment = row
                
                # Read local file
                local_file_path = self.attachments_dir / attachment['file_path']
                if not local_file_path.exists():
                    raise FileNotFoundError(f"Local file not found: {local_file_path}")
                
                with open(local_file_path, 'rb') as f:
                    file_content = f.read()
                
                # Upload to S3
                s3_result = self.s3_manager.upload_file(
                    file_content, 
                    attachment['entity_type'], 
                    attachment['company_id'], 
                    attachment['original_filename'], 
                    attachment['description']
                )
                
                # Update database record
                update_query = """
                    UPDATE public.attachments 
                    SET storage_backend = 's3', s3_bucket = %s, s3_key = %s, 
                        file_path = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """
                execute_query(update_query, (
                    s3_result['bucket_name'], 
                    s3_result['s3_key'], 
                    s3_result['s3_key'],  # Update file_path to S3 key
                    attachment['id']
                ), fetch=False)
                
                # Optionally delete local file after successful migration
                try:
                    local_file_path.unlink()
                    print(f"🗑️ [Migration] Deleted local file: {local_file_path}")
                except Exception as e:
                    print(f"⚠️ [Migration] Could not delete local file: {e}")
                
                migration_stats["migrated"] += 1
                print(f"✅ [Migration] Migrated: {attachment['original_filename']} → S3")
                
            except Exception as e:
                migration_stats["failed"] += 1
                error_msg = f"Failed to migrate attachment ID {attachment['id']}: {str(e)}"
                migration_stats["errors"].append(error_msg)
                print(f"❌ [Migration] {error_msg}")
        
        return migration_stats
