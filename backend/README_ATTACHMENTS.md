# PSC Accounting - Attachment Management System

## Overview

The new Attachment Management System replaces the old PDF-only document system with a comprehensive file management solution that supports multiple file types, better organization, and enhanced security.

## Features

### Supported File Types

#### Documents
- **PDF**: .pdf (up to 50MB)
- **Word**: .doc, .docx (up to 50MB)
- **Text**: .txt, .rtf (up to 10MB)
- **OpenDocument**: .odt (up to 50MB)

#### Spreadsheets
- **Excel**: .xls, .xlsx (up to 50MB)
- **CSV**: .csv (up to 10MB)
- **OpenDocument**: .ods (up to 50MB)

#### Images
- **Common formats**: .jpg, .jpeg, .png, .gif, .bmp, .tiff, .webp (up to 20MB)

#### Archives
- **Compressed files**: .zip, .rar, .7z, .tar, .gz (up to 100MB)

#### Other
- **Data files**: .xml, .json (up to 10MB)
- **Custom types**: Other file types accepted with 25MB default limit

### Security Features

- File type validation based on extension and MIME type
- File size limits per category
- Blocked dangerous file types (.exe, .bat, .cmd, .scr, .vbs, .js)
- Company-specific access control
- Secure file paths with UUID-based naming

### Storage Organization

```
uploads/
└── attachments/
    ├── document/
    │   └── company_1/
    │       ├── invoice/
    │       ├── expense/
    │       ├── payroll/
    │       └── bank_statement/
    ├── image/
    │   └── company_1/
    │       ├── invoice/
    │       ├── expense/
    │       ├── payroll/
    │       └── bank_statement/
    ├── spreadsheet/
    │   └── company_1/
    │       └── ...
    └── archive/
        └── company_1/
            └── ...
```

## API Endpoints

### New Attachment Endpoints

#### Upload Attachment
```http
POST /attachments/upload
Content-Type: multipart/form-data

Parameters:
- entity_type: string (invoice, expense, payroll, bank_statement)
- entity_id: integer
- company_id: integer
- file: file (any supported type)
- description: string (optional)
```

#### Download Attachment
```http
GET /attachments/download/{attachment_id}?company_id={company_id}
```

#### List Attachments
```http
GET /attachments/{entity_type}/{entity_id}?company_id={company_id}
```

#### Delete Attachment
```http
DELETE /attachments/{attachment_id}?company_id={company_id}
```

#### Get Attachment Info
```http
GET /attachments/info/{attachment_id}?company_id={company_id}
```

#### Update Description
```http
PUT /attachments/{attachment_id}/description
Content-Type: application/x-www-form-urlencoded

Parameters:
- description: string
- company_id: integer (optional)
```

#### Get Statistics
```http
GET /attachments/stats?company_id={company_id}
```

### Legacy Endpoints (Deprecated)

The old `/documents/*` endpoints are still available for backward compatibility but will show deprecation warnings:

- `POST /documents/upload` → Use `POST /attachments/upload`
- `GET /documents/download/{id}` → Use `GET /attachments/download/{id}`
- `GET /documents/{entity_type}/{entity_id}` → Use `GET /attachments/{entity_type}/{entity_id}`
- `DELETE /documents/{id}` → Use `DELETE /attachments/{id}`

## Migration Guide

### 1. Database Migration

Run the SQL migration script to create the new attachments table:

```bash
cd backend
psql -d your_database -f migration_attachments.sql
```

### 2. Data Migration

Use the Python migration script to migrate existing PDF documents:

```bash
cd backend

# Check what would be migrated (dry run)
python migrate_attachments.py --action analyze

# Set up new system
python migrate_attachments.py --action setup

# Migrate all documents
python migrate_attachments.py --action migrate

# Migrate for specific company only
python migrate_attachments.py --action migrate --company-id 1

# Clean up old data (after verifying migration)
python migrate_attachments.py --action cleanup --confirm

# View statistics
python migrate_attachments.py --action stats
```

### 3. Frontend Updates

Update your frontend code to use the new endpoints:

#### Old way (PDF only):
```javascript
// Upload PDF
const formData = new FormData();
formData.append('file', pdfFile);
fetch(`/documents/upload?entity_type=invoice&entity_id=1&company_id=1`, {
    method: 'POST',
    body: formData
});
```

#### New way (All file types):
```javascript
// Upload any file type
const formData = new FormData();
formData.append('file', anyFile);
formData.append('description', 'Receipt for office supplies');
fetch(`/attachments/upload?entity_type=invoice&entity_id=1&company_id=1`, {
    method: 'POST',
    body: formData
});
```

#### List attachments with enhanced metadata:
```javascript
// Get attachments for an invoice
const response = await fetch(`/attachments/invoice/1?company_id=1`);
const data = await response.json();

// Response includes:
// - attachments[]: Array of attachment objects
// - total_count: Number of attachments
// - total_size_bytes: Total size in bytes
// - total_size_human: Human-readable size
```

## Database Schema

### New Attachments Table

```sql
CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER NOT NULL,
    company_id INTEGER NOT NULL,
    filename VARCHAR(255) NOT NULL,          -- Unique filename on disk
    original_filename VARCHAR(255) NOT NULL, -- Original upload filename
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,           -- document, image, spreadsheet, etc.
    file_path TEXT NOT NULL,                 -- Relative path from attachments dir
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Legacy Document Attachments Table

The old `document_attachments` table is preserved for migration purposes with additional columns:
- `storage_type`: Tracks migration status
- `file_path`: For local file references
- `updated_at`: Timestamp tracking

## Configuration

### Environment Variables

```bash
# Storage mode (legacy setting, new system always uses local)
STORAGE_MODE=local

# Database connection
DATABASE_URL=postgresql://user:pass@localhost/db
```

### File Size Limits

File size limits are configured in `AttachmentManager.SUPPORTED_TYPES`:

```python
SUPPORTED_TYPES = {
    'pdf': {'category': 'document', 'max_size': 50 * 1024 * 1024},  # 50MB
    'jpg': {'category': 'image', 'max_size': 20 * 1024 * 1024},     # 20MB
    # ... etc
}
```

## Monitoring and Maintenance

### Storage Statistics

Get comprehensive statistics about attachment usage:

```http
GET /attachments/stats
```

Returns:
```json
{
    "total_attachments": 150,
    "total_size_bytes": 52428800,
    "total_size_human": "50.0 MB",
    "disk_usage_bytes": 52428800,
    "disk_usage_human": "50.0 MB",
    "by_category": {
        "document": {
            "count": 100,
            "total_size_bytes": 41943040,
            "total_size_human": "40.0 MB"
        },
        "image": {
            "count": 50,
            "total_size_bytes": 10485760,
            "total_size_human": "10.0 MB"
        }
    },
    "supported_types": ["pdf", "jpg", "png", ...]
}
```

### Cleanup Operations

The system includes utilities for maintenance:

```python
# Clean up empty directories
attachment_manager.cleanup_empty_directories()

# Get detailed statistics
stats = attachment_manager.get_attachment_stats(company_id=1)
```

## Security Considerations

1. **File Type Validation**: Files are validated by extension and MIME type
2. **Size Limits**: Different limits per file category to prevent abuse
3. **Dangerous Files**: Executable files are blocked for security
4. **Company Isolation**: Files are organized by company for access control
5. **Unique Naming**: Files use UUID-based naming to prevent conflicts and information disclosure

## Performance Considerations

1. **Local Storage**: All files stored locally for fast access
2. **Category Organization**: Files organized by type for efficient browsing
3. **Metadata Caching**: Database stores file metadata for quick queries
4. **Streaming Downloads**: Large files streamed to prevent memory issues

## Error Handling

The system provides detailed error messages for common issues:

- **File too large**: Specific size limits per file type
- **Unsupported type**: Clear message about supported formats
- **Security blocked**: Information about blocked file types
- **Storage errors**: Detailed error messages for troubleshooting

## Future Enhancements

Planned improvements for future versions:

1. **Image Thumbnails**: Automatic thumbnail generation for images
2. **Document Preview**: In-browser preview for common document types
3. **Virus Scanning**: Integration with antivirus scanning
4. **Cloud Storage**: Optional cloud storage backends (S3, Azure, etc.)
5. **Compression**: Automatic compression for large files
6. **Audit Trail**: Detailed logging of file access and modifications

## Troubleshooting

### Common Issues

#### Migration fails
```bash
# Check database connection
python migrate_attachments.py --action analyze

# Check file permissions
ls -la uploads/attachments/
```

#### Files not uploading
- Check file size limits
- Verify file type is supported
- Check disk space
- Review server logs for detailed errors

#### Legacy endpoints not working
- Ensure migration completed successfully
- Check that legacy endpoints are enabled
- Verify database has both old and new tables

#### Performance issues
- Monitor disk space usage
- Check for large numbers of files in single directories
- Consider cleanup of old/unused files

For additional support, check the server logs and attachment statistics for detailed information about the current state of the system.
