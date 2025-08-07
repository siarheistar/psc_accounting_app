#!/usr/bin/env python3

import sys
import os

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import execute_query

def create_payroll_table():
    """Create the payroll table in the database"""
    
    print("🗂️ [Database] Creating payroll table...")
    
    # Create payroll table
    payroll_table_sql = """
    CREATE TABLE IF NOT EXISTS payroll (
        id SERIAL PRIMARY KEY,
        company_id INTEGER NOT NULL,
        period VARCHAR(50) NOT NULL,
        employee_name VARCHAR(255) NOT NULL,
        gross_pay DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        deductions DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        net_pay DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        pay_date DATE,
        employee_id VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
    );
    """
    
    # Create indexes for better performance
    payroll_indexes = [
        "CREATE INDEX IF NOT EXISTS idx_payroll_company_id ON payroll(company_id);",
        "CREATE INDEX IF NOT EXISTS idx_payroll_period ON payroll(period);",
        "CREATE INDEX IF NOT EXISTS idx_payroll_employee_name ON payroll(employee_name);",
        "CREATE INDEX IF NOT EXISTS idx_payroll_pay_date ON payroll(pay_date);"
    ]
    
    try:
        # Create table
        execute_query(payroll_table_sql)
        print("✅ [Database] payroll table created successfully")
        
        # Create indexes
        for index_sql in payroll_indexes:
            execute_query(index_sql)
            print(f"✅ [Database] Index created: {index_sql.split('idx_')[1].split(' ')[0]}")
        
        print("\n🎉 [Database] Payroll table setup completed successfully!")
        print("📊 [Table Structure] payroll:")
        print("   - id (SERIAL, PRIMARY KEY)")
        print("   - company_id (INTEGER, FOREIGN KEY)")
        print("   - period (VARCHAR(50))")
        print("   - employee_name (VARCHAR(255))")
        print("   - gross_pay (DECIMAL(10,2))")
        print("   - deductions (DECIMAL(10,2))")
        print("   - net_pay (DECIMAL(10,2))")
        print("   - pay_date (DATE)")
        print("   - employee_id (VARCHAR(50))")
        print("   - created_at (TIMESTAMP)")
        print("   - updated_at (TIMESTAMP)")
        
    except Exception as e:
        print(f"❌ [Database] Error creating payroll table: {e}")
        raise

if __name__ == "__main__":
    create_payroll_table()
