from fastapi import FastAPI, HTTPException, UploadFile, File, Query, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, StreamingResponse
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

# Import new attachment system
from attachment_manager import AttachmentManager
import attachment_endpoints

# Import VAT endpoints
from vat_endpoints import router as vat_router

app = FastAPI(title="PSC Accounting API", version="1.0.0")

# ================== GLOBAL VARIABLES ==================

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

# Configuration for file storage (legacy - now using AttachmentManager)
STORAGE_MODE = os.getenv("STORAGE_MODE", "local")  # "local" or "database"
UPLOAD_DIR = Path("uploads")
PDF_DIR = UPLOAD_DIR / "pdfs"  # Legacy PDF directory

# Ensure legacy upload directories exist for backward compatibility
PDF_DIR.mkdir(parents=True, exist_ok=True)

# Initialize attachment manager on startup
attachment_manager = None

# Initialize database connection on startup
@app.on_event("startup")
async def startup_event():
    global attachment_manager
    print("🚀 [Backend] Starting PSC Accounting API...")
    if initialize_db_pool():
        print("✅ [Backend] Database connection established")
    else:
        print("❌ [Backend] Failed to connect to database - API will not work properly")
    
    # Initialize new attachment system
    try:
        attachment_manager = AttachmentManager()
        print("✅ [Backend] Attachment system initialized")
    except Exception as e:
        print(f"⚠️ [Backend] Failed to initialize attachment system: {e}")
    
    print(f"📁 [Backend] Storage mode: {STORAGE_MODE} (legacy setting)")
    print(f"📁 [Backend] New attachment system active with local storage")

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
    expose_headers=["Content-Disposition"],  # Explicitly expose Content-Disposition header
)

# Include VAT endpoints
app.include_router(vat_router, tags=["VAT"])

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

# ================== LEGACY PDF STORAGE UTILITIES (DEPRECATED) ==================
# These functions have been replaced by the AttachmentManager class
# They are kept here temporarily for backward compatibility but will be removed
# Please use the AttachmentManager for all new file storage operations

# Note: All file storage operations now handled by AttachmentManager in attachment_manager.py
# - Supports all file types (not just PDFs)
# - Better organization with category-based storage
# - Enhanced security and validation
# - Comprehensive metadata management

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
               is_demo, created_at, status, vat_number, country, currency
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
                "created_at": row['created_at'].isoformat() if row['created_at'] else None,
                # Get actual values from database instead of hardcoded defaults
                "currency": row.get('currency', 'EUR'),
                "country": row.get('country', 'Ireland'),
                "vat_number": row.get('vat_number'),
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
    print(f"🏢 [Backend] Company details - VAT: {vat_number}, Country: {country}, Currency: {currency}")
    
    try:
        # Generate slug from company name
        slug = name.lower().replace(' ', '-').replace('&', 'and').replace('.', '').replace(',', '')
        slug = ''.join(c for c in slug if c.isalnum() or c == '-')  # Remove special characters
        
        print(f"🏢 [Backend] Generated slug: {slug}")
        
        # Create company in public.companies table with integer IDs (consistent with existing system)
        company_query = """
        INSERT INTO public.companies (name, slug, owner_email, status, subscription_plan, is_demo, created_at)
        VALUES (%s, %s, %s, 'active', 'free', false, NOW())
        RETURNING id, name, slug, owner_email, status, subscription_plan, is_demo, created_at
        """
        
        print(f"🏢 [Backend] Executing company creation query...")
        result = execute_query(company_query, (name, slug, owner_email), fetch=True)
        
        if not result:
            raise HTTPException(status_code=500, detail="Failed to create company")
        
        print(f"🏢 [Backend] Company creation result: {result}")
        
        # Convert single row result to dict
        row = dict(zip(['id', 'name', 'slug', 'owner_email', 'status', 'subscription_plan', 'is_demo', 'created_at'], result))
        
        print(f"🏢 [Backend] Company data row: {row}")
        
        # Return response with additional fields that frontend expects
        company = {
            "id": str(row['id']),  # Convert to string for JSON response, but it's an integer in DB
            "name": row['name'],
            "vat_number": vat_number,  # Include the VAT number from request
            "country": country,  # Include country from request
            "currency": currency,  # Include currency from request
            "slug": row.get('slug'),
            "owner_email": row['owner_email'], 
            "phone": None,  # Not supported in current schema
            "address": None,  # Not supported in current schema
            "subscription_plan": row.get('subscription_plan', 'free'),
            "is_demo": row.get('is_demo', False),
            "status": row.get('status', 'active'),
            "created_at": row['created_at'].isoformat() if row['created_at'] else None
        }
        
        print(f"✅ [Backend] Created company with integer ID: {row['id']} (returned as string: {company['id']})")
        return company
        
    except Exception as e:
        print(f"❌ [Backend] Error creating company: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create company: {str(e)}")

@app.put("/companies/{company_id}")
async def update_company(
    company_id: str,
    company_data: dict
):
    """Update an existing company"""
    
    print(f"🏢 [Backend] Updating company {company_id}")
    print(f"🏢 [Backend] Update data received: {company_data}")
    
    try:
        # First check if company exists
        check_query = """
        SELECT id, name, slug, owner_email, phone, address, subscription_plan, is_demo, created_at, status, vat_number, country, currency
        FROM public.companies 
        WHERE id = %s
        """
        existing_result = execute_query(check_query, (company_id,), fetch=True)
        
        if not existing_result or len(existing_result) == 0:
            print(f"❌ [Backend] Company {company_id} not found")
            raise HTTPException(status_code=404, detail=f"Company {company_id} not found")
        
        existing_company = dict(zip(['id', 'name', 'slug', 'owner_email', 'phone', 'address', 'subscription_plan', 'is_demo', 'created_at', 'status', 'vat_number', 'country', 'currency'], existing_result[0]))
        
        # Update the company in database
        update_query = """
        UPDATE public.companies 
        SET name = %s, slug = %s, owner_email = %s, phone = %s, address = %s, 
            subscription_plan = %s, is_demo = %s, status = %s, vat_number = %s, 
            country = %s, currency = %s, updated_at = CURRENT_TIMESTAMP
        WHERE id = %s
        RETURNING id, name, slug, owner_email, phone, address, subscription_plan, is_demo, created_at, status, vat_number, country, currency, updated_at
        """
        
        # Generate new slug if name changed
        name = company_data.get('name', existing_company['name'])
        slug = name.lower().replace(' ', '-').replace('&', 'and').replace('.', '').replace(',', '')
        slug = ''.join(c for c in slug if c.isalnum() or c == '-')
        
        updated_company = execute_query(
            update_query,
            (
                name,
                slug,
                company_data.get('owner_email', existing_company['owner_email']),
                company_data.get('phone', existing_company['phone']),
                company_data.get('address', existing_company['address']),
                company_data.get('subscription_plan', existing_company['subscription_plan']),
                company_data.get('is_demo', existing_company['is_demo']),
                company_data.get('status', existing_company['status']),
                company_data.get('vat_number', existing_company['vat_number']),
                company_data.get('country', existing_company['country']),
                company_data.get('currency', existing_company['currency']),
                company_id
            ),
            fetch=True
        )
        
        if updated_company:
            # For UPDATE with RETURNING, execute_query returns a tuple 
            # (id, name, slug, owner_email, phone, address, subscription_plan, is_demo, created_at, status, vat_number, country, currency, updated_at)
            result = {
                "id": str(updated_company[0]),
                "name": updated_company[1],
                "slug": updated_company[2],
                "owner_email": updated_company[3],
                "phone": updated_company[4],
                "address": updated_company[5],
                "subscription_plan": updated_company[6],
                "is_demo": updated_company[7],
                "created_at": updated_company[8].isoformat() if updated_company[8] else None,
                "status": updated_company[9],
                "vat_number": updated_company[10],  # Get from database result
                "country": updated_company[11],     # Get from database result
                "currency": updated_company[12],    # Get from database result
                "updated_at": updated_company[13].isoformat() if updated_company[13] else None
            }
            print(f"✅ [Backend] Company {company_id} updated successfully")
            return result
        else:
            print(f"❌ [Backend] Failed to update company {company_id}")
            raise HTTPException(status_code=500, detail="Failed to update company")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error updating company: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update company: {str(e)}")

# ================== USER ENDPOINTS ==================

@app.post("/users")
async def create_user(user_data: dict):
    """Create a new user"""
    try:
        print(f"🔤 [Backend] Creating user with data: {user_data}")
        
        # Validate required fields
        if not user_data.get('firebase_uid'):
            raise HTTPException(status_code=400, detail="firebase_uid is required")
        
        if not user_data.get('email'):
            raise HTTPException(status_code=400, detail="email is required")
        
        # Check if user already exists
        check_query = """
        SELECT id FROM public.users WHERE firebase_uid = %s OR email = %s
        """
        existing_user = execute_query(check_query, (user_data['firebase_uid'], user_data['email']), fetch=True)
        
        if existing_user:
            raise HTTPException(status_code=409, detail="User with this firebase_uid or email already exists")
        
        # Create user
        user_query = """
        INSERT INTO public.users (firebase_uid, email, created_at)
        VALUES (%s, %s, CURRENT_TIMESTAMP)
        RETURNING id, firebase_uid, email, created_at
        """
        
        result = execute_query(
            user_query, 
            (user_data['firebase_uid'], user_data['email']), 
            fetch=True
        )
        
        if result:
            user = {
                "id": str(result[0]),
                "firebase_uid": result[1],
                "email": result[2],
                "created_at": result[3].isoformat() if result[3] else None
            }
            
            print(f"✅ [Backend] User created successfully: {user}")
            return user
        else:
            raise HTTPException(status_code=500, detail="Failed to create user")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error creating user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")

@app.get("/users")
async def get_users():
    """Get all users"""
    try:
        print("📋 [Backend] Getting all users")
        
        query = """
        SELECT id, firebase_uid, email, created_at 
        FROM public.users 
        ORDER BY created_at DESC
        """
        
        result = execute_query(query, fetch=True)
        
        if result:
            users = []
            for row in result:
                user = {
                    "id": str(row[0]),
                    "firebase_uid": row[1],
                    "email": row[2],
                    "created_at": row[3].isoformat() if row[3] else None
                }
                users.append(user)
            
            print(f"✅ [Backend] Retrieved {len(users)} users")
            return users
        else:
            print("📋 [Backend] No users found")
            return []
        
    except Exception as e:
        print(f"❌ [Backend] Error getting users: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get users: {str(e)}")

@app.get("/users/{user_id}")
async def get_user(user_id: str):
    """Get a specific user by ID"""
    try:
        print(f"🔍 [Backend] Getting user with ID: {user_id}")
        
        query = """
        SELECT id, firebase_uid, email, created_at 
        FROM public.users 
        WHERE id = %s
        """
        
        result = execute_query(query, (int(user_id),), fetch=True)
        
        if result:
            user = {
                "id": str(result[0][0]),
                "firebase_uid": result[0][1],
                "email": result[0][2],
                "created_at": result[0][3].isoformat() if result[0][3] else None
            }
            
            print(f"✅ [Backend] User found: {user}")
            return user
        else:
            raise HTTPException(status_code=404, detail="User not found")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error getting user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user: {str(e)}")

@app.put("/users/{user_id}")
async def update_user(user_id: str, user_data: dict):
    """Update a user"""
    try:
        print(f"🔄 [Backend] Updating user {user_id} with data: {user_data}")
        
        # Check if user exists
        check_query = """
        SELECT id, firebase_uid, email, created_at 
        FROM public.users 
        WHERE id = %s
        """
        existing_result = execute_query(check_query, (int(user_id),), fetch=True)
        
        if not existing_result:
            raise HTTPException(status_code=404, detail="User not found")
        
        existing_user = {
            'id': existing_result[0][0],
            'firebase_uid': existing_result[0][1],
            'email': existing_result[0][2],
            'created_at': existing_result[0][3]
        }
        
        # Update user
        update_query = """
        UPDATE public.users 
        SET email = %s, firebase_uid = %s
        WHERE id = %s
        RETURNING id, firebase_uid, email, created_at
        """
        
        updated_user = execute_query(
            update_query,
            (
                user_data.get('email', existing_user['email']),
                user_data.get('firebase_uid', existing_user['firebase_uid']),
                int(user_id)
            ),
            fetch=True
        )
        
        if updated_user:
            result = {
                "id": str(updated_user[0][0]),
                "firebase_uid": updated_user[0][1],
                "email": updated_user[0][2],
                "created_at": updated_user[0][3].isoformat() if updated_user[0][3] else None
            }
            
            print(f"✅ [Backend] User updated successfully: {result}")
            return result
        else:
            raise HTTPException(status_code=500, detail="Failed to update user")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error updating user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update user: {str(e)}")

@app.delete("/users/{user_id}")
async def delete_user(user_id: str):
    """Delete a user"""
    try:
        print(f"🗑️ [Backend] Deleting user with ID: {user_id}")
        
        # Check if user exists
        check_query = """
        SELECT id FROM public.users WHERE id = %s
        """
        existing_user = execute_query(check_query, (int(user_id),), fetch=True)
        
        if not existing_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Delete user
        delete_query = """
        DELETE FROM public.users WHERE id = %s
        """
        
        execute_query(delete_query, (int(user_id),))
        
        print(f"✅ [Backend] User {user_id} deleted successfully")
        return {"message": f"User {user_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error deleting user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")

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
                "invoice_number": f"INV-{row['id']:04d}",  # Generate invoice number from ID for now
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

# ================== ATTACHMENT ENDPOINTS ==================

# Initialize attachment manager
attachment_manager = AttachmentManager()

@app.post("/attachments/upload")
async def upload_attachment(
    entity_type: str = Query(..., description="Type of entity (invoice, expense, payroll, bank_statement)"),
    entity_id: int = Query(..., description="ID of the entity"),
    company_id: int = Query(..., description="Company ID"),
    file: UploadFile = File(..., description="File to upload"),
    description: Optional[str] = Form(None, description="Optional description for the attachment")
):
    """Upload an attachment file for any entity type"""
    return await attachment_endpoints.upload_attachment(entity_type, entity_id, company_id, file, description)

@app.get("/attachments/download/{attachment_id}")
async def download_attachment(
    attachment_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Download an attachment file by ID"""
    return await attachment_endpoints.download_attachment(attachment_id, company_id)

@app.get("/attachments/{entity_type}/{entity_id}")
async def list_attachments(
    entity_type: str,
    entity_id: int,
    company_id: int = Query(..., description="Company ID")
):
    """List all attachments for a specific entity"""
    return await attachment_endpoints.list_attachments(entity_type, entity_id, company_id)

@app.delete("/attachments/{attachment_id}")
async def delete_attachment(
    attachment_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Delete an attachment file"""
    return await attachment_endpoints.delete_attachment(attachment_id, company_id)

@app.get("/attachments/info/{attachment_id}")
async def get_attachment_info(
    attachment_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Get attachment metadata without downloading the file"""
    return await attachment_endpoints.get_attachment_info(attachment_id, company_id)

@app.get("/attachments/stats")
async def get_attachment_stats(
    company_id: Optional[int] = Query(None, description="Company ID to filter stats")
):
    """Get attachment storage statistics"""
    return await attachment_endpoints.get_attachment_stats(company_id)

@app.put("/attachments/{attachment_id}/description")
async def update_attachment_description(
    attachment_id: int,
    description: str = Form(..., description="New description for the attachment"),
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Update the description of an attachment"""
    return await attachment_endpoints.update_attachment_description(attachment_id, description, company_id)

# Legacy PDF endpoints for backward compatibility (will be deprecated)
@app.post("/documents/upload")
async def upload_document_legacy(
    entity_type: str = Query(..., description="Type of entity (invoice, expense, payroll, bank_statement)"),
    entity_id: int = Query(..., description="ID of the entity"),
    company_id: int = Query(..., description="Company ID"),
    file: UploadFile = File(..., description="PDF file to upload")
):
    """Legacy PDF upload endpoint - redirects to new attachment system"""
    print("⚠️ [Backend] Legacy /documents/upload endpoint used - please migrate to /attachments/upload")
    return await attachment_endpoints.upload_attachment(entity_type, entity_id, company_id, file, "Uploaded via legacy endpoint")

@app.get("/documents/download/{document_id}")
async def download_document_legacy(
    document_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Legacy PDF download endpoint - redirects to new attachment system"""
    print("⚠️ [Backend] Legacy /documents/download endpoint used - please migrate to /attachments/download")
    return await attachment_endpoints.download_attachment(document_id, company_id)

@app.get("/documents/{entity_type}/{entity_id}")
async def get_documents_legacy(entity_type: str, entity_id: int, company_id: int = Query(...)):
    """Legacy document list endpoint - redirects to new attachment system"""
    print("⚠️ [Backend] Legacy /documents endpoint used - please migrate to /attachments")
    return await attachment_endpoints.list_attachments(entity_type, entity_id, company_id)

@app.delete("/documents/{document_id}")
async def delete_document_legacy(
    document_id: int,
    company_id: Optional[int] = Query(None, description="Company ID for security check")
):
    """Legacy document delete endpoint - redirects to new attachment system"""
    print("⚠️ [Backend] Legacy /documents delete endpoint used - please migrate to /attachments")
    return await attachment_endpoints.delete_attachment(document_id, company_id)

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
    """Get list of employees for a company (from database employees + payroll data)"""
    
    print(f"👥 [Backend] Getting employees for company: {company_id}")
    
    try:
        employees = []
        
        # Get employees from dedicated employees table
        employees_query = """
        SELECT id, company_id, name, email, phone_number, position, department, 
               base_salary, hire_date, is_active, created_at, updated_at
        FROM public.employees 
        WHERE company_id = %s
        ORDER BY name
        """
        
        employees_result = execute_query(employees_query, (company_id,), fetch=True)
        
        # Add employees from employees table
        for row in employees_result or []:
            employee = {
                "id": str(row['id']),
                "name": row['name'],
                "company_id": company_id,
                "email": row['email'],
                "phone_number": row['phone_number'],
                "position": row['position'],
                "department": row['department'],
                "base_salary": float(row['base_salary']) if row['base_salary'] else None,
                "hire_date": row['hire_date'].isoformat() if row['hire_date'] else None,
                "is_active": row['is_active'],
                "created_at": row['created_at'].isoformat() if row['created_at'] else None,
                "source": "database"
            }
            employees.append(employee)
        
        # Get employees from payroll entries (for backward compatibility)
        payroll_query = """
        SELECT DISTINCT employee_name
        FROM public.payroll 
        WHERE company_id = %s::VARCHAR AND employee_name IS NOT NULL
        ORDER BY employee_name
        """
        
        payroll_result = execute_query(payroll_query, (company_id,), fetch=True)
        
        # Add employees from payroll (only if not already in employees table)
        existing_names = {emp['name'].lower() for emp in employees}
        for i, row in enumerate(payroll_result or [], 1):
            employee_name = row['employee_name']
            if employee_name.lower() not in existing_names:
                employee = {
                    "id": f"payroll_{i}",  # Generate simple ID for payroll employees
                    "name": employee_name,
                    "company_id": company_id,
                    "email": None,
                    "phone_number": None,
                    "position": None,
                    "department": None,
                    "base_salary": None,
                    "hire_date": None,
                    "is_active": True,
                    "created_at": None,
                    "source": "payroll"
                }
                employees.append(employee)
        
        print(f"👥 [Backend] Returning {len(employees)} employees (database: {len(employees_result or [])}, payroll: {len(payroll_result or [])})")
        return employees
        
    except Exception as e:
        print(f"❌ [Backend] Error getting employees: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get employees: {str(e)}")

@app.post("/employees", status_code=201)
async def create_employee(
    employee_data: dict,
    company_id: str = Query(..., description="Company ID")
):
    """Create a new employee in database"""
    
    print(f"👥 [Backend] Creating employee for company: {company_id}")
    print(f"👥 [Backend] Employee data received: {employee_data}")
    
    try:
        # Extract employee data from request body
        name = employee_data.get('name')
        email = employee_data.get('email')
        phone_number = employee_data.get('phone_number')
        position = employee_data.get('position')
        department = employee_data.get('department')
        base_salary = employee_data.get('base_salary')
        hire_date = employee_data.get('hire_date')
        is_active = employee_data.get('is_active', True)
        
        if not name:
            raise HTTPException(status_code=400, detail="Employee name is required")
        
        # First ensure the employees table exists
        create_table_query = """
        CREATE TABLE IF NOT EXISTS public.employees (
            id SERIAL PRIMARY KEY,
            company_id VARCHAR(36) NOT NULL,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255),
            phone_number VARCHAR(20),
            position VARCHAR(100),
            department VARCHAR(100),
            base_salary NUMERIC(10,2),
            hire_date DATE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        execute_query(create_table_query, (), fetch=False)
        
        # Insert employee into database
        insert_query = """
        INSERT INTO public.employees (
            company_id, name, email, phone_number, position, department, 
            base_salary, hire_date, is_active
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id, created_at
        """
        
        result = execute_query(insert_query, (
            company_id, name, email, phone_number, position, department,
            base_salary, hire_date, is_active
        ), fetch=True)
        
        if result:
            # For INSERT with RETURNING, execute_query returns a tuple (id, created_at)
            employee_id = result[0]
            created_at = result[1]
            
            print(f"✅ [Backend] Employee created with ID: {employee_id}")
            
            # Return employee data in expected format
            employee = {
                "id": str(employee_id),
                "company_id": company_id,
                "name": name,
                "email": email,
                "phone_number": phone_number,
                "position": position,
                "department": department,
                "base_salary": float(base_salary) if base_salary else None,
                "hire_date": hire_date,
                "is_active": is_active,
                "created_at": created_at.isoformat() if created_at else None,
                "source": "database"
            }
            
            return employee
        else:
            raise HTTPException(status_code=500, detail="Failed to create employee")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error creating employee: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create employee: {str(e)}")

@app.put("/employees/{employee_id}")
async def update_employee(
    employee_id: str,
    employee_data: dict,
    company_id: str = Query(..., description="Company ID")
):
    """Update an existing employee"""
    
    print(f"👥 [Backend] Updating employee {employee_id} for company: {company_id}")
    print(f"👥 [Backend] Update data received: {employee_data}")
    
    try:
        # Check if this is a payroll-derived employee (starts with 'payroll_')
        if employee_id.startswith('payroll_'):
            print(f"👥 [Backend] Employee {employee_id} is from payroll - payroll employees are read-only")
            raise HTTPException(
                status_code=400, 
                detail="Payroll-derived employees cannot be updated. Create a new employee record instead."
            )
        
        # First check if employee exists in database
        check_query = """
        SELECT id, name, email, phone_number, position, department, base_salary, hire_date, is_active 
        FROM employees 
        WHERE id = %s AND company_id = %s
        """
        existing_result = execute_query(check_query, (employee_id, company_id), fetch=True)
        
        if not existing_result or len(existing_result) == 0:
            print(f"❌ [Backend] Employee {employee_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        
        existing_employee = existing_result[0]  # Get the first (and only) row
        
        # Update the employee in database
        update_query = """
        UPDATE employees 
        SET name = %s, email = %s, phone_number = %s, position = %s, 
            department = %s, base_salary = %s, hire_date = %s, is_active = %s, 
            updated_at = CURRENT_TIMESTAMP
        WHERE id = %s AND company_id = %s
        RETURNING id, name, email, phone_number, position, department, base_salary, hire_date, is_active
        """
        
        updated_employee = execute_query(
            update_query,
            (
                employee_data.get('name', existing_employee['name']),
                employee_data.get('email', existing_employee['email']),
                employee_data.get('phone_number', existing_employee['phone_number']),
                employee_data.get('position', existing_employee['position']),
                employee_data.get('department', existing_employee['department']),
                employee_data.get('base_salary', existing_employee['base_salary']),
                employee_data.get('hire_date', existing_employee['hire_date']),
                employee_data.get('is_active', existing_employee['is_active']),
                employee_id,
                company_id
            ),
            fetch=True
        )
        
        if updated_employee:
            # For UPDATE with RETURNING, execute_query returns a tuple 
            result = {
                "id": str(updated_employee[0]),
                "name": updated_employee[1],
                "email": updated_employee[2],
                "phone_number": updated_employee[3],
                "position": updated_employee[4],
                "department": updated_employee[5],
                "base_salary": float(updated_employee[6]) if updated_employee[6] else None,
                "hire_date": str(updated_employee[7]) if updated_employee[7] else None,
                "is_active": updated_employee[8],
                "source": "database"
            }
            print(f"✅ [Backend] Employee {employee_id} updated successfully")
            return result
        else:
            print(f"❌ [Backend] Failed to update employee {employee_id}")
            raise HTTPException(status_code=500, detail="Failed to update employee")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error updating employee: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update employee: {str(e)}")

@app.delete("/employees/{employee_id}")
async def delete_employee(
    employee_id: str,
    company_id: str = Query(..., description="Company ID")
):
    """Delete an employee from database"""
    
    print(f"👥 [Backend] Deleting employee {employee_id} for company: {company_id}")
    
    try:
        # Check if this is a payroll-derived employee (starts with 'payroll_')
        if employee_id.startswith('payroll_'):
            print(f"👥 [Backend] Employee {employee_id} is from payroll - payroll employees cannot be deleted")
            raise HTTPException(
                status_code=400, 
                detail="Payroll-derived employees cannot be deleted. They are read-only records."
            )
        
        # First check if employee exists in database
        check_query = """
        SELECT id FROM employees 
        WHERE id = %s AND company_id = %s
        """
        existing_employee = execute_query(check_query, (employee_id, company_id), fetch=True)
        
        if not existing_employee or len(existing_employee) == 0:
            print(f"❌ [Backend] Employee {employee_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        
        # Delete the employee from database
        delete_query = """
        DELETE FROM employees 
        WHERE id = %s AND company_id = %s
        """
        
        result = execute_query(delete_query, (employee_id, company_id), fetch=False)
        
        if result > 0:
            print(f"✅ [Backend] Employee {employee_id} deleted successfully")
            return {"message": f"Employee {employee_id} deleted successfully"}
        else:
            print(f"❌ [Backend] Failed to delete employee {employee_id}")
            raise HTTPException(status_code=500, detail="Failed to delete employee")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error deleting employee: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete employee: {str(e)}")

# ================== DASHBOARD ENDPOINT ==================

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
        
        # Handle the result properly - it's a tuple when using RETURNING
        invoice_id = result[0] if result and len(result) > 0 else None
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
        
        # Handle the result properly - it's a tuple when using RETURNING
        expense_id = result[0] if result and len(result) > 0 else None
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
        
        # Handle the result properly - it's a tuple when using RETURNING
        payroll_id = result[0] if result and len(result) > 0 else None
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
        
        # Handle the result properly - it's a tuple when using RETURNING
        statement_id = result[0] if result and len(result) > 0 else None
            
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
