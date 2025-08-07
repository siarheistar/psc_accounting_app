#!/usr/bin/env python3
"""
Create database tables for PSC Accounting App
This script creates tables that match the current API structure
"""

from database import execute_query

def create_tables():
    """Create all required database tables"""
    
    print("🗄️ [Setup] Creating database tables...")
    
    # 1. Create invoices table (matching real database schema)
    invoices_table = """
    CREATE TABLE IF NOT EXISTS invoices (
        id SERIAL PRIMARY KEY,
        company_id INTEGER NOT NULL,
        client_name VARCHAR(255) NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        date DATE NOT NULL,
        due_date DATE NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    # 2. Create expenses table (matching real database schema)
    expenses_table = """
    CREATE TABLE IF NOT EXISTS expenses (
        id SERIAL PRIMARY KEY,
        company_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        date DATE NOT NULL,
        category VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    # 3. Create payroll table (matching API expectations)
    payroll_table = """
    CREATE TABLE IF NOT EXISTS payroll (
        id SERIAL PRIMARY KEY,
        company_id INTEGER NOT NULL,
        employee_name VARCHAR(255) NOT NULL,
        period VARCHAR(100) NOT NULL,
        gross_pay DECIMAL(10,2) NOT NULL,
        deductions DECIMAL(10,2) DEFAULT 0,
        net_pay DECIMAL(10,2) NOT NULL,
        pay_date DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    # 4. Create employees table (matching real database schema)
    employees_table = """
    CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        company_id VARCHAR(36) NOT NULL,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255),
        phone_number VARCHAR(20),
        position VARCHAR(100),
        department VARCHAR(100),
        base_salary DECIMAL(10,2),
        hire_date DATE,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    # 5. Create bank_statements table
    bank_statements_table = """
    CREATE TABLE IF NOT EXISTS bank_statements (
        id SERIAL PRIMARY KEY,
        company_id INTEGER NOT NULL,
        transaction_date DATE NOT NULL,
        description TEXT NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        balance DECIMAL(10,2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    # 6. Create document_attachments table for PDF storage
    documents_table = """
    CREATE TABLE IF NOT EXISTS document_attachments (
        id SERIAL PRIMARY KEY,
        entity_type VARCHAR(50) NOT NULL, -- 'invoice', 'expense', 'bank_statement', 'payroll'
        entity_id INTEGER NOT NULL,
        company_id INTEGER NOT NULL,
        filename VARCHAR(255) NOT NULL,
        original_filename VARCHAR(255) NOT NULL,
        file_data BYTEA NOT NULL,
        file_size INTEGER NOT NULL,
        mime_type VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    
    try:
        # Create tables
        execute_query(invoices_table)
        print("✅ [Setup] Created invoices table")
        
        execute_query(expenses_table)
        print("✅ [Setup] Created expenses table")
        
        execute_query(payroll_table)
        print("✅ [Setup] Created payroll table")
        
        execute_query(employees_table)
        print("✅ [Setup] Created employees table")
        
        execute_query(bank_statements_table)
        print("✅ [Setup] Created bank_statements table")
        
        execute_query(documents_table)
        print("✅ [Setup] Created document_attachments table")
        
        print("🎉 [Setup] All database tables created successfully!")
        
    except Exception as e:
        print(f"❌ [Setup] Error creating tables: {e}")
        raise

if __name__ == "__main__":
    from database import initialize_db_pool
    
    # Initialize database connection
    if initialize_db_pool():
        create_tables()
    else:
        print("❌ [Setup] Failed to initialize database connection")
