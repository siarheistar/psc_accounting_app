"""
PDF Storage Manager for PSC Accounting API
Supports both local file system and database storage
"""

import os
import uuid
import base64
from pathlib import Path
from typing import Tuple, Optional, Dict, Any
from datetime import datetime
from database import execute_query

class PDFStorageManager:
    """Manages PDF storage with support for local and database backends"""
    
    def __init__(self, storage_mode: str = "local", upload_dir: str = "uploads"):
        self.storage_mode = storage_mode.lower()
        self.upload_dir = Path(upload_dir)
        self.pdf_dir = self.upload_dir / "pdfs"
        
        # Ensure directories exist for local storage
        if self.storage_mode == "local":
            self.pdf_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"📁 [PDF Storage] Initialized with mode: {self.storage_mode}")
        if self.storage_mode == "local":
            print(f"📁 [PDF Storage] Local directory: {self.pdf_dir.absolute()}")
    
    def generate_unique_filename(self, original_filename: str) -> str:
        """Generate a unique filename for storage"""
        file_ext = Path(original_filename).suffix
        unique_id = str(uuid.uuid4())
        return f"{unique_id}{file_ext}"
    
    def validate_pdf(self, file_content: bytes) -> bool:
        """Validate that file content is a PDF"""
        return file_content.startswith(b'%PDF')
    
    def save_pdf(self, file_content: bytes, entity_type: str, entity_id: int, 
                 company_id: int, original_filename: str) -> Dict[str, Any]:
        """
        Save PDF file using configured storage method
        Returns document metadata including ID
        """
        
        if not self.validate_pdf(file_content):
            raise ValueError("Invalid PDF file (missing PDF header)")
        
        file_size = len(file_content)
        
        if self.storage_mode == "local":
            return self._save_to_local(
                file_content, entity_type, entity_id, company_id, 
                original_filename, file_size
            )
        elif self.storage_mode == "database":
            return self._save_to_database(
                file_content, entity_type, entity_id, company_id, 
                original_filename, file_size
            )
        else:
            raise ValueError(f"Invalid storage mode: {self.storage_mode}")
    
    def _save_to_local(self, file_content: bytes, entity_type: str, entity_id: int,
                      company_id: int, original_filename: str, file_size: int) -> Dict[str, Any]:
        """Save PDF to local file system"""
        
        # Create company-specific directory structure
        company_dir = self.pdf_dir / f"company_{company_id}" / entity_type
        company_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate unique filename
        unique_filename = self.generate_unique_filename(original_filename)
        file_path = company_dir / unique_filename
        
        # Save file to disk
        with open(file_path, 'wb') as f:
            f.write(file_content)
        
        # Store relative path for database
        relative_path = str(file_path.relative_to(self.pdf_dir))
        
        # Save metadata to database
        document_id = self._save_metadata_to_db(
            entity_type, entity_id, company_id, original_filename,
            unique_filename, file_size, "local", relative_path
        )
        
        print(f"📁 [Local Storage] Saved: {relative_path}")
        
        return {
            "id": document_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "filename": unique_filename,
            "original_filename": original_filename,
            "file_size": file_size,
            "storage_type": "local",
            "file_path": relative_path
        }
    
    def _save_to_database(self, file_content: bytes, entity_type: str, entity_id: int,
                         company_id: int, original_filename: str, file_size: int) -> Dict[str, Any]:
        """Save PDF to database as base64"""
        
        # Encode file content as base64
        encoded_content = base64.b64encode(file_content).decode('utf-8')
        
        # Save to database with file data
        query = """
            INSERT INTO document_attachments 
            (entity_type, entity_id, company_id, filename, original_filename, 
             file_data, file_size, mime_type, storage_type, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """
        
        params = (
            entity_type, entity_id, company_id, original_filename, original_filename,
            encoded_content, file_size, "application/pdf", "database", datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        document_id = result[0] if isinstance(result, tuple) else result['id']
        
        print(f"💾 [Database Storage] Saved with ID: {document_id}")
        
        return {
            "id": document_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "filename": original_filename,
            "original_filename": original_filename,
            "file_size": file_size,
            "storage_type": "database"
        }
    
    def _save_metadata_to_db(self, entity_type: str, entity_id: int, company_id: int,
                            original_filename: str, unique_filename: str, file_size: int,
                            storage_type: str, file_path: Optional[str] = None) -> int:
        """Save PDF metadata to database (for local storage)"""
        
        query = """
            INSERT INTO document_attachments 
            (entity_type, entity_id, company_id, filename, original_filename, 
             file_size, mime_type, storage_type, file_path, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """
        
        params = (
            entity_type, entity_id, company_id, unique_filename, original_filename,
            file_size, "application/pdf", storage_type, file_path, datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        return result[0] if isinstance(result, tuple) else result['id']
    
    def get_document(self, document_id: int) -> Tuple[bytes, str, str]:
        """
        Retrieve a document by ID
        Returns: (file_content, original_filename, mime_type)
        """
        
        # Get document metadata
        query = """
            SELECT filename, original_filename, file_size, mime_type, storage_type, 
                   file_path, file_data
            FROM document_attachments 
            WHERE id = %s
        """
        
        result = execute_query(query, (document_id,), fetch=True)
        
        if not result:
            raise FileNotFoundError(f"Document {document_id} not found")
        
        # Handle both tuple and dict results
        if isinstance(result, tuple):
            doc = {
                'filename': result[0], 'original_filename': result[1], 'file_size': result[2],
                'mime_type': result[3], 'storage_type': result[4], 'file_path': result[5],
                'file_data': result[6]
            }
        else:
            doc = result
        
        storage_type = doc['storage_type']
        original_filename = doc['original_filename']
        mime_type = doc['mime_type']
        
        if storage_type == "local":
            # Read from file system
            file_path = self.pdf_dir / doc['file_path']
            
            if not file_path.exists():
                raise FileNotFoundError(f"File not found on disk: {file_path}")
            
            with open(file_path, 'rb') as f:
                file_content = f.read()
            
            print(f"📁 [Local Storage] Retrieved: {doc['file_path']}")
            
        elif storage_type == "database":
            # Decode from database
            file_data = doc['file_data']
            
            if isinstance(file_data, str):
                file_content = base64.b64decode(file_data)
            elif isinstance(file_data, bytes):
                file_content = file_data
            else:
                raise ValueError("Invalid file data format in database")
            
            print(f"💾 [Database Storage] Retrieved: {len(file_content):,} bytes")
            
        else:
            raise ValueError(f"Unknown storage type: {storage_type}")
        
        return file_content, original_filename, mime_type
    
    def list_documents(self, entity_type: str, entity_id: int, company_id: int) -> list:
        """List all documents for a specific entity"""
        
        query = """
            SELECT id, filename, original_filename, file_size, mime_type, 
                   storage_type, created_at
            FROM document_attachments 
            WHERE entity_type = %s AND entity_id = %s AND company_id = %s
            ORDER BY created_at DESC
        """
        
        results = execute_query(query, (entity_type, entity_id, company_id), fetch=True)
        
        documents = []
        result_list = results if isinstance(results, list) else [results] if results else []
        
        for row in result_list:
            if isinstance(row, tuple):
                doc = {
                    'id': row[0], 'filename': row[1], 'original_filename': row[2],
                    'file_size': row[3], 'mime_type': row[4], 'storage_type': row[5],
                    'created_at': row[6]
                }
            else:
                doc = row
            
            documents.append(doc)
        
        return documents
    
    def delete_document(self, document_id: int) -> bool:
        """Delete a document from storage and database"""
        
        # Get document info
        query = "SELECT storage_type, file_path FROM document_attachments WHERE id = %s"
        result = execute_query(query, (document_id,), fetch=True)
        
        if not result:
            return False
        
        storage_type = result[0] if isinstance(result, tuple) else result['storage_type']
        file_path = result[1] if isinstance(result, tuple) else result['file_path']
        
        # Delete from storage
        if storage_type == "local" and file_path:
            local_file_path = self.pdf_dir / file_path
            if local_file_path.exists():
                local_file_path.unlink()
                print(f"📁 [Local Storage] Deleted: {file_path}")
            else:
                print(f"⚠️ [Local Storage] File not found: {file_path}")
        
        # Delete from database
        delete_query = "DELETE FROM document_attachments WHERE id = %s"
        execute_query(delete_query, (document_id,), fetch=False)
        
        print(f"✅ [PDF Storage] Document {document_id} deleted")
        return True
    
    def get_storage_stats(self) -> Dict[str, Any]:
        """Get storage statistics"""
        
        # Get document count and total size from database
        query = """
            SELECT 
                COUNT(*) as total_documents,
                COALESCE(SUM(file_size), 0) as total_size,
                storage_type
            FROM document_attachments 
            GROUP BY storage_type
        """
        
        results = execute_query(query, fetch=True)
        result_list = results if isinstance(results, list) else [results] if results else []
        
        stats = {
            "storage_mode": self.storage_mode,
            "by_storage_type": {}
        }
        
        for row in result_list:
            if isinstance(row, tuple):
                storage_type = row[2]
                stats["by_storage_type"][storage_type] = {
                    "documents": row[0],
                    "total_size_bytes": row[1]
                }
            else:
                storage_type = row['storage_type']
                stats["by_storage_type"][storage_type] = {
                    "documents": row['total_documents'],
                    "total_size_bytes": row['total_size']
                }
        
        # Add local storage disk usage if applicable
        if self.storage_mode == "local" and self.pdf_dir.exists():
            local_size = sum(f.stat().st_size for f in self.pdf_dir.rglob('*') if f.is_file())
            stats["local_disk_usage_bytes"] = local_size
        
        return stats
