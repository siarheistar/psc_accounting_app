"""
Storage Management API Endpoints for PSC Accounting
Provides endpoints for managing storage backends and data migration
"""

from fastapi import HTTPException, Query
from typing import Optional, Dict, Any
from unified_attachment_manager import UnifiedAttachmentManager
import os

async def get_storage_info():
    """Get current storage configuration and statistics"""
    
    try:
        current_backend = os.getenv("STORAGE_BACKEND", "local")
        s3_bucket = os.getenv("S3_BUCKET", "psc-accounting")
        s3_region = os.getenv("AWS_REGION", "us-east-1")
        
        # Initialize manager to get stats
        manager = UnifiedAttachmentManager(
            storage_backend=current_backend,
            s3_bucket=s3_bucket,
            s3_region=s3_region
        )
        
        stats = manager.get_attachment_stats()
        
        info = {
            "current_backend": current_backend,
            "s3_configuration": {
                "bucket": s3_bucket,
                "region": s3_region,
                "configured": bool(os.getenv("AWS_ACCESS_KEY_ID"))
            },
            "statistics": stats,
            "available_backends": ["local", "s3"]
        }
        
        return info
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get storage info: {str(e)}")

async def migrate_to_s3(
    company_id: Optional[int] = Query(None, description="Company ID to migrate (all if not specified)"),
    dry_run: bool = Query(False, description="Preview migration without actually moving files")
):
    """Migrate local attachments to S3 storage"""
    
    try:
        current_backend = os.getenv("STORAGE_BACKEND", "local")
        if current_backend != "s3":
            # Temporarily create S3 manager for migration
            s3_manager = UnifiedAttachmentManager(
                storage_backend="s3",
                s3_bucket=os.getenv("S3_BUCKET", "psc-accounting"),
                s3_region=os.getenv("AWS_REGION", "us-east-1")
            )
        else:
            s3_manager = UnifiedAttachmentManager(
                storage_backend="s3",
                s3_bucket=os.getenv("S3_BUCKET", "psc-accounting"),
                s3_region=os.getenv("AWS_REGION", "us-east-1")
            )
        
        if dry_run:
            # Count files that would be migrated
            from database import execute_query
            
            query = """
                SELECT COUNT(*) as count, COALESCE(SUM(file_size), 0) as total_size
                FROM public.attachments 
                WHERE storage_backend = 'local' OR storage_backend IS NULL
            """
            params = []
            
            if company_id is not None:
                query += " AND company_id = %s"
                params.append(company_id)
            
            result = execute_query(query, params, fetch=True)
            
            if result:
                count = result[0]['count'] if isinstance(result[0], dict) else result[0][0]
                total_size = result[0]['total_size'] if isinstance(result[0], dict) else result[0][1]
            else:
                count = 0
                total_size = 0
            
            return {
                "dry_run": True,
                "files_to_migrate": count,
                "total_size_bytes": total_size,
                "total_size_human": s3_manager._format_file_size(total_size),
                "company_id": company_id,
                "message": f"Would migrate {count} files ({s3_manager._format_file_size(total_size)})"
            }
        else:
            # Perform actual migration
            migration_result = s3_manager.migrate_to_s3(company_id)
            
            return {
                "dry_run": False,
                "migration_result": migration_result,
                "company_id": company_id,
                "message": f"Migration completed: {migration_result['migrated']} files migrated, {migration_result['failed']} failed"
            }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Migration failed: {str(e)}")

async def test_s3_connection():
    """Test S3 connection and bucket access"""
    
    try:
        from s3_storage import S3StorageManager
        
        s3_bucket = os.getenv("S3_BUCKET", "psc-accounting")
        s3_region = os.getenv("AWS_REGION", "us-east-1")
        
        # Test S3 connection
        s3_manager = S3StorageManager(
            bucket_name=s3_bucket,
            region_name=s3_region
        )
        
        # Get bucket stats to verify access
        stats = s3_manager.get_bucket_stats("attachments/")
        
        return {
            "connection_status": "success",
            "bucket": s3_bucket,
            "region": s3_region,
            "bucket_stats": stats,
            "message": "S3 connection successful"
        }
        
    except Exception as e:
        return {
            "connection_status": "failed",
            "bucket": os.getenv("S3_BUCKET", "psc-accounting"),
            "region": os.getenv("AWS_REGION", "us-east-1"),
            "error": str(e),
            "message": "S3 connection failed"
        }

async def cleanup_storage(
    storage_backend: str = Query(..., description="Storage backend to clean up (local or s3)"),
    company_id: Optional[int] = Query(None, description="Company ID to clean up (all if not specified)"),
    orphaned_only: bool = Query(True, description="Only clean up orphaned files (no database record)")
):
    """Clean up storage by removing orphaned or unused files"""
    
    try:
        if storage_backend not in ["local", "s3"]:
            raise HTTPException(status_code=400, detail="Storage backend must be 'local' or 's3'")
        
        manager = UnifiedAttachmentManager(
            storage_backend=storage_backend,
            s3_bucket=os.getenv("S3_BUCKET", "psc-accounting"),
            s3_region=os.getenv("AWS_REGION", "us-east-1")
        )
        
        cleanup_stats = {
            "storage_backend": storage_backend,
            "company_id": company_id,
            "orphaned_only": orphaned_only,
            "files_removed": 0,
            "space_freed_bytes": 0,
            "errors": []
        }
        
        if storage_backend == "local":
            # For local storage, check for files without database records
            from database import execute_query
            from pathlib import Path
            
            # Get all files in attachments directory
            attachments_dir = Path("uploads/attachments")
            if attachments_dir.exists():
                for file_path in attachments_dir.rglob("*"):
                    if file_path.is_file():
                        relative_path = str(file_path.relative_to(attachments_dir))
                        
                        # Check if file has database record
                        query = "SELECT id FROM public.attachments WHERE file_path = %s"
                        params = [relative_path]
                        
                        if company_id is not None:
                            query += " AND company_id = %s"
                            params.append(company_id)
                        
                        result = execute_query(query, params, fetch=True)
                        
                        if not result:  # Orphaned file
                            try:
                                file_size = file_path.stat().st_size
                                file_path.unlink()
                                cleanup_stats["files_removed"] += 1
                                cleanup_stats["space_freed_bytes"] += file_size
                            except Exception as e:
                                cleanup_stats["errors"].append(f"Failed to remove {relative_path}: {str(e)}")
        
        cleanup_stats["space_freed_human"] = manager._format_file_size(cleanup_stats["space_freed_bytes"])
        
        return cleanup_stats
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cleanup failed: {str(e)}")

async def get_storage_usage_by_company():
    """Get storage usage statistics grouped by company"""
    
    try:
        from database import execute_query
        
        query = """
            SELECT 
                company_id,
                storage_backend,
                COUNT(*) as file_count,
                COALESCE(SUM(file_size), 0) as total_size
            FROM public.attachments
            GROUP BY company_id, storage_backend
            ORDER BY company_id, storage_backend
        """
        
        results = execute_query(query, [], fetch=True)
        result_list = results if isinstance(results, list) else [results] if results else []
        
        usage_stats = {}
        
        for row in result_list:
            if isinstance(row, tuple):
                company_id, storage_backend, file_count, total_size = row
            else:
                company_id = row['company_id']
                storage_backend = row.get('storage_backend', 'local')
                file_count = row['file_count']
                total_size = row['total_size']
            
            if company_id not in usage_stats:
                usage_stats[company_id] = {
                    "company_id": company_id,
                    "total_files": 0,
                    "total_size_bytes": 0,
                    "by_backend": {}
                }
            
            usage_stats[company_id]["total_files"] += file_count
            usage_stats[company_id]["total_size_bytes"] += total_size
            usage_stats[company_id]["by_backend"][storage_backend] = {
                "file_count": file_count,
                "total_size_bytes": total_size,
                "total_size_human": UnifiedAttachmentManager._format_file_size(None, total_size)
            }
        
        # Add human readable totals
        for company_id, stats in usage_stats.items():
            stats["total_size_human"] = UnifiedAttachmentManager._format_file_size(None, stats["total_size_bytes"])
        
        return {
            "usage_by_company": list(usage_stats.values()),
            "total_companies": len(usage_stats)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get usage stats: {str(e)}")

# Static method reference fix for formatting
def _format_file_size_static(size_bytes: int) -> str:
    """Static method for file size formatting"""
    if size_bytes == 0:
        return "0 B"
    
    size_names = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024.0
        i += 1
    
    return f"{size_bytes:.1f} {size_names[i]}"

# Replace the broken static method calls
UnifiedAttachmentManager._format_file_size = lambda self, size: _format_file_size_static(size)
