"""
Universal Attachment Manager for PSC Accounting API
Supports all file types with local storage and comprehensive management
"""

import os
import uuid
import mimetypes
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
from database import execute_query

class AttachmentManager:
    """Manages file attachments with local storage and database metadata"""
    
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
    
    def __init__(self, upload_dir: str = "uploads"):
        self.upload_dir = Path(upload_dir)
        self.attachments_dir = self.upload_dir / "attachments"
        
        # Create directory structure organized by entity type and date
        self._create_directory_structure()
        
        print(f"📁 [Attachment Manager] Initialized")
        print(f"📁 [Attachment Manager] Base directory: {self.attachments_dir.absolute()}")
    
    def _create_directory_structure(self):
        """Create the directory structure organized by entity type"""
        
        # Base attachments directory
        self.attachments_dir.mkdir(parents=True, exist_ok=True)
        
        # Create entity type directories
        entity_types = ['invoice', 'expense', 'bank_statement', 'payroll']
        for entity_type in entity_types:
            entity_dir = self.attachments_dir / entity_type
            entity_dir.mkdir(exist_ok=True)
        
        print(f"📁 [Attachment Manager] Directory structure created for entity types: {entity_types}")
    
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
    
    def generate_unique_filename(self, original_filename: str) -> str:
        """Generate a unique filename while preserving the original extension"""
        file_ext = Path(original_filename).suffix
        unique_id = str(uuid.uuid4())
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{timestamp}_{unique_id}{file_ext}"
    
    def get_storage_path(self, entity_type: str, company_id: int) -> Path:
        """Get the storage path for a file organized by entity type, company, and date"""
        current_date = datetime.now().strftime("%Y-%m-%d")
        return self.attachments_dir / entity_type / f"company_{company_id}" / current_date
    
    def save_attachment(self, file_content: bytes, entity_type: str, entity_id: int, 
                       company_id: int, original_filename: str, 
                       description: Optional[str] = None) -> Dict[str, Any]:
        """
        Save attachment file to local storage with minimal database metadata
        No file content serialization - only path and metadata stored in DB
        """
        
        file_size = len(file_content)
        
        # Validate file
        is_valid, error_message = self.validate_file(original_filename, file_size)
        if not is_valid:
            raise ValueError(error_message)
        
        # Get file information
        try:
            file_info = self.get_file_info(original_filename)
            print(f"📎 [Attachment Manager] File info: {file_info}")
        except Exception as e:
            print(f"❌ [Attachment Manager] Error getting file info: {e}")
            raise e
        
        # Create storage directory organized by entity type, company, and date
        storage_path = self.get_storage_path(entity_type, company_id)
        storage_path.mkdir(parents=True, exist_ok=True)
        
        # Generate unique filename with timestamp
        timestamp = datetime.now().strftime("%H%M%S")
        file_ext = Path(original_filename).suffix
        unique_filename = f"{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
        file_path = storage_path / unique_filename
        
        # Save file to disk
        try:
            with open(file_path, 'wb') as f:
                f.write(file_content)
            print(f"📎 [Attachment Manager] File saved: {file_path}")
        except Exception as e:
            raise RuntimeError(f"Failed to save file to disk: {str(e)}")
        
        # Calculate relative path for database (from attachments root)
        relative_path = str(file_path.relative_to(self.attachments_dir))
        
        # Save minimal metadata to database (no file content)
        try:
            attachment_id = self._save_metadata_to_db(
                entity_type=entity_type,
                entity_id=entity_id,
                company_id=company_id,
                original_filename=original_filename,
                unique_filename=unique_filename,
                file_size=file_size,
                mime_type=file_info.get('mime_type', 'application/octet-stream'),
                category=file_info.get('category', 'other'),
                relative_path=relative_path,
                description=description
            )
            print(f"📎 [Attachment Manager] Got attachment_id: {attachment_id}, type: {type(attachment_id)}")
        except Exception as e:
            print(f"❌ [Attachment Manager] Error saving metadata: {e}")
            raise e
        
        return {
            "id": attachment_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "filename": unique_filename,
            "original_filename": original_filename,
            "file_size": file_size,
            "mime_type": file_info.get('mime_type', 'application/octet-stream'),
            "category": file_info.get('category', 'other'),
            "file_path": relative_path,
            "description": description,
            "created_at": datetime.now().isoformat()
        }
    
    def _save_metadata_to_db(self, entity_type: str, entity_id: int, company_id: int,
                            original_filename: str, unique_filename: str, file_size: int,
                            mime_type: str, category: str, relative_path: str,
                            description: Optional[str] = None) -> int:
        """Save attachment metadata to database (no file content)"""
        
        query = """
            INSERT INTO public.attachments 
            (entity_type, entity_id, company_id, filename, original_filename, 
             file_size, mime_type, category, file_path, description, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """
        
        params = (
            entity_type, entity_id, company_id, unique_filename, original_filename,
            file_size, mime_type, category, relative_path, description, datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        print(f"📎 [Attachment Manager] Metadata saved to DB for: {original_filename}")
        print(f"📎 [Attachment Manager] DB result: {result}, type: {type(result)}")
        
        if result:
            # For INSERT with RETURNING, result is a tuple (id,)
            if isinstance(result, tuple):
                return result[0]  # First element is the ID
            elif isinstance(result, list) and len(result) > 0:
                if isinstance(result[0], dict):
                    return result[0]['id']
                elif isinstance(result[0], (list, tuple)):
                    return result[0][0]
                else:
                    return result[0]
        
        return None
    
    def get_attachment(self, attachment_id: int, company_id: Optional[int] = None) -> Tuple[bytes, str, str]:
        """
        Retrieve an attachment by ID from local storage
        Returns: (file_content, original_filename, mime_type)
        """
        
        # Get attachment metadata from database
        query = """
            SELECT filename, original_filename, file_size, mime_type, 
                   file_path, company_id
            FROM public.attachments 
            WHERE id = %s
        """
        params = [attachment_id]
        
        # Add company filter if specified
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            raise FileNotFoundError(f"Attachment {attachment_id} not found")
        
        # Result is a list of dictionaries, get the first one
        attachment = result[0]
        
        # Read file from local storage
        file_path = self.attachments_dir / attachment['file_path']
        
        if not file_path.exists():
            raise FileNotFoundError(f"Attachment file not found on disk: {file_path}")
        
        try:
            with open(file_path, 'rb') as f:
                file_content = f.read()
        except Exception as e:
            raise RuntimeError(f"Failed to read attachment file: {str(e)}")
        
        print(f"📎 [Attachment Manager] Retrieved from local storage: {attachment['file_path']}")
        
        return file_content, attachment['original_filename'], attachment['mime_type']
    
    def list_attachments(self, entity_type: str, entity_id: int, company_id: int) -> List[Dict[str, Any]]:
        """List all attachments for a specific entity"""
        
        query = """
            SELECT id, filename, original_filename, file_size, mime_type, 
                   category, description, created_at, file_path, entity_type, entity_id
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
                    'entity_type': row[9], 'entity_id': row[10]
                }
            else:
                attachment = row
            
            # Verify file still exists on disk
            if attachment.get('file_path'):
                file_path = self.attachments_dir / attachment['file_path']
                attachment['file_exists'] = file_path.exists()
            else:
                attachment['file_exists'] = False
                
            # Add file size in human readable format
            attachment['file_size_human'] = self._format_file_size(attachment['file_size'])
            
            attachments.append(attachment)
        
        print(f"📎 [Attachment Manager] Listed {len(attachments)} attachments for {entity_type} {entity_id}")
        
        return attachments
    
    def delete_attachment(self, attachment_id: int, company_id: Optional[int] = None) -> bool:
        """Delete an attachment from storage and database"""
        
        # Get attachment info
        query = "SELECT file_path, company_id FROM public.attachments WHERE id = %s"
        params = [attachment_id]
        
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            return False
        
        # Extract file_path from the first result (list of dictionaries)
        attachment_info = result[0]
        file_path = attachment_info['file_path']
        
        # Delete file from storage
        local_file_path = self.attachments_dir / file_path
        if local_file_path.exists():
            try:
                local_file_path.unlink()
                print(f"📎 [Attachment Manager] Deleted file: {file_path}")
            except Exception as e:
                print(f"⚠️ [Attachment Manager] Failed to delete file: {e}")
        else:
            print(f"⚠️ [Attachment Manager] File not found: {file_path}")
        
        # Delete metadata from database
        delete_query = "DELETE FROM public.attachments WHERE id = %s"
        delete_params = [attachment_id]
        
        if company_id is not None:
            delete_query += " AND company_id = %s"
            delete_params.append(company_id)
        
        execute_query(delete_query, delete_params, fetch=False)
        
        print(f"✅ [Attachment Manager] Attachment {attachment_id} deleted")
        return True
    
    def get_attachment_stats(self, company_id: Optional[int] = None) -> Dict[str, Any]:
        """Get attachment storage statistics"""
        
        # Base query
        query = """
            SELECT 
                category,
                COUNT(*) as count,
                COALESCE(SUM(file_size), 0) as total_size
            FROM public.attachments
        """
        
        params = []
        if company_id is not None:
            query += " WHERE company_id = %s"
            params.append(company_id)
        
        query += " GROUP BY category"
        
        results = execute_query(query, params, fetch=True)
        result_list = results if isinstance(results, list) else [results] if results else []
        
        stats = {
            "total_attachments": 0,
            "total_size_bytes": 0,
            "by_category": {},
            "supported_types": list(self.SUPPORTED_TYPES.keys())
        }
        
        for row in result_list:
            if isinstance(row, tuple):
                category, count, total_size = row
            else:
                category = row['category']
                count = row['count']
                total_size = row['total_size']
            
            stats["by_category"][category] = {
                "count": count,
                "total_size_bytes": total_size,
                "total_size_human": self._format_file_size(total_size)
            }
            
            stats["total_attachments"] += count
            stats["total_size_bytes"] += total_size
        
        stats["total_size_human"] = self._format_file_size(stats["total_size_bytes"])
        
        # Add disk usage info
        if self.attachments_dir.exists():
            disk_usage = sum(f.stat().st_size for f in self.attachments_dir.rglob('*') if f.is_file())
            stats["disk_usage_bytes"] = disk_usage
            stats["disk_usage_human"] = self._format_file_size(disk_usage)
        
        return stats
    
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
    
    def migrate_from_database_storage(self, company_id: Optional[int] = None) -> Dict[str, Any]:
        """Migrate attachments from database storage to local storage"""
        
        # Query for database-stored documents
        query = """
            SELECT id, entity_type, entity_id, company_id, original_filename, 
                   file_data, file_size, mime_type
            FROM document_attachments 
            WHERE storage_type = 'database'
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
                    doc = {
                        'id': row[0], 'entity_type': row[1], 'entity_id': row[2],
                        'company_id': row[3], 'original_filename': row[4],
                        'file_data': row[5], 'file_size': row[6], 'mime_type': row[7]
                    }
                else:
                    doc = row
                
                # Decode file data
                import base64
                file_content = base64.b64decode(doc['file_data'])
                
                # Save as new attachment
                attachment_data = self.save_attachment(
                    file_content=file_content,
                    entity_type=doc['entity_type'],
                    entity_id=doc['entity_id'],
                    company_id=doc['company_id'],
                    original_filename=doc['original_filename'],
                    description=f"Migrated from database storage (original ID: {doc['id']})"
                )
                
                # Mark old record as migrated or delete it
                update_query = """
                    UPDATE document_attachments 
                    SET storage_type = 'migrated', 
                        file_path = %s,
                        updated_at = %s
                    WHERE id = %s
                """
                execute_query(update_query, (attachment_data['file_path'], datetime.now(), doc['id']), fetch=False)
                
                migration_stats["migrated"] += 1
                print(f"✅ Migrated: {doc['original_filename']} (ID: {doc['id']} → {attachment_data['id']})")
                
            except Exception as e:
                migration_stats["failed"] += 1
                error_msg = f"Failed to migrate file ID {doc['id']}: {str(e)}"
                migration_stats["errors"].append(error_msg)
                print(f"❌ {error_msg}")
        
        return migration_stats
    
    def cleanup_empty_directories(self):
        """Remove empty directories from the attachment storage"""
        
        for root, dirs, files in os.walk(self.attachments_dir, topdown=False):
            for dir_name in dirs:
                dir_path = Path(root) / dir_name
                try:
                    if not any(dir_path.iterdir()):  # Directory is empty
                        dir_path.rmdir()
                        print(f"🗑️ [Attachment Manager] Removed empty directory: {dir_path}")
                except Exception as e:
                    print(f"⚠️ [Attachment Manager] Could not remove directory {dir_path}: {e}")
