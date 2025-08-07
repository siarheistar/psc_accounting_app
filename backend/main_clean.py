from fastapi import FastAPI, HTTPException, UploadFile, File, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os
import shutil
import uuid
from datetime import datetime
import base64
import json
from pathlib import Path

# Import your existing database module
from database import initialize_db_pool, close_db_pool, execute_query

app = FastAPI(title="PSC Accounting API", version="1.0.0")

# Configuration for file storage
STORAGE_MODE = os.getenv("STORAGE_MODE", "local")  # "local" or "database"
UPLOAD_DIR = Path("uploads")
PDF_DIR = UPLOAD_DIR / "pdfs"

# Ensure upload directories exist
PDF_DIR.mkdir(parents=True, exist_ok=True)

# Initialize database connection on startup
@app.on_event("startup")
async def startup_event():
    print("🚀 [Backend] Starting PSC Accounting API...")
    if initialize_db_pool():
        print("✅ [Backend] Database connection established")
    else:
        print("❌ [Backend] Failed to connect to database - API will not work properly")
    
    print(f"📁 [Backend] Storage mode: {STORAGE_MODE}")
    if STORAGE_MODE == "local":
        print(f"📁 [Backend] Local storage directory: {PDF_DIR.absolute()}")

@app.on_event("shutdown")
async def shutdown_event():
    print("🛑 [Backend] Shutting down PSC Accounting API...")
    close_db_pool()

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================== MODELS ==================

class DocumentMetadata(BaseModel):
    id: Optional[int] = None
    entity_type: str  # 'invoice', 'expense', 'payroll', 'bank_statement'
    entity_id: int
    company_id: int
    filename: str
    original_filename: str
    file_size: int
    mime_type: str = "application/pdf"
    storage_type: str = "local"  # "local" or "database"
    file_path: Optional[str] = None  # For local storage
    created_at: Optional[datetime] = None

class Company(BaseModel):
    id: Optional[int] = None
    name: str
    email: str = ""
    phone: Optional[str] = None
    address: Optional[str] = None
    subscription_plan: str = "free"
    owner_email: str
    is_demo: bool = False

class Invoice(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None
    invoice_number: Optional[str] = None
    client_name: str
    amount: float
    date: Optional[str] = None
    due_date: Optional[str] = None
    status: str = "pending"
    description: Optional[str] = None
    created_at: Optional[str] = None

class Expense(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None
    description: str
    amount: float
    date: str
    category: str
    status: str = "pending"
    notes: Optional[str] = None

class PayrollEntry(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None
    period: str
    employee_name: str
    gross_pay: float
    deductions: float
    net_pay: float
    pay_date: Optional[str] = None
    employee_id: Optional[str] = None

class Employee(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None
    name: str
    email: Optional[str] = None
    phone_number: Optional[str] = None
    position: Optional[str] = None
    department: Optional[str] = None
    base_salary: Optional[float] = None
    hire_date: Optional[str] = None
    is_active: bool = True
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class BankStatement(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None
    transaction_date: str
    description: str
    amount: float
    balance: float

# ================== PDF STORAGE UTILITIES ==================

def generate_unique_filename(original_filename: str) -> str:
    """Generate a unique filename for storage"""
    file_ext = Path(original_filename).suffix
    unique_id = str(uuid.uuid4())
    return f"{unique_id}{file_ext}"

def save_pdf_locally(file_content: bytes, entity_type: str, entity_id: int, company_id: int, original_filename: str) -> tuple[str, str]:
    """Save PDF file to local storage and return file path and unique filename"""
    
    # Create company-specific directory
    company_dir = PDF_DIR / f"company_{company_id}" / entity_type
    company_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate unique filename
    unique_filename = generate_unique_filename(original_filename)
    file_path = company_dir / unique_filename
    
    # Save file
    with open(file_path, 'wb') as f:
        f.write(file_content)
    
    # Return relative path for database storage
    relative_path = str(file_path.relative_to(PDF_DIR))
    
    print(f"📁 [Local Storage] Saved file: {relative_path}")
    return relative_path, unique_filename

def save_pdf_to_database(file_content: bytes, entity_type: str, entity_id: int, company_id: int, original_filename: str) -> int:
    """Save PDF file to database and return document ID"""
    
    # Encode file content as base64 for database storage
    encoded_content = base64.b64encode(file_content).decode('utf-8')
    
    query = """
        INSERT INTO document_attachments 
        (entity_type, entity_id, company_id, filename, original_filename, file_data, file_size, mime_type, storage_type, created_at) 
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """
    
    params = (
        entity_type,
        entity_id,
        company_id,
        original_filename,
        original_filename,
        encoded_content,
        len(file_content),
        "application/pdf",
        "database",
        datetime.now()
    )
    
    result = execute_query(query, params, fetch=True)
    document_id = result[0] if isinstance(result, tuple) else result['id']
    
    print(f"💾 [Database Storage] Saved file with ID: {document_id}")
    return document_id

def save_pdf_metadata_to_db(entity_type: str, entity_id: int, company_id: int, 
                           original_filename: str, unique_filename: str, file_size: int, 
                           storage_type: str, file_path: Optional[str] = None) -> int:
    """Save PDF metadata to database"""
    
    query = """
        INSERT INTO document_attachments 
        (entity_type, entity_id, company_id, filename, original_filename, file_size, mime_type, storage_type, file_path, created_at) 
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """
    
    params = (
        entity_type,
        entity_id,
        company_id,
        unique_filename,
        original_filename,
        file_size,
        "application/pdf",
        storage_type,
        file_path,
        datetime.now()
    )
    
    result = execute_query(query, params, fetch=True)
    document_id = result[0] if isinstance(result, tuple) else result['id']
    
    return document_id

# ================== BASIC ENDPOINTS ==================

@app.get("/")
async def root():
    return {"message": "PSC Accounting API is running", "storage_mode": STORAGE_MODE}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "storage_mode": STORAGE_MODE}

# ================== PDF DOCUMENT ENDPOINTS ==================

@app.post("/documents/upload")
async def upload_document(
    entity_type: str = Query(..., description="Type of entity (invoice, expense, payroll, bank_statement)"),
    entity_id: int = Query(..., description="ID of the entity"),
    company_id: int = Query(..., description="Company ID"),
    file: UploadFile = File(..., description="PDF file to upload")
):
    """Upload a PDF document with configurable storage backend"""
    
    print(f"📎 [Backend] Upload request:")
    print(f"   Entity: {entity_type} #{entity_id}")
    print(f"   Company: {company_id}")
    print(f"   File: {file.filename} ({file.content_type})")
    print(f"   Storage: {STORAGE_MODE}")
    
    # Validate file type
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")
    
    if file.content_type and file.content_type != "application/pdf":
        print(f"⚠️ Warning: Content-Type is {file.content_type}, but accepting as PDF")
    
    try:
        # Read file content
        file_content = await file.read()
        file_size = len(file_content)
        
        print(f"📊 File size: {file_size:,} bytes")
        
        # Validate PDF header
        if not file_content.startswith(b'%PDF'):
            raise HTTPException(status_code=400, detail="Invalid PDF file (missing PDF header)")
        
        document_id = None
        
        if STORAGE_MODE == "local":
            # Save to local storage
            file_path, unique_filename = save_pdf_locally(
                file_content, entity_type, entity_id, company_id, file.filename
            )
            
            # Save metadata to database
            document_id = save_pdf_metadata_to_db(
                entity_type, entity_id, company_id, file.filename, 
                unique_filename, file_size, "local", file_path
            )
            
        elif STORAGE_MODE == "database":
            # Save to database
            document_id = save_pdf_to_database(
                file_content, entity_type, entity_id, company_id, file.filename
            )
        
        else:
            raise HTTPException(status_code=500, detail=f"Invalid storage mode: {STORAGE_MODE}")
        
        print(f"✅ [Backend] Document uploaded successfully with ID: {document_id}")
        
        return {
            "id": document_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "company_id": company_id,
            "filename": file.filename,
            "file_size": file_size,
            "storage_type": STORAGE_MODE,
            "message": f"File uploaded successfully using {STORAGE_MODE} storage"
        }
        
    except Exception as e:
        print(f"❌ [Backend] Upload error: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@app.get("/documents/download/{document_id}")
async def download_document(document_id: int):
    """Download a PDF document from either local storage or database"""
    
    print(f"📥 [Backend] Download request for document ID: {document_id}")
    
    try:
        # Get document metadata from database
        query = """
            SELECT id, filename, original_filename, file_size, mime_type, storage_type, file_path, file_data
            FROM document_attachments 
            WHERE id = %s
        """
        
        result = execute_query(query, (document_id,), fetch=True)
        
        if not result:
            raise HTTPException(status_code=404, detail="Document not found")
        
        # Handle both tuple and dict results
        if isinstance(result, tuple):
            doc = {
                'id': result[0], 'filename': result[1], 'original_filename': result[2],
                'file_size': result[3], 'mime_type': result[4], 'storage_type': result[5],
                'file_path': result[6], 'file_data': result[7]
            }
        else:
            doc = result
        
        storage_type = doc['storage_type']
        original_filename = doc['original_filename']
        
        print(f"📄 Found document: {original_filename} (storage: {storage_type})")
        
        if storage_type == "local":
            # Serve from local storage
            file_path = PDF_DIR / doc['file_path']
            
            if not file_path.exists():
                raise HTTPException(status_code=404, detail="File not found on disk")
            
            print(f"📁 [Local Storage] Serving file: {file_path}")
            return FileResponse(
                path=str(file_path),
                filename=original_filename,
                media_type="application/pdf"
            )
        
        elif storage_type == "database":
            # Decode from database
            file_data = doc['file_data']
            
            if isinstance(file_data, str):
                # Base64 encoded string
                file_content = base64.b64decode(file_data)
            elif isinstance(file_data, bytes):
                # Raw bytes
                file_content = file_data
            else:
                raise HTTPException(status_code=500, detail="Invalid file data format")
            
            # Validate PDF
            if not file_content.startswith(b'%PDF'):
                print("⚠️ Warning: File doesn't appear to be a valid PDF")
            
            print(f"💾 [Database Storage] Serving file: {len(file_content):,} bytes")
            
            # Return file content as response
            return Response(
                content=file_content,
                media_type="application/pdf",
                headers={"Content-Disposition": f"attachment; filename={original_filename}"}
            )
        
        else:
            raise HTTPException(status_code=500, detail=f"Unknown storage type: {storage_type}")
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Download error: {e}")
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")

@app.get("/documents/{entity_type}/{entity_id}")
async def get_documents(entity_type: str, entity_id: int, company_id: int = Query(...)):
    """Get all documents for a specific entity"""
    
    print(f"📋 [Backend] Fetching documents for {entity_type} #{entity_id} (company {company_id})")
    
    try:
        query = """
            SELECT id, filename, original_filename, file_size, mime_type, storage_type, created_at
            FROM document_attachments 
            WHERE entity_type = %s AND entity_id = %s AND company_id = %s
            ORDER BY created_at DESC
        """
        
        results = execute_query(query, (entity_type, entity_id, company_id), fetch=True)
        
        documents = []
        for row in results if isinstance(results, list) else [results] if results else []:
            if isinstance(row, tuple):
                doc = {
                    'id': row[0], 'filename': row[1], 'original_filename': row[2],
                    'file_size': row[3], 'mime_type': row[4], 'storage_type': row[5],
                    'created_at': row[6]
                }
            else:
                doc = row
            
            documents.append(doc)
        
        print(f"📄 Found {len(documents)} documents")
        return documents
    
    except Exception as e:
        print(f"❌ [Backend] Error fetching documents: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch documents: {str(e)}")

@app.delete("/documents/{document_id}")
async def delete_document(document_id: int):
    """Delete a document from both storage and database"""
    
    print(f"🗑️ [Backend] Delete request for document ID: {document_id}")
    
    try:
        # Get document info first
        query = "SELECT storage_type, file_path FROM document_attachments WHERE id = %s"
        result = execute_query(query, (document_id,), fetch=True)
        
        if not result:
            raise HTTPException(status_code=404, detail="Document not found")
        
        storage_type = result[0] if isinstance(result, tuple) else result['storage_type']
        file_path = result[1] if isinstance(result, tuple) else result['file_path']
        
        # Delete from storage
        if storage_type == "local" and file_path:
            local_file_path = PDF_DIR / file_path
            if local_file_path.exists():
                local_file_path.unlink()
                print(f"📁 [Local Storage] Deleted file: {file_path}")
            else:
                print(f"⚠️ [Local Storage] File not found: {file_path}")
        
        # Delete from database
        delete_query = "DELETE FROM document_attachments WHERE id = %s"
        execute_query(delete_query, (document_id,), fetch=False)
        
        print(f"✅ [Backend] Document {document_id} deleted successfully")
        return {"message": f"Document {document_id} deleted successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete error: {e}")
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

# ================== STORAGE CONFIGURATION ==================

@app.get("/storage/config")
async def get_storage_config():
    """Get current storage configuration"""
    return {
        "storage_mode": STORAGE_MODE,
        "upload_directory": str(PDF_DIR.absolute()) if STORAGE_MODE == "local" else None,
        "supported_modes": ["local", "database"]
    }

@app.post("/storage/config")
async def set_storage_config(mode: str = Query(..., regex="^(local|database)$")):
    """Set storage mode (requires restart)"""
    global STORAGE_MODE
    STORAGE_MODE = mode
    print(f"📁 [Backend] Storage mode changed to: {STORAGE_MODE}")
    return {
        "message": f"Storage mode set to {STORAGE_MODE}",
        "note": "Restart required for full effect"
    }

# ================== YOUR EXISTING ENDPOINTS ==================
# Add all your existing company, invoice, expense, payroll endpoints here...
# I'm keeping this clean file focused on the PDF storage implementation

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
