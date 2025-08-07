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

# ================== PYDANTIC MODELS ==================

class Company(BaseModel):
    id: str
    name: str
    vat_number: Optional[str] = None
    country: str = "Ireland"
    currency: str = "EUR"
    created_at: str
    is_demo: bool = False

class User(BaseModel):
    id: str
    firebase_uid: str
    email: Optional[str] = None
    created_at: str

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

# ================== COMPANY ENDPOINTS ==================

@app.get("/companies")
async def get_companies(owner_email: str = Query(..., description="Email of the company owner")):
    """Get all companies for a specific user by email from public schema"""
    
    print(f"🏢 [Backend] Getting companies for email: {owner_email}")
    
    try:
        # Get companies directly from public.companies table
        companies_query = """
        SELECT id, name, slug, owner_email, phone, address, subscription_plan, 
               is_demo, created_at, status
        FROM public.companies 
        WHERE owner_email = %s AND status = 'active'
        ORDER BY created_at DESC
        """
        
        companies_result = execute_query(companies_query, (owner_email,), fetch=True)
        
        # Convert to response format
        companies = []
        for row in companies_result or []:
            company = {
                "id": str(row['id']),
                "name": row['name'],
                "slug": row.get('slug'),
                "owner_email": row['owner_email'],
                "phone": row.get('phone'),
                "address": row.get('address'),
                "subscription_plan": row.get('subscription_plan', 'free'),
                "is_demo": row.get('is_demo', False),
                "status": row.get('status', 'active'),
                "created_at": row['created_at'].isoformat() if row['created_at'] else None
            }
            companies.append(company)
        
        print(f"📊 [Backend] Returning {len(companies)} companies")
        return companies
        
    except Exception as e:
        print(f"❌ [Backend] Error getting companies: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get companies: {str(e)}")

@app.post("/companies")
async def create_company(
    name: str = Query(..., description="Company name"),
    vat_number: Optional[str] = Query(None, description="VAT number"),
    country: str = Query("Ireland", description="Country"),
    currency: str = Query("EUR", description="Currency"),
    owner_email: str = Query(..., description="Owner email")
):
    """Create a new company"""
    
    print(f"🏢 [Backend] Creating company: {name} for {owner_email}")
    
    try:
        # Get or create user
        get_user_query = "SELECT id FROM prod.users WHERE email = %s"
        user_result = execute_query(get_user_query, (owner_email,), fetch=True)
        
        user_id = None
        if not user_result:
            # Create new user
            create_user_query = """
            INSERT INTO prod.users (firebase_uid, email) 
            VALUES (%s, %s) 
            RETURNING id
            """
            user_result = execute_query(create_user_query, (owner_email, owner_email), fetch=True)
            if user_result:
                user_id = dict(zip(['id'], user_result))['id']
        else:
            user_id = user_result[0]['id']
            
        if not user_id:
            raise HTTPException(status_code=400, detail="Failed to create/find user")
        
        # Create company
        company_query = """
        INSERT INTO prod.companies (user_id, name, vat_number, country, currency)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, user_id, name, vat_number, country, currency, created_at
        """
        
        result = execute_query(company_query, (user_id, name, vat_number, country, currency), fetch=True)
        
        if not result:
            raise HTTPException(status_code=500, detail="Failed to create company")
        
        # Convert single row result to dict
        row = dict(zip(['id', 'user_id', 'name', 'vat_number', 'country', 'currency', 'created_at'], result))
        company = {
            "id": str(row['id']),
            "name": row['name'],
            "vat_number": row.get('vat_number'),
            "country": row.get('country', 'Ireland'),
            "currency": row.get('currency', 'EUR'),
            "created_at": row['created_at'].isoformat() if row['created_at'] else None,
            "is_demo": False
        }
        
        print(f"✅ [Backend] Created company: {company['id']}")
        return company
        
    except Exception as e:
        print(f"❌ [Backend] Error creating company: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create company: {str(e)}")

# ================== DATA ENDPOINTS ==================

@app.get("/invoices")
async def get_invoices(company_id: str = Query(..., description="Company ID")):
    """Get all invoices for a company from public schema"""
    
    print(f"📄 [Backend] Getting invoices for company: {company_id}")
    
    try:
        query = """
        SELECT id, company_id, client_name, amount, date, due_date, status, created_at
        FROM public.invoices 
        WHERE company_id = %s
        ORDER BY created_at DESC
        """
        
        result = execute_query(query, (int(company_id),), fetch=True)
        
        invoices = []
        for row in result or []:
            invoice = {
                "id": str(row['id']),
                "company_id": str(row['company_id']),
                "invoice_number": f"INV-{row['id']:04d}",  # Generate invoice number from ID
                "client_name": row['client_name'],  # Use actual column name
                "amount": float(row['amount']) if row['amount'] else 0.0,
                "date": row['date'].isoformat() if row['date'] else None,
                "due_date": row['due_date'].isoformat() if row['due_date'] else None,
                "status": row['status'] or 'pending',
                "created_at": row['created_at'].isoformat() if row['created_at'] else None
            }
            invoices.append(invoice)
        
        print(f"📊 [Backend] Returning {len(invoices)} invoices")
        return invoices
        
    except Exception as e:
        print(f"❌ [Backend] Error getting invoices: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get invoices: {str(e)}")

@app.get("/expenses")
async def get_expenses(company_id: str = Query(..., description="Company ID")):
    """Get all expenses for a company from public schema"""
    
    print(f"💰 [Backend] Getting expenses for company: {company_id}")
    
    try:
        query = """
        SELECT id, company_id, description, amount, date, category, created_at
        FROM public.expenses 
        WHERE company_id = %s
        ORDER BY created_at DESC
        """
        
        result = execute_query(query, (int(company_id),), fetch=True)
        
        expenses = []
        for row in result or []:
            expense = {
                "id": str(row['id']),
                "company_id": str(row['company_id']),
                "date": row['date'].isoformat() if row['date'] else None,
                "description": row['description'],
                "category": row['category'],
                "amount": float(row['amount']) if row['amount'] else 0.0,
                "created_at": row['created_at'].isoformat() if row['created_at'] else None
            }
            expenses.append(expense)
        
        print(f"📊 [Backend] Returning {len(expenses)} expenses")
        return expenses
        
    except Exception as e:
        print(f"❌ [Backend] Error getting expenses: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get expenses: {str(e)}")

@app.get("/payroll")
async def get_payroll_entries(company_id: str = Query(..., description="Company ID")):
    """Get all payroll entries for a company from public schema"""
    
    print(f"👥 [Backend] Getting payroll entries for company: {company_id}")
    
    try:
        query = """
        SELECT id, company_id, period, employee_name, gross_pay, deductions, net_pay, pay_date, created_at
        FROM public.payroll 
        WHERE company_id = %s::VARCHAR
        ORDER BY created_at DESC
        """
        
        result = execute_query(query, (company_id,), fetch=True)
        
        payroll_entries = []
        for row in result or []:
            entry = {
                "id": str(row['id']),
                "company_id": str(row['company_id']),
                "period": row['period'],
                "employee_name": row['employee_name'],
                "gross_pay": float(row['gross_pay']) if row['gross_pay'] else 0.0,
                "deductions": float(row['deductions']) if row['deductions'] else 0.0,
                "net_pay": float(row['net_pay']) if row['net_pay'] else 0.0,
                "pay_date": row['pay_date'].isoformat() if row['pay_date'] else None,
                "created_at": row['created_at'].isoformat() if row['created_at'] else None
            }
            payroll_entries.append(entry)
        
        print(f"📊 [Backend] Returning {len(payroll_entries)} payroll entries")
        return payroll_entries
        
    except Exception as e:
        print(f"❌ [Backend] Error getting payroll entries: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get payroll entries: {str(e)}")

@app.get("/bank-statements")
async def get_bank_statements(company_id: str = Query(..., description="Company ID")):
    """Get all bank statements for a company from public schema"""
    
    print(f"🏦 [Backend] Getting bank statements for company: {company_id}")
    
    try:
        query = """
        SELECT id, company_id, transaction_date, description, amount, balance, created_at
        FROM public.bank_statements 
        WHERE company_id = %s
        ORDER BY transaction_date DESC
        """
        
        result = execute_query(query, (int(company_id),), fetch=True)
        
        statements = []
        for row in result or []:
            statement = {
                "id": str(row['id']),
                "company_id": str(row['company_id']),
                "transaction_date": row['transaction_date'].isoformat() if row['transaction_date'] else None,
                "description": row['description'],
                "amount": float(row['amount']) if row['amount'] else 0.0,
                "balance": float(row['balance']) if row['balance'] else 0.0,
                "created_at": row['created_at'].isoformat() if row['created_at'] else None
            }
            statements.append(statement)
        
        print(f"📊 [Backend] Returning {len(statements)} bank statements")
        return statements
        
    except Exception as e:
        print(f"❌ [Backend] Error getting bank statements: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get bank statements: {str(e)}")

@app.get("/dashboard/metrics")
async def get_dashboard_metrics(company_id: str = Query(..., description="Company ID")):
    """Get dashboard metrics for a company from public schema"""
    
    print(f"📈 [Backend] Getting dashboard metrics for company: {company_id}")
    
    try:
        # Get invoice metrics
        invoice_query = """
        SELECT 
            COUNT(*) as total_invoices,
            COUNT(CASE WHEN status != 'paid' THEN 1 END) as pending_invoices,
            COALESCE(SUM(amount), 0) as total_invoice_amount,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) as paid_amount
        FROM public.invoices 
        WHERE company_id = %s
        """
        
        invoice_result = execute_query(invoice_query, (int(company_id),), fetch=True)
        
        # Get expense metrics
        expense_query = """
        SELECT 
            COUNT(*) as total_expenses,
            COALESCE(SUM(amount), 0) as total_expense_amount
        FROM public.expenses 
        WHERE company_id = %s
        """
        
        expense_result = execute_query(expense_query, (int(company_id),), fetch=True)
        
        # Calculate metrics
        invoice_data = invoice_result[0] if invoice_result else {}
        expense_data = expense_result[0] if expense_result else {}
        
        total_income = float(invoice_data.get('total_invoice_amount', 0))
        total_expenses = float(expense_data.get('total_expense_amount', 0))
        net_profit = total_income - total_expenses
        
        metrics = {
            "invoices": {
                "total_invoices": invoice_data.get('total_invoices', 0),
                "pending_invoices": invoice_data.get('pending_invoices', 0),
                "total_invoice_amount": total_income,
                "paid_amount": float(invoice_data.get('paid_amount', 0))
            },
            "expenses": {
                "total_expenses": expense_data.get('total_expenses', 0),
                "total_expense_amount": total_expenses
            },
            "net_profit": net_profit
        }
        
        print(f"📊 [Backend] Returning dashboard metrics: {metrics}")
        return metrics
        
    except Exception as e:
        print(f"❌ [Backend] Error getting dashboard metrics: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get dashboard metrics: {str(e)}")

@app.get("/dashboard/{company_id}")
async def get_dashboard_by_path(company_id: str):
    """Get dashboard metrics by path parameter - redirect to metrics endpoint"""
    return await get_dashboard_metrics(company_id)

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

# ================== MISSING CRUD ENDPOINTS ==================

@app.get("/expense-categories")
async def get_expense_categories():
    """Get list of available expense categories"""
    
    print("💰 [Backend] Getting expense categories")
    
    try:
        # Return standard expense categories
        categories = [
            'Office',
            'Technology', 
            'Meals',
            'Travel',
            'Marketing',
            'Utilities',
            'Professional Services',
            'Supplies',
            'Insurance',
            'Rent',
            'Training',
            'Other'
        ]
        
        print(f"💰 [Backend] Returning {len(categories)} expense categories")
        return categories
        
    except Exception as e:
        print(f"❌ [Backend] Error getting expense categories: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get expense categories: {str(e)}")

@app.get("/employees")
async def get_employees(company_id: str = Query(..., description="Company ID")):
    """Get list of employees for a company (extracted from payroll data)"""
    
    print(f"👥 [Backend] Getting employees for company: {company_id}")
    
    try:
        # Extract unique employee names from payroll entries
        query = """
        SELECT DISTINCT employee_name
        FROM public.payroll 
        WHERE company_id = %s::VARCHAR AND employee_name IS NOT NULL
        ORDER BY employee_name
        """
        
        result = execute_query(query, (company_id,), fetch=True)
        
        employees = []
        for i, row in enumerate(result or [], 1):
            employee = {
                "id": str(i),  # Generate simple ID
                "name": row['employee_name'],
                "company_id": company_id
            }
            employees.append(employee)
        
        print(f"👥 [Backend] Returning {len(employees)} employees")
        return employees
        
    except Exception as e:
        print(f"❌ [Backend] Error getting employees: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get employees: {str(e)}")

@app.get("/expense-categories")
async def get_expense_categories():
    """Get list of available expense categories"""
    
    print(f"💰 [Backend] Getting expense categories")
    
    categories = [
        'Office Supplies',
        'Technology',
        'Meals & Entertainment',
        'Travel',
        'Marketing',
        'Utilities',
        'Professional Services',
        'Insurance',
        'Rent',
        'Equipment',
        'Software',
        'Training',
        'Maintenance',
        'Other'
    ]
    
    print(f"💰 [Backend] Returning {len(categories)} expense categories")
    return categories

@app.get("/expense-categories")
async def get_expense_categories():
    """Get list of expense categories"""
    
    print(f"💰 [Backend] Getting expense categories")
    
    try:
        # Return standard expense categories
        categories = [
            "Office Supplies",
            "Travel",
            "Meals & Entertainment",
            "Marketing",
            "Software & Subscriptions",
            "Equipment",
            "Professional Services",
            "Utilities",
            "Rent",
            "Insurance",
            "Training",
            "Other"
        ]
        
        print(f"📊 [Backend] Returning {len(categories)} expense categories")
        return categories
        
    except Exception as e:
        print(f"❌ [Backend] Error getting expense categories: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get expense categories: {str(e)}")

# ================== CREATE (POST) ENDPOINTS ==================

@app.post("/invoices")
async def create_invoice(invoice_data: dict, company_id: str = Query(..., description="Company ID")):
    """Create a new invoice"""
    
    print(f"📄 [Backend] Creating new invoice for company {company_id}")
    print(f"📄 [Backend] Invoice data: {invoice_data}")
    
    try:
        # Insert new invoice
        insert_query = """
        INSERT INTO public.invoices 
        (company_id, client_name, amount, date, due_date, status, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
        RETURNING id
        """
        
        result = execute_query(insert_query, (
            int(company_id),
            invoice_data.get('client_name'),
            float(invoice_data.get('amount', 0)),
            invoice_data.get('date'),
            invoice_data.get('due_date'),
            invoice_data.get('status', 'pending')
        ), fetch=True)
        
        invoice_id = result[0]['id'] if result else None
        print(f"✅ [Backend] Invoice created with ID: {invoice_id}")
        return {"id": invoice_id, "message": "Invoice created successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Create invoice error: {e}")
        raise HTTPException(status_code=500, detail=f"Create failed: {str(e)}")

@app.post("/expenses")
async def create_expense(expense_data: dict, company_id: str = Query(..., description="Company ID")):
    """Create a new expense"""
    
    print(f"💰 [Backend] Creating new expense for company {company_id}")
    print(f"💰 [Backend] Expense data: {expense_data}")
    
    try:
        # Insert new expense
        insert_query = """
        INSERT INTO public.expenses 
        (company_id, description, category, amount, date, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
        RETURNING id
        """
        
        result = execute_query(insert_query, (
            int(company_id),
            expense_data.get('description'),
            expense_data.get('category'),
            float(expense_data.get('amount', 0)),
            expense_data.get('date')
        ), fetch=True)
        
        expense_id = result[0]['id'] if result else None
        print(f"✅ [Backend] Expense created with ID: {expense_id}")
        return {"id": expense_id, "message": "Expense created successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Create expense error: {e}")
        raise HTTPException(status_code=500, detail=f"Create failed: {str(e)}")

@app.post("/payroll")
async def create_payroll(payroll_data: dict, company_id: str = Query(..., description="Company ID")):
    """Create a new payroll entry"""
    
    print(f"👥 [Backend] Creating new payroll entry for company {company_id}")
    print(f"👥 [Backend] Payroll data: {payroll_data}")
    
    try:
        # Insert new payroll entry
        insert_query = """
        INSERT INTO public.payroll 
        (company_id, employee_name, period, gross_pay, deductions, net_pay, pay_date, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        RETURNING id
        """
        
        result = execute_query(insert_query, (
            int(company_id),
            payroll_data.get('employee_name'),
            payroll_data.get('period'),
            float(payroll_data.get('gross_pay', 0)),
            float(payroll_data.get('deductions', 0)),
            float(payroll_data.get('net_pay', 0)),
            payroll_data.get('pay_date')
        ), fetch=True)
        
        payroll_id = result[0]['id'] if result else None
        print(f"✅ [Backend] Payroll entry created with ID: {payroll_id}")
        return {"id": payroll_id, "message": "Payroll entry created successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Create payroll error: {e}")
        raise HTTPException(status_code=500, detail=f"Create failed: {str(e)}")

@app.post("/bank-statements")
async def create_bank_statement(statement_data: dict, company_id: str = Query(..., description="Company ID")):
    """Create a new bank statement"""
    
    print(f"🏦 [Backend] Creating new bank statement for company {company_id}")
    print(f"🏦 [Backend] Statement data: {statement_data}")
    
    try:
        # Insert new bank statement with proper field mapping
        insert_query = """
        INSERT INTO public.bank_statements 
        (company_id, transaction_date, description, amount, balance, created_at)
        VALUES (%s, %s, %s, %s, %s, NOW())
        RETURNING id
        """
        
        # Calculate balance (this is a simple approach - in production you'd track running balance)
        # For now, we'll set balance to amount for deposits, negative for withdrawals
        transaction_type = statement_data.get('transaction_type', 'deposit')
        amount = float(statement_data.get('amount', 0))
        
        # Simple balance calculation - in real app you'd calculate from previous transactions
        if transaction_type.lower() == 'withdrawal':
            balance = -amount  # Negative balance for withdrawals
        else:
            balance = amount   # Positive balance for deposits
        
        result = execute_query(insert_query, (
            int(company_id),
            statement_data.get('transaction_date'),
            statement_data.get('description'),
            amount,
            balance
        ), fetch=True)
        
        # Handle the result properly (it's a dict when returning ID)
        if result:
            if isinstance(result, list) and len(result) > 0:
                statement_id = result[0]['id']
            elif isinstance(result, dict):
                statement_id = result['id']
            else:
                statement_id = result
        else:
            statement_id = None
            
        print(f"✅ [Backend] Bank statement created with ID: {statement_id}")
        return {"id": statement_id, "message": "Bank statement created successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Create bank statement error: {e}")
        raise HTTPException(status_code=500, detail=f"Create failed: {str(e)}")

# ================== DELETE ENDPOINTS ==================

@app.delete("/invoices/{invoice_id}")
async def delete_invoice(invoice_id: int, company_id: str = Query(..., description="Company ID")):
    """Delete an invoice"""
    
    print(f"🗑️ [Backend] Deleting invoice {invoice_id} for company {company_id}")
    
    try:
        # Check if invoice exists and belongs to company
        check_query = "SELECT id FROM public.invoices WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (invoice_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Invoice {invoice_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        # Delete the invoice
        delete_query = "DELETE FROM public.invoices WHERE id = %s AND company_id = %s"
        execute_query(delete_query, (invoice_id, int(company_id)), fetch=False)
        
        print(f"✅ [Backend] Invoice {invoice_id} deleted successfully")
        return {"message": f"Invoice {invoice_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete invoice error: {e}")
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

@app.delete("/expenses/{expense_id}")
async def delete_expense(expense_id: int, company_id: str = Query(..., description="Company ID")):
    """Delete an expense"""
    
    print(f"🗑️ [Backend] Deleting expense {expense_id} for company {company_id}")
    
    try:
        # Check if expense exists and belongs to company
        check_query = "SELECT id FROM public.expenses WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (expense_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Expense {expense_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Expense not found")
        
        # Delete the expense
        delete_query = "DELETE FROM public.expenses WHERE id = %s AND company_id = %s"
        execute_query(delete_query, (expense_id, int(company_id)), fetch=False)
        
        print(f"✅ [Backend] Expense {expense_id} deleted successfully")
        return {"message": f"Expense {expense_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete expense error: {e}")
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

@app.delete("/payroll/{payroll_id}")
async def delete_payroll(payroll_id: int, company_id: str = Query(..., description="Company ID")):
    """Delete a payroll entry"""
    
    print(f"🗑️ [Backend] Deleting payroll {payroll_id} for company {company_id}")
    
    try:
        # Check if payroll exists and belongs to company
        check_query = "SELECT id FROM public.payroll WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (payroll_id, company_id), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Payroll {payroll_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Payroll entry not found")
        
        # Delete the payroll entry
        delete_query = "DELETE FROM public.payroll WHERE id = %s AND company_id = %s"
        execute_query(delete_query, (payroll_id, company_id), fetch=False)
        
        print(f"✅ [Backend] Payroll {payroll_id} deleted successfully")
        return {"message": f"Payroll {payroll_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete payroll error: {e}")
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

# ================== UPDATE (PUT) ENDPOINTS ==================

@app.put("/invoices/{invoice_id}")
async def update_invoice(invoice_id: int, invoice_data: dict, company_id: str = Query(..., description="Company ID")):
    """Update an invoice"""
    
    print(f"📄 [Backend] Updating invoice {invoice_id} for company {company_id}")
    print(f"📄 [Backend] Update data: {invoice_data}")
    
    try:
        # Check if invoice exists and belongs to company
        check_query = "SELECT id FROM public.invoices WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (invoice_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Invoice {invoice_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        # Update the invoice
        update_query = """
        UPDATE public.invoices 
        SET client_name = %s, amount = %s, date = %s, due_date = %s, status = %s, updated_at = CURRENT_TIMESTAMP
        WHERE id = %s AND company_id = %s
        """
        
        execute_query(update_query, (
            invoice_data.get('client_name'),
            float(invoice_data.get('amount', 0)),
            invoice_data.get('date'),
            invoice_data.get('due_date'),
            invoice_data.get('status', 'pending'),
            invoice_id,
            int(company_id)
        ), fetch=False)
        
        print(f"✅ [Backend] Invoice {invoice_id} updated successfully")
        return {"message": f"Invoice {invoice_id} updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Update invoice error: {e}")
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")

@app.put("/expenses/{expense_id}")
async def update_expense(expense_id: int, expense_data: dict, company_id: str = Query(..., description="Company ID")):
    """Update an expense"""
    
    print(f"💰 [Backend] Updating expense {expense_id} for company {company_id}")
    print(f"💰 [Backend] Update data: {expense_data}")
    
    try:
        # Check if expense exists and belongs to company
        check_query = "SELECT id FROM public.expenses WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (expense_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Expense {expense_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Expense not found")
        
        # Update the expense
        update_query = """
        UPDATE public.expenses 
        SET description = %s, category = %s, amount = %s, date = %s, updated_at = CURRENT_TIMESTAMP
        WHERE id = %s AND company_id = %s
        """
        
        execute_query(update_query, (
            expense_data.get('description'),
            expense_data.get('category'),
            float(expense_data.get('amount', 0)),
            expense_data.get('date'),
            expense_id,
            int(company_id)
        ), fetch=False)
        
        print(f"✅ [Backend] Expense {expense_id} updated successfully")
        return {"message": f"Expense {expense_id} updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Update expense error: {e}")
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")

@app.put("/payroll/{payroll_id}")
async def update_payroll(payroll_id: int, payroll_data: dict, company_id: str = Query(..., description="Company ID")):
    """Update a payroll entry"""
    
    print(f"👥 [Backend] Updating payroll {payroll_id} for company {company_id}")
    print(f"👥 [Backend] Update data: {payroll_data}")
    
    try:
        # Check if payroll exists and belongs to company
        check_query = "SELECT id FROM public.payroll WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (payroll_id, company_id), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Payroll {payroll_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Payroll entry not found")
        
        # Update the payroll entry with explicit type casting
        update_query = """
        UPDATE public.payroll 
        SET employee_name = %s, period = %s, gross_pay = %s::numeric, deductions = %s::numeric, 
            net_pay = %s::numeric, pay_date = %s::date, updated_at = NOW()
        WHERE id = %s AND company_id = %s
        """
        
        execute_query(update_query, (
            str(payroll_data.get('employee_name')),
            str(payroll_data.get('period')),
            float(payroll_data.get('gross_pay', 0)),
            float(payroll_data.get('deductions', 0)),
            float(payroll_data.get('net_pay', 0)),
            payroll_data.get('pay_date'),
            payroll_id,
            company_id
        ), fetch=False)
        
        print(f"✅ [Backend] Payroll {payroll_id} updated successfully")
        return {"message": f"Payroll {payroll_id} updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Update payroll error: {e}")
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")

@app.put("/bank-statements/{statement_id}")
async def update_bank_statement(statement_id: int, statement_data: dict, company_id: str = Query(..., description="Company ID")):
    """Update a bank statement"""
    
    print(f"🏦 [Backend] Updating bank statement {statement_id} for company {company_id}")
    print(f"🏦 [Backend] Update data: {statement_data}")
    
    try:
        # Check if bank statement exists and belongs to company
        check_query = "SELECT id FROM public.bank_statements WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (statement_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Bank statement {statement_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Bank statement not found")
        
        # Update the bank statement
        update_query = """
        UPDATE public.bank_statements 
        SET transaction_date = %s, description = %s, amount = %s, balance = %s
        WHERE id = %s AND company_id = %s
        """
        
        execute_query(update_query, (
            statement_data.get('transaction_date'),
            statement_data.get('description'),
            float(statement_data.get('amount', 0)),
            float(statement_data.get('balance', 0)),
            statement_id,
            int(company_id)
        ), fetch=False)
        
        print(f"✅ [Backend] Bank statement {statement_id} updated successfully")
        return {"message": f"Bank statement {statement_id} updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Update bank statement error: {e}")
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")

@app.delete("/bank-statements/{statement_id}")
async def delete_bank_statement(statement_id: int, company_id: str = Query(..., description="Company ID")):
    """Delete a bank statement"""
    
    print(f"🗑️ [Backend] Deleting bank statement {statement_id} for company {company_id}")
    
    try:
        # Check if bank statement exists and belongs to company
        check_query = "SELECT id FROM public.bank_statements WHERE id = %s AND company_id = %s"
        result = execute_query(check_query, (statement_id, int(company_id)), fetch=True)
        
        if not result:
            print(f"❌ [Backend] Bank statement {statement_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Bank statement not found")
        
        # Delete the bank statement
        delete_query = "DELETE FROM public.bank_statements WHERE id = %s AND company_id = %s"
        execute_query(delete_query, (statement_id, int(company_id)), fetch=False)
        
        print(f"✅ [Backend] Bank statement {statement_id} deleted successfully")
        return {"message": f"Bank statement {statement_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Delete bank statement error: {e}")
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
