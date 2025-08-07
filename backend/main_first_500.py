from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
from database import initialize_db_pool, close_db_pool, execute_query
from datetime import datetime
import base64
import pickle
import json
import psycopg2
import psycopg2.extras
import traceback

app = FastAPI(title="PSC Accounting API", version="1.0.0")

# Initialize database connection on startup
@app.on_event("startup")
async def startup_event():
    print("🚀 [Backend] Starting PSC Accounting API...")
    if initialize_db_pool():
        print("✅ [Backend] Database connection established")
    else:
        print("❌ [Backend] Failed to connect to database - API will not work properly")

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

# Pydantic models
class Company(BaseModel):
    id: Optional[int] = None
    name: str
    email: str = ""  # Not stored in DB but required by Flutter model
    phone: Optional[str] = None
    address: Optional[str] = None
    subscription_plan: str = "free"
    owner_email: str
    is_demo: bool = False

class Invoice(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None  # Made optional since it comes from query params
    invoice_number: Optional[str] = None
    client_name: str
    amount: float
    date: Optional[str] = None  # For compatibility
    due_date: Optional[str] = None  # Flutter sends due_date
    status: str = "pending"
    description: Optional[str] = None
    created_at: Optional[str] = None

class Expense(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None  # Made optional since it comes from query params
    description: str
    amount: float
    date: str
    category: str

class BankStatement(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None  # Made optional since it comes from query params
    transaction_date: str
    description: str
    amount: float
    balance: float

class PayrollEntry(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None  # Made optional since it comes from query params
    period: str
    employee_name: str
    gross_pay: float
    deductions: float
    net_pay: float
    pay_date: Optional[str] = None
    employee_id: Optional[str] = None

class Employee(BaseModel):
    id: Optional[int] = None
    company_id: Optional[str] = None  # Made optional since it comes from query params
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

# Payslip functionality removed - not required by user

@app.get("/")
async def root():
    return {"message": "PSC Accounting API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# Dashboard endpoint
@app.get("/dashboard/{company_id}")
async def get_dashboard_data(company_id: str):
    """Get dashboard calculations from real database data"""
    print(f"📊 [Backend] Fetching dashboard data for company_id: {company_id}")
    
    try:
        # Get invoice statistics
        invoice_query = """
            SELECT 
                COUNT(*) as total_invoices,
                COALESCE(SUM(amount), 0) as total_invoice_amount,
                COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_invoices,
                COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid_invoices
            FROM invoices 
            WHERE company_id = %s
        """
        invoice_stats = execute_query(invoice_query, (company_id,), fetch=True)
        
        # Get expense statistics  
        expense_query = """
            SELECT 
                COUNT(*) as total_expenses,
                COALESCE(SUM(amount), 0) as total_expense_amount
            FROM expenses 
            WHERE company_id = %s
        """
        print(f"🔍 [Backend] Running expense query with company_id: {company_id}")
        expense_stats = execute_query(expense_query, (company_id,), fetch=True)
        print(f"🔍 [Backend] Expense stats result: {expense_stats}")
        
        # Get bank statement statistics
        bank_query = """
            SELECT 
                COUNT(*) as total_transactions,
                COALESCE(
                    (SELECT balance FROM bank_statements 
                     WHERE company_id = %s 
                     ORDER BY transaction_date DESC, created_at DESC 
                     LIMIT 1), 0
                ) as current_balance
            FROM bank_statements 
            WHERE company_id = %s
        """
        bank_stats = execute_query(bank_query, (company_id, company_id), fetch=True)
        
        # Get payroll statistics
        payroll_query = """
            SELECT 
                COUNT(*) as total_payroll_entries,
                COALESCE(SUM(gross_pay), 0) as total_gross_pay,
                COALESCE(SUM(deductions), 0) as total_deductions,
                COALESCE(SUM(net_pay), 0) as total_net_pay
            FROM payroll 
            WHERE company_id = %s
        """
        payroll_stats = execute_query(payroll_query, (company_id,), fetch=True)
        
        # Format results - execute_query returns list of dictionaries
        if invoice_stats and len(invoice_stats) > 0:
            stats = invoice_stats[0]  # Get first row
            invoice_data = {
                "total_invoices": stats["total_invoices"],
                "total_invoice_amount": float(stats["total_invoice_amount"]),
                "pending_invoices": stats["pending_invoices"],
                "paid_invoices": stats["paid_invoices"]
            }
        else:
            invoice_data = {"total_invoices": 0, "total_invoice_amount": 0.0, "pending_invoices": 0, "paid_invoices": 0}
            
        if expense_stats and len(expense_stats) > 0:
            stats = expense_stats[0]  # Get first row
            expense_data = {
                "total_expenses": stats["total_expenses"],
                "total_expense_amount": float(stats["total_expense_amount"])
            }
        else:
            expense_data = {"total_expenses": 0, "total_expense_amount": 0.0}
            
        if bank_stats and len(bank_stats) > 0:
            stats = bank_stats[0]  # Get first row
            bank_data = {
                "total_transactions": stats["total_transactions"],
                "current_balance": float(stats["current_balance"])
            }
        else:
            bank_data = {"total_transactions": 0, "current_balance": 0.0}
            
        if payroll_stats and len(payroll_stats) > 0:
            stats = payroll_stats[0]  # Get first row
            payroll_data = {
                "total_payroll_entries": stats["total_payroll_entries"],
                "total_gross_pay": float(stats["total_gross_pay"]),
                "total_deductions": float(stats["total_deductions"]),
                "total_net_pay": float(stats["total_net_pay"])
            }
        else:
            payroll_data = {"total_payroll_entries": 0, "total_gross_pay": 0.0, "total_deductions": 0.0, "total_net_pay": 0.0}
        
        dashboard_data = {
            "company_id": company_id,
            "invoices": invoice_data,
            "expenses": expense_data,
            "bank_statements": bank_data,
            "payroll": payroll_data,
            "net_profit": invoice_data["total_invoice_amount"] - expense_data["total_expense_amount"]
        }
        
        print(f"📊 [Backend] Dashboard data calculated from database:")
        print(f"   📄 Invoices: {invoice_data['total_invoices']} total, ${invoice_data['total_invoice_amount']:.2f} value")
        print(f"   💰 Expenses: {expense_data['total_expenses']} total, ${expense_data['total_expense_amount']:.2f} value")
        print(f"   🏦 Bank: {bank_data['total_transactions']} transactions, ${bank_data['current_balance']:.2f} balance")
        print(f"   �‍💼 Payroll: {payroll_data['total_payroll_entries']} entries, ${payroll_data['total_net_pay']:.2f} total pay")
        print(f"   �💵 Net Profit: ${dashboard_data['net_profit']:.2f}")
        
        return dashboard_data
        
    except Exception as e:
        print(f"❌ [Backend] Database error fetching dashboard data: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Company endpoints
@app.get("/companies")
async def get_companies(owner_email: Optional[str] = None):
    """Get companies owned by a user"""
    print(f"🏢 [Backend] Fetching companies for owner_email: {owner_email}")
    
    try:
        if owner_email:
            query = "SELECT * FROM companies WHERE owner_email = %s ORDER BY created_at DESC"
            companies = execute_query(query, (owner_email,), fetch=True)
            print(f"🔍 [Backend] Found {len(companies)} companies for {owner_email} in AWS database")
        else:
            query = "SELECT * FROM companies ORDER BY created_at DESC"
            companies = execute_query(query, fetch=True)
            print(f"📋 [Backend] Returning all {len(companies)} companies from AWS database")
        
        return companies
    except Exception as e:
        print(f"❌ [Backend] Database error fetching companies: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/companies")
async def create_company(company: Company):
    """Create a new company"""
    print(f"🏢 [Backend] Creating company with data: {company.dict()}")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.companies' table")
        
        # Generate slug from name (replace spaces with hyphens, lowercase)
        slug = company.name.lower().replace(' ', '-').replace('_', '-')
        
        # Insert into database - using actual database schema
        query = """
            INSERT INTO companies (name, slug, owner_email, phone, address, subscription_plan, is_demo, status, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """
        
        params = (
            company.name,
            slug,
            company.owner_email,
            company.phone or '',
            company.address or '',
            'free',  # default subscription plan
            company.is_demo,
            'active',  # default status
            datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            # For INSERT with RETURNING, we get a tuple with all columns
            if isinstance(result, tuple):
                # The tuple contains all columns in order: (id, name, slug, owner_email, phone, address, subscription_plan, is_demo, created_at, status)
                company_id = result[0]
                print(f"✅ [Backend] Company successfully created in database with ID: {company_id}")
                print(f"🗂️ [Database] Table: pscdb.companies | Operation: INSERT | Row ID: {company_id}")
                
                return {
                    "id": result[0],  # id
                    "name": result[1],  # name
                    "slug": result[2],  # slug
                    "owner_email": result[3],  # owner_email
                    "phone": result[4] or '',  # phone
                    "address": result[5] or '',  # address
                    "subscription_plan": result[6],  # subscription_plan
                    "is_demo": result[7],  # is_demo
                    "created_at": result[8],  # created_at
                    "status": result[9],  # status
                    "email": ""  # Not stored in DB but required by Flutter model
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise Exception("Failed to create company - no result returned")
            
    except Exception as e:
        print(f"❌ [Backend] Database error creating company: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/companies/{company_id}")
async def get_company(company_id: str):
    """Get a specific company by ID"""
    print(f"🏢 [Backend] Fetching company with ID: {company_id}")
    
    try:
        query = "SELECT * FROM companies WHERE id = %s"
        result = execute_query(query, (company_id,), fetch=True)
        
        if result and len(result) > 0:
            company = result[0]
            print(f"✅ [Backend] Found company: {company[1]}")  # name is at index 1
            return {
                "id": company[0],
                "name": company[1],
                "slug": company[2],
                "owner_email": company[3],
                "phone": company[4] or '',
                "address": company[5] or '',
                "subscription_plan": company[6],
                "is_demo": company[7],
                "created_at": company[8],
                "status": company[9],
                "email": ""  # Not stored in DB but required by Flutter model
            }
        else:
            print(f"❌ [Backend] Company not found with ID: {company_id}")
            raise HTTPException(status_code=404, detail="Company not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error fetching company: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Invoice endpoints
@app.get("/invoices", response_model=List[Invoice])
async def get_invoices(company_id: Optional[str] = None):
    """Get invoices from database"""
    print(f"📄 [Backend] Fetching invoices for company_id: {company_id}")
    
    try:
        if company_id:
            query = "SELECT * FROM invoices WHERE company_id = %s ORDER BY created_at DESC"
            result = execute_query(query, (company_id,), fetch=True)
            print(f"🔍 [Backend] Found {len(result)} invoices for company {company_id}")
        else:
            query = "SELECT * FROM invoices ORDER BY created_at DESC"
            result = execute_query(query, fetch=True)
            print(f"📋 [Backend] Returning all {len(result)} invoices from database")
        
        invoices = []
        for row in result:
            # Row is a dictionary from execute_query SELECT
            invoices.append({
                "id": row["id"],
                "company_id": str(row["company_id"]),
                "client_name": row["client_name"],
                "amount": float(row["amount"]),
                "date": str(row["date"]),
                "due_date": str(row["due_date"]),
                "status": row["status"]
            })
        
        print(f"✅ [Backend] Returning {len(invoices)} formatted invoices")
        return invoices
    except Exception as e:
        print(f"❌ [Backend] Database error fetching invoices: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/invoices", response_model=Invoice)
async def create_invoice(invoice: Invoice, company_id: str = None):
    """Create a new invoice in database"""
    print(f"📄 [Backend] Creating invoice with data: {invoice.dict()}")
    print(f"📄 [Backend] Company ID from query: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id query parameter is required")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.invoices' table")
        
        # Use due_date if provided, otherwise fall back to date
        invoice_date = invoice.date or datetime.now().strftime('%Y-%m-%d')
        invoice_due_date = invoice.due_date or invoice.date or datetime.now().strftime('%Y-%m-%d')
        
        query = """
            INSERT INTO invoices (company_id, client_name, amount, date, due_date, status, created_at, updated_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """
        
        params = (
            int(company_id),
            invoice.client_name,
            invoice.amount,
            invoice_date,
            invoice_due_date,
            invoice.status,
            datetime.now(),
            datetime.now()
        )
        
        print(f"🔍 [Debug] Executing query with params: {params}")
        
        result = execute_query(query, params, fetch=True)
        
        print(f"🔍 [Debug] Query result: {result}, type: {type(result)}")
        
        if result:
            # For INSERT with RETURNING, we get a tuple with all columns
            if isinstance(result, tuple):
                invoice_id = result[0]
                print(f"✅ [Backend] Invoice successfully created in database with ID: {invoice_id}")
                print(f"🗂️ [Database] Table: pscdb.invoices | Operation: INSERT | Row ID: {invoice_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "client_name": result[2],
                    "amount": float(result[3]),
                    "date": str(result[4]),
                    "due_date": str(result[5]),
                    "status": result[6]
                }
            else:
                print(f"❌ [Debug] Unexpected result format: {type(result)}, value: {result}")
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            print(f"❌ [Debug] No result returned from database")
            raise Exception("Failed to create invoice - no result returned")
            
    except Exception as e:
        print(f"❌ [Backend] Database error creating invoice: {e}")
        print(f"❌ [Debug] Exception type: {type(e)}")
        print(f"❌ [Debug] Exception args: {e.args}")
        print(f"❌ [Debug] Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.put("/invoices/{invoice_id}", response_model=Invoice)
async def update_invoice(invoice_id: int, invoice: Invoice):
    """Update an existing invoice in database"""
    print(f"📄 [Backend] Updating invoice {invoice_id} with data: {invoice.dict()}")
    
    try:
        print(f"💾 [Backend] Updating in AWS PostgreSQL database 'pscdb.invoices' table")
        
        query = """
            UPDATE invoices 
            SET company_id = %s, client_name = %s, amount = %s, date = %s, due_date = %s, status = %s, updated_at = %s
            WHERE id = %s
            RETURNING *
        """
        
        params = (
            int(invoice.company_id),
            invoice.client_name,
            invoice.amount,
            invoice.date,
            invoice.due_date,
            invoice.status,
            datetime.now(),
            invoice_id
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            if isinstance(result, tuple):
                print(f"✅ [Backend] Invoice {invoice_id} successfully updated in database")
                print(f"🗂️ [Database] Table: pscdb.invoices | Operation: UPDATE | Row ID: {invoice_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "client_name": result[2],
                    "amount": float(result[3]),
                    "date": str(result[4]),
                    "due_date": str(result[5]),
                    "status": result[6]
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
