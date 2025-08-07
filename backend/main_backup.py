from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
from database import initialize_db_pool, close_db_pool, execute_query
from datetime import datetime

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
    company_id: str
    client_name: str
    amount: float
    date: str
    status: str = "pending"

class Expense(BaseModel):
    id: Optional[int] = None
    company_id: str
    description: str
    amount: float
    date: str
    category: str

class BankStatement(BaseModel):
    id: Optional[int] = None
    company_id: str
    transaction_date: str
    description: str
    amount: float
    balance: float

class Payslip(BaseModel):
    id: Optional[int] = None
    company_id: str
    employee_name: str
    month: str
    gross_salary: float
    net_salary: float
    status: str = "draft"

# In-memory storage for non-company entities (to be replaced with database)
invoices_db = []
expenses_db = []
payslips_db = []
bank_statements_db = []

@app.get("/")
async def root():
    return {"message": "PSC Accounting API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

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
        
        if result and len(result) > 0:
            created_company = result[0]
            company_id = created_company[0]  # First column is ID
            print(f"✅ [Backend] Company successfully created in database with ID: {company_id}")
            print(f"🗂️ [Database] Table: pscdb.companies | Operation: INSERT | Row ID: {company_id}")
            
            # Return the created company in the expected format
            return {
                "id": company_id,
                "name": created_company[1],  # name
                "slug": created_company[2],  # slug
                "owner_email": created_company[3],  # owner_email
                "phone": created_company[4] or '',  # phone
                "address": created_company[5] or '',  # address
                "subscription_plan": created_company[6],  # subscription_plan
                "is_demo": created_company[7],  # is_demo
                "created_at": created_company[8],  # created_at
                "status": created_company[9],  # status
                "email": ""  # Not stored in DB but required by Flutter model
            }
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
    if company_id:
        return [invoice for invoice in invoices_db if invoice.get("company_id") == company_id]
    return invoices_db

@app.post("/invoices", response_model=Invoice)
async def create_invoice(invoice: Invoice):
    print(f"📄 [Backend] Creating invoice with data: {invoice.dict()}")
    
    invoice.id = max([i.get("id", 0) for i in invoices_db], default=0) + 1
    invoice_dict = invoice.dict()
    
    print(f"📋 [Backend] Generated invoice ID: {invoice.id}")
    print(f"⚠️ [Backend] WARNING: Using IN-MEMORY storage for invoices - data will be lost on server restart!")
    
    invoices_db.append(invoice_dict)
    
    print(f"✅ [Backend] Invoice added to in-memory storage")
    
    return invoice

# Expense endpoints
@app.get("/expenses", response_model=List[Expense])
async def get_expenses(company_id: Optional[str] = None):
    if company_id:
        return [expense for expense in expenses_db if expense.get("company_id") == company_id]
    return expenses_db

@app.post("/expenses", response_model=Expense)
async def create_expense(expense: Expense):
    print(f"💰 [Backend] Creating expense with data: {expense.dict()}")
    
    expense.id = max([e.get("id", 0) for e in expenses_db], default=0) + 1
    expense_dict = expense.dict()
    
    print(f"📋 [Backend] Generated expense ID: {expense.id}")
    print(f"⚠️ [Backend] WARNING: Using IN-MEMORY storage for expenses - data will be lost on server restart!")
    
    expenses_db.append(expense_dict)
    
    print(f"✅ [Backend] Expense added to in-memory storage")
    
    return expense

# Payslips endpoints
@app.get("/payslips", response_model=List[Payslip])
async def get_payslips(company_id: Optional[str] = None):
    if company_id:
        return [payslip for payslip in payslips_db if payslip.get("company_id") == company_id]
    return payslips_db

@app.post("/payslips", response_model=Payslip)
async def create_payslip(payslip: Payslip):
    print(f"💼 [Backend] Creating payslip with data: {payslip.dict()}")
    
    payslip.id = max([p.get("id", 0) for p in payslips_db], default=0) + 1
    payslip_dict = payslip.dict()
    
    print(f"📋 [Backend] Generated payslip ID: {payslip.id}")
    print(f"⚠️ [Backend] WARNING: Using IN-MEMORY storage for payslips - data will be lost on server restart!")
    
    payslips_db.append(payslip_dict)
    
    print(f"✅ [Backend] Payslip added to in-memory storage")
    
    return payslip

# Bank statement endpoints
@app.get("/bank-statements", response_model=List[BankStatement])
async def get_bank_statements(company_id: Optional[str] = None):
    if company_id:
        return [statement for statement in bank_statements_db if statement.get("company_id") == company_id]
    return bank_statements_db

@app.post("/bank-statements", response_model=BankStatement)
async def create_bank_statement(statement: BankStatement):
    statement.id = max([s.get("id", 0) for s in bank_statements_db], default=0) + 1
    statement_dict = statement.dict()
    bank_statements_db.append(statement_dict)
    return statement

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
