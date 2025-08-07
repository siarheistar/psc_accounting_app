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
        else:
            raise HTTPException(status_code=404, detail="Invoice not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error updating invoice: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.delete("/invoices/{invoice_id}")
async def delete_invoice(invoice_id: int, company_id: Optional[str] = None):
    """Delete an invoice from database"""
    print(f"🗑️ [Backend] Deleting invoice {invoice_id} for company_id: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id is required")
    
    try:
        # First check if invoice exists
        check_query = "SELECT id FROM invoices WHERE id = %s AND company_id = %s"
        existing = execute_query(check_query, (invoice_id, company_id), fetch=True)
        
        if not existing:
            print(f"❌ [Backend] Invoice {invoice_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        # Delete the invoice
        delete_query = "DELETE FROM invoices WHERE id = %s AND company_id = %s"
        result = execute_query(delete_query, (invoice_id, company_id), fetch=False)
        
        print(f"✅ [Backend] Invoice {invoice_id} deleted successfully")
        print(f"🗂️ [Database] Table: pscdb.invoices | Operation: DELETE | Row ID: {invoice_id}")
        
        return {"message": f"Invoice {invoice_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error deleting invoice: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Expense endpoints
@app.get("/expenses", response_model=List[Expense])
async def get_expenses(company_id: Optional[str] = None):
    """Get expenses from database"""
    print(f"💰 [Backend] Fetching expenses for company_id: {company_id}")
    
    try:
        if company_id:
            query = "SELECT * FROM expenses WHERE company_id = %s ORDER BY created_at DESC"
            result = execute_query(query, (company_id,), fetch=True)
            print(f"🔍 [Backend] Found {len(result)} expenses for company {company_id}")
        else:
            query = "SELECT * FROM expenses ORDER BY created_at DESC"
            result = execute_query(query, fetch=True)
            print(f"📋 [Backend] Returning all {len(result)} expenses from database")
        
        expenses = []
        for row in result:
            expenses.append({
                "id": row["id"],
                "company_id": str(row["company_id"]),
                "description": row["description"],
                "amount": float(row["amount"]),
                "date": str(row["date"]),
                "category": row["category"] or ""
            })
        
        return expenses
    except Exception as e:
        print(f"❌ [Backend] Database error fetching expenses: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/expenses", response_model=Expense)
async def create_expense(expense: Expense, company_id: str = None):
    """Create a new expense in database"""
    print(f"💰 [Backend] Creating expense with data: {expense.dict()}")
    print(f"💰 [Backend] Company ID from query: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id query parameter is required")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.expenses' table")
        
        query = """
            INSERT INTO expenses (company_id, description, amount, date, category, created_at, updated_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """
        
        params = (
            int(company_id),
            expense.description,
            expense.amount,
            expense.date,
            expense.category,
            datetime.now(),
            datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            # For INSERT with RETURNING, we get a tuple with all columns
            if isinstance(result, tuple):
                expense_id = result[0]
                print(f"✅ [Backend] Expense successfully created in database with ID: {expense_id}")
                print(f"🗂️ [Database] Table: pscdb.expenses | Operation: INSERT | Row ID: {expense_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "description": result[2],
                    "amount": float(result[3]),
                    "date": str(result[4]),
                    "category": result[5] or ""
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise Exception("Failed to create expense - no result returned")
            
    except Exception as e:
        print(f"❌ [Backend] Database error creating expense: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.put("/expenses/{expense_id}", response_model=Expense)
async def update_expense(expense_id: int, expense: Expense):
    """Update an existing expense in database"""
    print(f"💰 [Backend] Updating expense {expense_id} with data: {expense.dict()}")
    
    try:
        print(f"💾 [Backend] Updating in AWS PostgreSQL database 'pscdb.expenses' table")
        
        query = """
            UPDATE expenses 
            SET company_id = %s, description = %s, amount = %s, date = %s, category = %s, updated_at = %s
            WHERE id = %s
            RETURNING *
        """
        
        params = (
            int(expense.company_id),
            expense.description,
            expense.amount,
            expense.date,
            expense.category,
            datetime.now(),
            expense_id
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            if isinstance(result, tuple):
                print(f"✅ [Backend] Expense {expense_id} successfully updated in database")
                print(f"🗂️ [Database] Table: pscdb.expenses | Operation: UPDATE | Row ID: {expense_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "description": result[2],
                    "amount": float(result[3]),
                    "date": str(result[4]),
                    "category": result[5] or ""
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise HTTPException(status_code=404, detail="Expense not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error updating expense: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.delete("/expenses/{expense_id}")
async def delete_expense(expense_id: int, company_id: Optional[str] = None):
    """Delete an expense from database"""
    print(f"🗑️ [Backend] Deleting expense {expense_id} for company_id: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id is required")
    
    try:
        # First check if expense exists
        check_query = "SELECT id FROM expenses WHERE id = %s AND company_id = %s"
        existing = execute_query(check_query, (expense_id, company_id), fetch=True)
        
        if not existing:
            print(f"❌ [Backend] Expense {expense_id} not found for company {company_id}")
            raise HTTPException(status_code=404, detail="Expense not found")
        
        # Delete the expense
        delete_query = "DELETE FROM expenses WHERE id = %s AND company_id = %s"
        result = execute_query(delete_query, (expense_id, company_id), fetch=False)
        
        print(f"✅ [Backend] Expense {expense_id} deleted successfully")
        print(f"🗂️ [Database] Table: pscdb.expenses | Operation: DELETE | Row ID: {expense_id}")
        
        return {"message": f"Expense {expense_id} deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error deleting expense: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Bank statement endpoints
@app.get("/bank-statements", response_model=List[BankStatement])
async def get_bank_statements(company_id: Optional[str] = None):
    """Get bank statements from database"""
    print(f"🏦 [Backend] Fetching bank statements for company_id: {company_id}")
    
    try:
        if company_id:
            query = "SELECT * FROM bank_statements WHERE company_id = %s ORDER BY created_at DESC"
            result = execute_query(query, (company_id,), fetch=True)
            print(f"🔍 [Backend] Found {len(result)} bank statements for company {company_id}")
        else:
            query = "SELECT * FROM bank_statements ORDER BY created_at DESC"
            result = execute_query(query, fetch=True)
            print(f"📋 [Backend] Returning all {len(result)} bank statements from database")
        
        bank_statements = []
        for row in result:
            bank_statements.append({
                "id": row["id"],
                "company_id": str(row["company_id"]),
                "transaction_date": str(row["transaction_date"]),
                "description": row["description"],
                "amount": float(row["amount"]),
                "balance": float(row["balance"])
            })
        
        return bank_statements
    except Exception as e:
        print(f"❌ [Backend] Database error fetching bank statements: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/bank-statements", response_model=BankStatement)
async def create_bank_statement(statement: BankStatement, company_id: str = None):
    """Create a new bank statement in database"""
    print(f"🏦 [Backend] Creating bank statement with data: {statement.dict()}")
    print(f"🏦 [Backend] Company ID from query: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id query parameter is required")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.bank_statements' table")
        
        query = """
            INSERT INTO bank_statements (company_id, transaction_date, description, amount, balance, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *
        """
        
        params = (
            int(company_id),
            statement.transaction_date,
            statement.description,
            statement.amount,
            statement.balance,
            datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            # For INSERT with RETURNING, we get a tuple with all columns
            if isinstance(result, tuple):
                statement_id = result[0]
                print(f"✅ [Backend] Bank statement successfully created in database with ID: {statement_id}")
                print(f"🗂️ [Database] Table: pscdb.bank_statements | Operation: INSERT | Row ID: {statement_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "transaction_date": str(result[2]),
                    "description": result[3],
                    "amount": float(result[4]),
                    "balance": float(result[5])
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise Exception("Failed to create bank statement - no result returned")
            
    except Exception as e:
        print(f"❌ [Backend] Database error creating bank statement: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.put("/bank-statements/{statement_id}", response_model=BankStatement)
async def update_bank_statement(statement_id: int, statement: BankStatement):
    """Update an existing bank statement in database"""
    print(f"🏦 [Backend] Updating bank statement {statement_id} with data: {statement.dict()}")
    
    try:
        print(f"💾 [Backend] Updating in AWS PostgreSQL database 'pscdb.bank_statements' table")
        
        query = """
            UPDATE bank_statements 
            SET company_id = %s, transaction_date = %s, description = %s, amount = %s, balance = %s
            WHERE id = %s
            RETURNING *
        """
        
        params = (
            int(statement.company_id),
            statement.transaction_date,
            statement.description,
            statement.amount,
            statement.balance,
            statement_id
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            if isinstance(result, tuple):
                print(f"✅ [Backend] Bank statement {statement_id} successfully updated in database")
                print(f"🗂️ [Database] Table: pscdb.bank_statements | Operation: UPDATE | Row ID: {statement_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "transaction_date": str(result[2]),
                    "description": result[3],
                    "amount": float(result[4]),
                    "balance": float(result[5])
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise HTTPException(status_code=404, detail="Bank statement not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error updating bank statement: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Payroll endpoints
@app.get("/payroll", response_model=List[PayrollEntry])
async def get_payroll_entries(company_id: Optional[str] = None):
    """Get payroll entries from database"""
    print(f"👨‍💼 [Backend] Fetching payroll entries for company_id: {company_id}")
    
    try:
        if company_id:
            query = "SELECT * FROM payroll WHERE company_id = %s ORDER BY created_at DESC"
            result = execute_query(query, (company_id,), fetch=True)
            print(f"🔍 [Backend] Found {len(result)} payroll entries for company {company_id}")
        else:
            query = "SELECT * FROM payroll ORDER BY created_at DESC"
            result = execute_query(query, fetch=True)
            print(f"📋 [Backend] Returning all {len(result)} payroll entries from database")
        
        payroll_entries = []
        for row in result:
            payroll_entries.append({
                "id": row["id"],
                "company_id": str(row["company_id"]),
                "period": row["period"],
                "employee_name": row["employee_name"],
                "gross_pay": float(row["gross_pay"]),
                "deductions": float(row["deductions"]),
                "net_pay": float(row["net_pay"]),
                "pay_date": str(row["pay_date"]) if row["pay_date"] else None,
                "employee_id": row["employee_id"]
            })
        
        return payroll_entries
    except Exception as e:
        print(f"❌ [Backend] Database error fetching payroll entries: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/payroll", response_model=PayrollEntry)
async def create_payroll_entry(payroll: PayrollEntry, company_id: str = None):
    """Create a new payroll entry in database"""
    print(f"👨‍💼 [Backend] Creating payroll entry with data: {payroll.dict()}")
    print(f"👨‍💼 [Backend] Company ID from query: {company_id}")
    
    if not company_id:
        raise HTTPException(status_code=400, detail="company_id query parameter is required")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.payroll' table")
        
        query = """
            INSERT INTO payroll (company_id, period, employee_name, gross_pay, deductions, net_pay, pay_date, employee_id, created_at, updated_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """
        
        params = (
            int(company_id),
            payroll.period,
            payroll.employee_name,
            payroll.gross_pay,
            payroll.deductions,
            payroll.net_pay,
            payroll.pay_date,
            payroll.employee_id,
            datetime.now(),
            datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result and isinstance(result, tuple):
            print(f"✅ [Backend] Payroll entry successfully created in database with ID: {result[0]}")
            print(f"🗂️ [Database] Table: pscdb.payroll | Operation: INSERT | Row ID: {result[0]}")
            
            return {
                "id": result[0],
                "company_id": str(result[1]),
                "period": result[2],
                "employee_name": result[3],
                "gross_pay": float(result[4]),
                "deductions": float(result[5]),
                "net_pay": float(result[6]),
                "pay_date": str(result[7]) if result[7] else None,
                "employee_id": result[8]
            }
        else:
            raise Exception(f"Unexpected result format: {type(result)}")
            
    except Exception as e:
        print(f"❌ [Backend] Database error creating payroll entry: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.put("/payroll/{payroll_id}", response_model=PayrollEntry)
async def update_payroll_entry(payroll_id: int, payroll: PayrollEntry):
    """Update an existing payroll entry in database"""
    print(f"👨‍💼 [Backend] Updating payroll entry {payroll_id} with data: {payroll.dict()}")
    
    try:
        print(f"💾 [Backend] Updating in AWS PostgreSQL database 'pscdb.payroll' table")
        
        query = """
            UPDATE payroll 
            SET company_id = %s, period = %s, employee_name = %s, gross_pay = %s, deductions = %s, net_pay = %s, pay_date = %s, employee_id = %s, updated_at = %s
            WHERE id = %s
            RETURNING *
        """
        
        params = (
            int(payroll.company_id),
            payroll.period,
            payroll.employee_name,
            payroll.gross_pay,
            payroll.deductions,
            payroll.net_pay,
            payroll.pay_date,
            payroll.employee_id,
            datetime.now(),
            payroll_id
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result:
            if isinstance(result, tuple):
                print(f"✅ [Backend] Payroll entry {payroll_id} successfully updated in database")
                print(f"🗂️ [Database] Table: pscdb.payroll | Operation: UPDATE | Row ID: {payroll_id}")
                
                return {
                    "id": result[0],
                    "company_id": str(result[1]),
                    "period": result[2],
                    "employee_name": result[3],
                    "gross_pay": float(result[4]),
                    "deductions": float(result[5]),
                    "net_pay": float(result[6]),
                    "pay_date": str(result[7]) if result[7] else None,
                    "employee_id": result[8]
                }
            else:
                raise Exception(f"Unexpected result format: {type(result)}")
        else:
            raise HTTPException(status_code=404, detail="Payroll entry not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Database error updating payroll entry: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.delete("/payroll/{payroll_id}")
async def delete_payroll_entry(payroll_id: int, company_id: Optional[str] = None):
    """Delete a payroll entry from database"""
    print(f"🗑️ [Backend] === STARTING PAYROLL DELETE ===")
    print(f"🗑️ [Backend] Payroll ID: {payroll_id}")
    print(f"🗑️ [Backend] Company ID: {company_id}")
    
    try:
        # Delete the payroll entry
        delete_query = "DELETE FROM payroll WHERE id = %s AND company_id = %s"
        result = execute_query(delete_query, (payroll_id, company_id), fetch=False)
        
        print(f"✅ [Backend] Payroll entry {payroll_id} deleted successfully")
        print(f"🗂️ [Database] Table: pscdb.payroll | Operation: DELETE | Row ID: {payroll_id}")
        
        return {"message": f"Payroll entry {payroll_id} deleted successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Database error deleting payroll entry: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ================== EMPLOYEE ENDPOINTS ==================

@app.get("/employees", response_model=List[Employee])
async def get_employees(company_id: Optional[str] = None):
    """Get all employees for a company from database"""
    print(f"👥 [Backend] Fetching employees for company_id: {company_id}")
    
    try:
        # Query database for employees
        query = """
        SELECT id, company_id, name, email, phone_number, position, department,
               base_salary, hire_date, is_active, created_at, updated_at
        FROM employees 
        WHERE company_id = %s 
        ORDER BY name ASC
        """
        
        rows = execute_query(query, (company_id,), fetch=True)
        employees = []
        
        for row in rows:
            employee_data = {
                'id': row['id'],
                'company_id': str(row['company_id']),
                'name': row['name'],
                'email': row['email'],
                'phone_number': row['phone_number'],
                'position': row['position'],
                'department': row['department'],
                'base_salary': float(row['base_salary']) if row['base_salary'] is not None else None,
                'hire_date': row['hire_date'].isoformat() if row['hire_date'] is not None else None,
                'is_active': row['is_active'],
                'created_at': row['created_at'].isoformat() if row['created_at'] is not None else None,
                'updated_at': row['updated_at'].isoformat() if row['updated_at'] is not None else None
            }
            employees.append(Employee(**employee_data))
        
        print(f"✅ [Backend] Found {len(employees)} employees")
        return employees
        
    except Exception as e:
        print(f"❌ [Backend] Database error fetching employees: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.post("/employees", response_model=Employee)
async def create_employee(employee: Employee, company_id: Optional[str] = None):
    """Create a new employee in database"""
    print(f"👥 [Backend] Creating new employee: {employee.name}")
    print(f"👥 [Backend] Company ID: {company_id}")
    
    try:
        # Insert employee into database
        insert_query = """
        INSERT INTO employees (company_id, name, email, phone_number, position, department,
                             base_salary, hire_date, is_active, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id, company_id, name, email, phone_number, position, department,
                  base_salary, hire_date, is_active, created_at, updated_at
        """
        
        hire_date = datetime.fromisoformat(employee.hire_date).date() if employee.hire_date else None
        now = datetime.now()
        
        result = execute_query(insert_query, (
            company_id,
            employee.name,
            employee.email,
            employee.phone_number,
            employee.position,
            employee.department,
            employee.base_salary,
            hire_date,
            employee.is_active,
            now,
            now
        ), fetch=True)
        
        if result:
            # For INSERT with RETURNING and fetch=True, result is a single tuple
            row = result  # result is already the tuple, not a list
            created_employee = Employee(
                id=row[0],
                company_id=str(row[1]),
                name=row[2],
                email=row[3],
                phone_number=row[4],
                position=row[5],
                department=row[6],
                base_salary=float(row[7]) if row[7] is not None else None,
                hire_date=row[8].isoformat() if row[8] is not None else None,
                is_active=row[9],
                created_at=row[10].isoformat() if row[10] is not None else None,
                updated_at=row[11].isoformat() if row[11] is not None else None
            )
            
            print(f"✅ [Backend] Employee {employee.name} created with ID: {created_employee.id}")
            return created_employee
        else:
            raise Exception("Failed to create employee")
        
    except Exception as e:
        print(f"❌ [Backend] Database error creating employee: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.put("/employees/{employee_id}", response_model=Employee)
async def update_employee(employee_id: int, employee: Employee, company_id: Optional[str] = None):
    """Update an employee in database"""
    print(f"👥 [Backend] Updating employee ID: {employee_id}")
    print(f"👥 [Backend] Employee name: {employee.name}")
    print(f"👥 [Backend] Company ID: {company_id}")
    
    try:
        # Update employee in database
        update_query = """
        UPDATE employees 
        SET name = %s, email = %s, phone_number = %s, position = %s, department = %s,
            base_salary = %s, hire_date = %s, is_active = %s, updated_at = %s
        WHERE id = %s AND company_id = %s
        RETURNING id, company_id, name, email, phone_number, position, department,
                  base_salary, hire_date, is_active, created_at, updated_at
        """
        
        hire_date = datetime.fromisoformat(employee.hire_date).date() if employee.hire_date else None
        now = datetime.now()
        
        result = execute_query(update_query, (
            employee.name,
            employee.email,
            employee.phone_number,
            employee.position,
            employee.department,
            employee.base_salary,
            hire_date,
            employee.is_active,
            now,
            employee_id,
            company_id
        ), fetch=True)
        
        if result:
            # For UPDATE with RETURNING and fetch=True, result is a single tuple
            row = result  # result is already the tuple, not a list
            updated_employee = Employee(
                id=row[0],
                company_id=str(row[1]),
                name=row[2],
                email=row[3],
                phone_number=row[4],
                position=row[5],
                department=row[6],
                base_salary=float(row[7]) if row[7] is not None else None,
                hire_date=row[8].isoformat() if row[8] is not None else None,
                is_active=row[9],
                created_at=row[10].isoformat() if row[10] is not None else None,
                updated_at=row[11].isoformat() if row[11] is not None else None
            )
            
            print(f"✅ [Backend] Employee {employee.name} updated successfully")
            return updated_employee
        else:
            raise HTTPException(status_code=404, detail="Employee not found")
        
    except Exception as e:
        print(f"❌ [Backend] Database error updating employee: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.delete("/employees/{employee_id}")
async def delete_employee(employee_id: int, company_id: Optional[str] = None):
    """Delete an employee from database"""
    print(f"👥 [Backend] === STARTING EMPLOYEE DELETE ===")
    print(f"👥 [Backend] Employee ID: {employee_id}")
    print(f"👥 [Backend] Company ID: {company_id}")
    
    try:
        # Delete the employee
        delete_query = "DELETE FROM employees WHERE id = %s AND company_id = %s"
        result = execute_query(delete_query, (employee_id, company_id), fetch=False)
        
        print(f"✅ [Backend] Employee {employee_id} deleted successfully")
        print(f"🗂️ [Database] Table: pscdb.employees | Operation: DELETE | Row ID: {employee_id}")
        
        return {"message": f"Employee {employee_id} deleted successfully"}
        
    except Exception as e:
        print(f"❌ [Backend] Database error deleting employee: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ================== EXPENSE CATEGORIES ==================

# Document attachment endpoints for PDF storage
@app.get("/expense-categories")
async def get_expense_categories():
    """Get list of expense categories"""
    print(f"📂 [Backend] Fetching expense categories")
    
    # Return a standard list of expense categories
    categories = [
        "Office Supplies",
        "Technology",
        "Travel & Transportation",
        "Meals & Entertainment",
        "Marketing & Advertising",
        "Professional Services",
        "Utilities",
        "Rent & Facilities", 
        "Insurance",
        "Training & Education",
        "Equipment",
        "Software & Subscriptions",
        "Other"
    ]
    
    print(f"✅ [Backend] Returning {len(categories)} expense categories")
    return categories

@app.get("/employees")
async def get_employees(company_id: Optional[str] = None):
    """Get list of employees for a company"""
    print(f"👥 [Backend] Fetching employees for company_id: {company_id}")
    
    try:
        if company_id:
            # Query employees from payroll entries (since we don't have a separate employees table)
            query = """
                SELECT DISTINCT employee_name, employee_id 
                FROM payroll 
                WHERE company_id = %s 
                AND employee_name IS NOT NULL
                ORDER BY employee_name
            """
            result = execute_query(query, (company_id,), fetch=True)
            
            employees = []
            for row in result:
                employees.append({
                    "name": row["employee_name"],
                    "employee_id": row["employee_id"] or f"EMP-{len(employees)+1:03d}"
                })
            
            print(f"✅ [Backend] Found {len(employees)} employees for company {company_id}")
            return employees
        else:
            # Return empty list if no company_id provided
            print(f"⚠️ [Backend] No company_id provided, returning empty employee list")
            return []
            
    except Exception as e:
        print(f"❌ [Backend] Database error fetching employees: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Document attachment endpoints for PDF storage
@app.post("/documents/upload")
async def upload_document(
    entity_type: str,  # 'invoice', 'expense', 'bank_statement'
    entity_id: int,
    company_id: int,
    filename: str,
    file_data: bytes
):
    """Upload a PDF document attachment"""
    print(f"📎 [Backend] Uploading document for {entity_type} {entity_id}")
    
    try:
        print(f"💾 [Backend] Writing to AWS PostgreSQL database 'pscdb.document_attachments' table")
        
        # Determine MIME type based on file extension
        mime_type = "application/pdf" if filename.lower().endswith('.pdf') else "application/octet-stream"
        
        query = """
            INSERT INTO document_attachments 
            (entity_type, entity_id, company_id, filename, original_filename, file_data, file_size, mime_type, created_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, filename, file_size, mime_type, created_at
        """
        
        params = (
            entity_type,
            entity_id,
            company_id,
            filename,
            filename,  # original_filename same as filename for now
            file_data,
            len(file_data),
            mime_type,
            datetime.now()
        )
        
        result = execute_query(query, params, fetch=True)
        
        if result and isinstance(result, tuple):
            doc_id = result[0]
            print(f"✅ [Backend] Document successfully uploaded with ID: {doc_id}")
            print(f"🗂️ [Database] Table: pscdb.document_attachments | Operation: INSERT | Row ID: {doc_id}")
            
            return {
                "id": result[0],
                "entity_type": entity_type,
                "entity_id": entity_id,
                "company_id": company_id,
                "filename": result[1],
                "file_size": result[2],
                "mime_type": result[3],
                "created_at": result[4]
            }
        else:
            raise Exception("Failed to upload document - no result returned")
            
    except Exception as e:
        print(f"❌ [Backend] Database error uploading document: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/documents/download/{document_id}")
async def download_document(document_id: int):
    """Download a document attachment by ID using robust deserialization."""
    import psycopg2
    import psycopg2.extras
    import pickle
    import json
    import base64
    
    try:
        print(f"📎 [Backend] Download request for document_id: {document_id}")
        
        # Database connection parameters from your working code
        db_config = {
            'host': 'pscdb.cnacsqi4u8qw.eu-west-1.rds.amazonaws.com',
            'port': '5432',
            'database': 'pscdb',
            'user': 'postgres',
            'password': 'Il1k3f1sh1ngperch!'
        }
        
        # SQL query
        query = """
        SELECT id, filename, original_filename, file_data, mime_type, file_size 
        FROM document_attachments 
        WHERE id = %s AND company_id = 1
        """
        
        connection = None
        cursor = None
        
        try:
            # Connect to PostgreSQL database
            print("🔌 Connecting to PostgreSQL database...")
            connection = psycopg2.connect(**db_config)
            cursor = connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            print(f"🔍 Querying for attachment_id={document_id}, company_id=1")
            
            # Execute query
            cursor.execute(query, (document_id,))
            result = cursor.fetchone()
            
            if not result:
                print(f"❌ No document found with id={document_id} and company_id=1")
                raise HTTPException(status_code=404, detail="Document not found")
            
            # Extract results (RealDictCursor allows dict-like access)
            doc_id = result['id']
            filename = result['filename']
            original_filename = result['original_filename']
            file_data = result['file_data']
            mime_type = result['mime_type']
            file_size = result['file_size']
            
            print(f"✅ Found document: {original_filename or filename} ({file_size} bytes, {mime_type})")
            
            # Deserialize file_data - try multiple common serialization methods
            pdf_content = None
            
            # Handle different PostgreSQL data types
            if isinstance(file_data, memoryview):
                file_data = file_data.tobytes()
            elif isinstance(file_data, str):
                file_data = file_data.encode('utf-8')
            
            # Method 1: Try base64 decoding
            try:
                if isinstance(file_data, bytes):
                    # Try to decode as base64
                    pdf_content = base64.b64decode(file_data)
                    print("✅ Successfully decoded using base64")
                else:
                    pdf_content = base64.b64decode(str(file_data))
                    print("✅ Successfully decoded using base64 (from string)")
            except Exception as e:
                print(f"⚠️ Base64 decode failed: {e}")
                pass
            
            # Method 2: Try pickle deserialization
            if pdf_content is None:
                try:
                    pdf_content = pickle.loads(file_data)
                    print("✅ Successfully deserialized using pickle")
                except Exception as e:
                    print(f"⚠️ Pickle deserialization failed: {e}")
                    pass
            
            # Method 3: Try JSON deserialization (if stored as JSON string)
            if pdf_content is None:
                try:
                    json_data = json.loads(file_data.decode('utf-8') if isinstance(file_data, bytes) else file_data)
                    if isinstance(json_data, str):
                        pdf_content = base64.b64decode(json_data)
                    else:
                        pdf_content = bytes(json_data)
                    print("✅ Successfully deserialized using JSON")
                except Exception as e:
                    print(f"⚠️ JSON deserialization failed: {e}")
                    pass
            
            # Method 4: Assume it's already binary data (PostgreSQL BYTEA)
            if pdf_content is None:
                try:
                    pdf_content = file_data if isinstance(file_data, bytes) else file_data.encode()
                    print("✅ Using data as-is (assuming PostgreSQL BYTEA)")
                except Exception as e:
                    print(f"⚠️ Direct binary usage failed: {e}")
                    pass
            
            if pdf_content is None:
                raise Exception("Could not deserialize file_data using any known method")
            
            # Validate PDF content (check for PDF magic number)
            if not pdf_content.startswith(b'%PDF'):
                print("⚠️ Warning: File doesn't appear to be a valid PDF (missing PDF header)")
            
            # Determine filename
            response_filename = original_filename or filename or f"document_{doc_id}.pdf"
            if not response_filename.lower().endswith('.pdf'):
                response_filename += '.pdf'
            
            print(f"📊 PDF deserialized successfully: {len(pdf_content)} bytes")
            
            # Encode as base64 for JSON response
            encoded_data = base64.b64encode(pdf_content).decode('utf-8')
            
            response_data = {
                "filename": response_filename,
                "file_size": len(pdf_content),
                "file_data": encoded_data,
                "mime_type": mime_type or 'application/pdf'
            }
            
            print(f"✅ [Backend] Returning response with filename: {response_filename}, size: {len(pdf_content)} bytes")
            return response_data
            
        finally:
            # Clean up database connections
            if cursor:
                cursor.close()
            if connection:
                connection.close()
                print("🔌 Database connection closed")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error in download_document: {str(e)}")
        print(f"❌ [Backend] Error type: {type(e)}")
        print(f"❌ [Backend] Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/documents/{entity_type}/{entity_id}")
async def get_documents(entity_type: str, entity_id: int, company_id: int):
    """Get all documents for a specific entity"""
    print(f"📎 [Backend] Fetching documents for {entity_type} {entity_id}")
    
    try:
        query = """
            SELECT id, filename, file_size, mime_type, created_at 
            FROM document_attachments 
            WHERE entity_type = %s AND entity_id = %s AND company_id = %s
            ORDER BY created_at DESC
        """
        
        result = execute_query(query, (entity_type, entity_id, company_id), fetch=True)
        
        documents = []
        if result:
            # Handle both single row and list of rows
            results = [result] if isinstance(result, dict) else result
            for row in results:
                documents.append({
                    "id": row["id"],
                    "filename": row["filename"],
                    "file_size": row["file_size"],
                    "mime_type": row["mime_type"],
                    "created_at": row["created_at"]
                })
        
        print(f"🔍 [Backend] Found {len(documents)} documents for {entity_type} {entity_id}")
        return documents
        
    except Exception as e:
        print(f"❌ [Backend] Database error fetching documents: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
    """Download a document attachment by ID using robust deserialization."""
    import psycopg2
    import psycopg2.extras
    import pickle
    import json
    import base64
    
    try:
        print(f"📎 [Backend] Download request for document_id: {document_id}")
    import base64
    # Database connection parameters from your working code
    try:
        print(f"📎 [Backend] Download request for document_id: {document_id}")
        
        # Database connection parameters from your working codecdb',
        db_config = {
            'host': 'pscdb.cnacsqi4u8qw.eu-west-1.rds.amazonaws.com',1sh1ngperch!'
            'port': '5432',
            'database': 'pscdb',
            'user': 'postgres',# SQL query
            'password': 'Il1k3f1sh1ngperch!'
        }filename, original_filename, file_data, mime_type, file_size 
        
        # SQL queryid = 1
        query = """
        SELECT id, filename, original_filename, file_data, mime_type, file_size 
        FROM document_attachments connection = None
        WHERE id = %s AND company_id = 1
        """
        try:
        connection = None# Connect to PostgreSQL database
        cursor = NoneL database...")
        
        try:psycopg2.extras.RealDictCursor)
            # Connect to PostgreSQL database
            print("� Connecting to PostgreSQL database...")print(f"🔍 Querying for attachment_id={document_id}, company_id=1")
            connection = psycopg2.connect(**db_config)
            cursor = connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)# Execute query
            query, (document_id,))
            print(f"🔍 Querying for attachment_id={document_id}, company_id=1")
            
            # Execute queryif not result:
            cursor.execute(query, (document_id,))No document found with id={document_id} and company_id=1")
            result = cursor.fetchone()
            
            if not result:# Extract results (RealDictCursor allows dict-like access)
                print(f"❌ No document found with id={document_id} and company_id=1")
                raise HTTPException(status_code=404, detail="Document not found")lename']
            riginal_filename']
            # Extract results (RealDictCursor allows dict-like access)
            doc_id = result['id']
            filename = result['filename']
            original_filename = result['original_filename']
            file_data = result['file_data']print(f"✅ Found document: {original_filename or filename} ({file_size} bytes, {mime_type})")
            mime_type = result['mime_type']
            file_size = result['file_size']# Deserialize file_data - try multiple common serialization methods
            
            print(f"✅ Found document: {original_filename or filename} ({file_size} bytes, {mime_type})")
            # Handle different PostgreSQL data types
            # Deserialize file_data - try multiple common serialization methods
            pdf_content = None
            
            # Handle different PostgreSQL data types('utf-8')
            if isinstance(file_data, memoryview):
                file_data = file_data.tobytes()# Method 1: Try base64 decoding
            elif isinstance(file_data, str):
                file_data = file_data.encode('utf-8')if isinstance(file_data, bytes):
            
            # Method 1: Try base64 decodingecode(file_data)
            try:4")
                if isinstance(file_data, bytes):
                    # Try to decode as base64df_content = base64.b64decode(str(file_data))
                    pdf_content = base64.b64decode(file_data)om string)")
                    print("✅ Successfully decoded using base64")
                else:decode failed: {e}")
                    pdf_content = base64.b64decode(str(file_data))
                    print("✅ Successfully decoded using base64 (from string)")
            except Exception as e:# Method 2: Try pickle deserialization
                print(f"⚠️ Base64 decode failed: {e}")
                pass
            pdf_content = pickle.loads(file_data)
            # Method 2: Try pickle deserializationing pickle")
            if pdf_content is None:
                try:deserialization failed: {e}")
                    pdf_content = pickle.loads(file_data)
                    print("✅ Successfully deserialized using pickle")
                except Exception as e:# Method 3: Try JSON deserialization (if stored as JSON string)
                    print(f"⚠️ Pickle deserialization failed: {e}")
                    pass
            json_data = json.loads(file_data.decode('utf-8') if isinstance(file_data, bytes) else file_data)
            # Method 3: Try JSON deserialization (if stored as JSON string)
            if pdf_content is None:code(json_data)
                try:
                    json_data = json.loads(file_data.decode('utf-8') if isinstance(file_data, bytes) else file_data)df_content = bytes(json_data)
                    if isinstance(json_data, str): using JSON")
                        pdf_content = base64.b64decode(json_data)
                    else:serialization failed: {e}")
                        pdf_content = bytes(json_data)
                    print("✅ Successfully deserialized using JSON")
                except Exception as e:# Method 4: Assume it's already binary data (PostgreSQL BYTEA)
                    print(f"⚠️ JSON deserialization failed: {e}")
                    pass
            pdf_content = file_data if isinstance(file_data, bytes) else file_data.encode()
            # Method 4: Assume it's already binary data (PostgreSQL BYTEA)
            if pdf_content is None:
                try:binary usage failed: {e}")
                    pdf_content = file_data if isinstance(file_data, bytes) else file_data.encode()
                    print("✅ Using data as-is (assuming PostgreSQL BYTEA)")
                except Exception as e:if pdf_content is None:
                    print(f"⚠️ Direct binary usage failed: {e}")uld not deserialize file_data using any known method")
                    pass
            # Validate PDF content (check for PDF magic number)
            if pdf_content is None:
                raise Exception("Could not deserialize file_data using any known method")ear to be a valid PDF (missing PDF header)")
            
            # Validate PDF content (check for PDF magic number)# Determine filename
            if not pdf_content.startswith(b'%PDF'):original_filename or filename or f"document_{doc_id}.pdf"
                print("⚠️ Warning: File doesn't appear to be a valid PDF (missing PDF header)")
            
            # Determine filename
            response_filename = original_filename or filename or f"document_{doc_id}.pdf"print(f"📊 PDF deserialized successfully: {len(pdf_content)} bytes")
            
            # Encode as base64 for JSON response
            encoded_data = base64.b64encode(pdf_content).decode('utf-8')
            
            response_data = {
                "filename": response_filename,
                "file_size": len(pdf_content),
                "file_data": encoded_data,
                "mime_type": mime_type or 'application/pdf'
            }
            
            print(f"✅ [Backend] Returning response with filename: {response_filename}, size: {len(pdf_content)} bytes")
            return response_data
            
        finally:
            # Clean up database connections
            if cursor:
                cursor.close()
            if connection:
                connection.close()
                print("🔌 Database connection closed")
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Backend] Error in download_document: {str(e)}")
        print(f"❌ [Backend] Error type: {type(e)}")
        print(f"❌ [Backend] Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
