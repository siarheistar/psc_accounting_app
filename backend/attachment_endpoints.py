"""
Attachment API Endpoints for PSC Accounting
Replaces the old PDF-specific document endpoints with universal attachment support
"""

from fastapi import HTTPException, UploadFile, File, Query, Form
from fastapi.responses import StreamingResponse
from typing import Optional, List
import io
from attachment_manager import AttachmentManager

# Initialize attachment manager
attachment_manager = AttachmentManager()

async def upload_attachment(
    entity_type: str = Query(..., description="Type of entity (invoice, expense, payroll, bank_statement)"),
    entity_id: int = Query(..., description="ID of the entity"),
    company_id: int = Query(..., description="Company ID"),
    file: UploadFile = File(..., description="File to upload"),
    description: Optional[str] = Form(None, description="Optional description for the attachment")
):
    """Upload an attachment file for any entity type"""
    
    print(f"📎 [Backend] Attachment upload request:")
    print(f"   Entity: {entity_type} #{entity_id}")
    print(f"   Company: {company_id}")
    print(f"   File: {file.filename} ({file.content_type})")
    print(f"   Description: {description or 'None'}")
    
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is required")
    
    try:
        # Read file content
        file_content = await file.read()
        file_size = len(file_content)
        
        print(f"📊 File size: {file_size:,} bytes")
        
        # Validate file using attachment manager
        file_info = attachment_manager.get_file_info(file.filename)
        is_valid, error_message = attachment_manager.validate_file(file.filename, file_size)
        
        if not is_valid:
            raise HTTPException(status_code=400, detail=error_message)
        
        # Save attachment
        attachment_data = attachment_manager.save_attachment(
            file_content=file_content,
            entity_type=entity_type,
            entity_id=entity_id,
            company_id=company_id,
            original_filename=file.filename,
            description=description
        )
        
        print(f"✅ [Backend] Attachment uploaded successfully with ID: {attachment_data['id']}")
        
        return {
            "id": attachment_data["id"],
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "filename": attachment_data["filename"],
            "original_filename": attachment_data["original_filename"],
            "file_size": attachment_data["file_size"],
            "file_size_human": attachment_manager._format_file_size(attachment_data["file_size"]),
            "mime_type": attachment_data["mime_type"],
            "category": attachment_data["category"],
            "description": attachment_data["description"],
            "uploaded_at": attachment_data["created_at"],  # Map created_at to uploaded_at for frontend compatibility
            "message": f"Attachment uploaded successfully ({file_info['category']} file)"
        }
        
    except ValueError as e:
        print(f"❌ [Backend] Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"❌ [Backend] Upload error: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

async def download_attachment(
    attachment_id: int,
    company_id: Optional[int] = None
):
    """Download an attachment file by ID"""
    
    print(f"📥 [Backend] Download request for attachment {attachment_id}")
    
    try:
        # Get attachment file
        file_content, original_filename, mime_type = attachment_manager.get_attachment(
            attachment_id, company_id
        )
        
        print(f"📥 [Backend] Serving file: {original_filename} ({len(file_content):,} bytes)")
        
        # Create file stream
        file_stream = io.BytesIO(file_content)
        
        # Determine if file should be displayed inline or downloaded
        # For downloads, always use attachment to force download behavior
        disposition = "attachment"
        
        # Properly encode filename for HTTP header (handle Unicode characters)
        import urllib.parse
        try:
            # Try to encode as ASCII first (simple case)
            encoded_filename = original_filename.encode('ascii').decode('ascii')
            content_disposition = f'{disposition}; filename="{encoded_filename}"'
        except UnicodeEncodeError:
            # Use RFC 5987 encoding for non-ASCII filenames
            encoded_filename = urllib.parse.quote(original_filename.encode('utf-8'))
            content_disposition = f'{disposition}; filename*=UTF-8\'\'{encoded_filename}'
        
        print(f"📥 [Backend] Content-Disposition: {content_disposition}")
        
        # Return file response
        return StreamingResponse(
            io.BytesIO(file_content),
            media_type=mime_type,
            headers={
                "Content-Disposition": content_disposition,
                "Content-Length": str(len(file_content))
            }
        )
        
    except FileNotFoundError as e:
        print(f"❌ [Backend] File not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"❌ [Backend] Download error: {e}")
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")

async def list_attachments(
    entity_type: str = Query(..., description="Type of entity"),
    entity_id: int = Query(..., description="ID of the entity"),
    company_id: int = Query(..., description="Company ID")
):
    """List all attachments for a specific entity"""
    
    print(f"📋 [Backend] List attachments for {entity_type} #{entity_id} (company {company_id})")
    
    try:
        attachments = attachment_manager.list_attachments(entity_type, entity_id, company_id)
        
        print(f"📋 [Backend] Found {len(attachments)} attachments")
        
        return {
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "attachments": attachments,
            "total_count": len(attachments),
            "total_size_bytes": sum(att['file_size'] for att in attachments),
            "total_size_human": attachment_manager._format_file_size(
                sum(att['file_size'] for att in attachments)
            )
        }
        
    except Exception as e:
        print(f"❌ [Backend] List error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list attachments: {str(e)}")

async def delete_attachment(
    attachment_id: int,
    company_id: Optional[int] = None
):
    """Delete an attachment file"""
    
    print(f"🗑️ [Backend] Delete request for attachment {attachment_id}")
    
    try:
        success = attachment_manager.delete_attachment(attachment_id, company_id)
        
        if not success:
            raise HTTPException(status_code=404, detail="Attachment not found")
        
        print(f"✅ [Backend] Attachment {attachment_id} deleted successfully")
        
        return {
            "id": attachment_id,
            "message": "Attachment deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete error: {e}")
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

async def get_attachment_info(
    attachment_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Get attachment metadata without downloading the file"""
    
    print(f"ℹ️ [Backend] Info request for attachment {attachment_id}")
    
    try:
        # Get attachment metadata from database
        from database import execute_query
        
        query = """
            SELECT id, entity_type, entity_id, company_id, filename, original_filename, 
                   file_size, mime_type, category, description, created_at
            FROM public.attachments 
            WHERE id = %s
        """
        params = [attachment_id]
        
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            raise HTTPException(status_code=404, detail="Attachment not found")
        
        # Handle both tuple and dict results
        if isinstance(result, tuple):
            attachment = {
                'id': result[0], 'entity_type': result[1], 'entity_id': result[2],
                'company_id': result[3], 'filename': result[4], 'original_filename': result[5],
                'file_size': result[6], 'mime_type': result[7], 'category': result[8],
                'description': result[9], 'created_at': result[10]
            }
        else:
            attachment = result
        
        # Add human readable file size
        attachment['file_size_human'] = attachment_manager._format_file_size(attachment['file_size'])
        
        print(f"ℹ️ [Backend] Returning info for: {attachment['original_filename']}")
        
        return attachment
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Info error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get attachment info: {str(e)}")

async def get_attachment_stats(
    company_id: Optional[int] = Query(None, description="Company ID to filter stats")
):
    """Get attachment storage statistics"""
    
    print(f"📊 [Backend] Stats request" + (f" for company {company_id}" if company_id else " (all companies)"))
    
    try:
        stats = attachment_manager.get_attachment_stats(company_id)
        
        print(f"📊 [Backend] Returning stats: {stats['total_attachments']} attachments, {stats['total_size_human']}")
        
        return stats
        
    except Exception as e:
        print(f"❌ [Backend] Stats error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")

async def update_attachment_description(
    attachment_id: int,
    description: str = Form(..., description="New description for the attachment"),
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Update the description of an attachment"""
    
    print(f"✏️ [Backend] Update description for attachment {attachment_id}")
    
    try:
        from database import execute_query
        
        # Update description in database
        query = "UPDATE attachments SET description = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s"
        params = [description, attachment_id]
        
        if company_id is not None:
            query += " AND company_id = %s"
            params.append(company_id)
        
        query += " RETURNING id"
        
        result = execute_query(query, params, fetch=True)
        
        if not result:
            raise HTTPException(status_code=404, detail="Attachment not found")
        
        print(f"✅ [Backend] Description updated for attachment {attachment_id}")
        
        return {
            "id": attachment_id,
            "description": description,
            "message": "Description updated successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Update error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update description: {str(e)}")
