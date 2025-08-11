#!/usr/bin/env python3
"""
VAT Fix Migration - Fix the VAT system to match existing schema
"""

import psycopg2
from env_config import env_config

def fix_vat_migration():
    """Fix VAT migration issues"""
    
    try:
        # Get database connection details
        db_host = env_config.get_config("DB_HOST")
        db_port = env_config.get_config("DB_PORT", "5432")
        db_name = env_config.get_config("DB_NAME")
        db_user = env_config.get_config("DB_USER")
        db_password = env_config.get_config("DB_PASSWORD")
        
        print(f"🔗 Connecting to database: {db_host}:{db_port}/{db_name}")
        
        # Create connection
        conn = psycopg2.connect(
            host=db_host,
            port=db_port,
            database=db_name,
            user=db_user,
            password=db_password
        )
        
        cursor = conn.cursor()
        
        print("🔧 Fixing VAT system schema...")
        
        # 1. Fix invoices.vat_rate_id column type (change from UUID to INTEGER)
        print("1. Fixing invoices.vat_rate_id column type...")
        cursor.execute("""
            ALTER TABLE public.invoices 
            DROP COLUMN IF EXISTS vat_rate_id CASCADE;
        """)
        cursor.execute("""
            ALTER TABLE public.invoices 
            ADD COLUMN vat_rate_id INTEGER REFERENCES public.vat_rates(id);
        """)
        
        # 2. Add missing columns to expenses table
        print("2. Adding VAT columns to expenses table...")
        
        # Add columns one by one with error handling
        columns_to_add = [
            ("category_id", "INTEGER REFERENCES public.expense_categories(id)"),
            ("vat_rate_id", "INTEGER REFERENCES public.vat_rates(id)"),
            ("business_usage_percentage", "NUMERIC(5,2) DEFAULT 100.00"),
            ("deductible_amount", "NUMERIC(10,2)"),
            ("expense_type", "VARCHAR(50) DEFAULT 'general'"),
            ("eworker_days", "NUMERIC(5,2)"),
            ("eworker_rate", "NUMERIC(8,2)"),
            ("mileage_km", "NUMERIC(8,2)"),
            ("mileage_rate", "NUMERIC(6,4) DEFAULT 0.3708"),
            ("receipt_required", "BOOLEAN DEFAULT TRUE"),
            ("notes", "TEXT"),
            ("vat_amount", "NUMERIC(10,2)"),
            ("gross_amount", "NUMERIC(10,2)"),
            ("supplier_name", "VARCHAR(255)"),
            ("paid", "BOOLEAN DEFAULT FALSE")
        ]
        
        for col_name, col_def in columns_to_add:
            try:
                cursor.execute(f"""
                    ALTER TABLE public.expenses 
                    ADD COLUMN IF NOT EXISTS {col_name} {col_def};
                """)
                print(f"  ✅ Added column: {col_name}")
            except Exception as e:
                print(f"  ⚠️ Column {col_name}: {e}")
        
        # 3. Add missing columns to invoices table
        print("3. Adding missing columns to invoices table...")
        
        invoice_columns = [
            ("invoice_number", "VARCHAR(50)"),
            ("issue_date", "DATE"),
            ("customer_name", "VARCHAR(255)"),
            ("net_amount", "NUMERIC(10,2)"),
            ("vat_amount", "NUMERIC(10,2)"),
            ("gross_amount", "NUMERIC(10,2)"),
            ("paid", "BOOLEAN DEFAULT FALSE"),
            ("description", "TEXT")
        ]
        
        for col_name, col_def in invoice_columns:
            try:
                cursor.execute(f"""
                    ALTER TABLE public.invoices 
                    ADD COLUMN IF NOT EXISTS {col_name} {col_def};
                """)
                print(f"  ✅ Added column: {col_name}")
            except Exception as e:
                print(f"  ⚠️ Column {col_name}: {e}")
        
        # 4. Create E-Worker Periods Table
        print("4. Creating eworker_periods table...")
        cursor.execute("""
            DROP TABLE IF EXISTS public.eworker_periods CASCADE;
            CREATE TABLE public.eworker_periods (
                id SERIAL PRIMARY KEY,
                company_id INTEGER REFERENCES public.companies(id) ON DELETE CASCADE,
                period_start DATE NOT NULL,
                period_end DATE NOT NULL,
                total_days NUMERIC(5,2),
                daily_rate NUMERIC(8,2),
                total_amount NUMERIC(10,2),
                status VARCHAR(20) DEFAULT 'draft',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        print("  ✅ Created eworker_periods table")
        
        # 5. Create Mileage Log Table  
        print("5. Creating mileage_log table...")
        cursor.execute("""
            DROP TABLE IF EXISTS public.mileage_log CASCADE;
            CREATE TABLE public.mileage_log (
                id SERIAL PRIMARY KEY,
                company_id INTEGER REFERENCES public.companies(id) ON DELETE CASCADE,
                expense_id INTEGER REFERENCES public.expenses(id) ON DELETE CASCADE,
                trip_date DATE NOT NULL,
                from_location VARCHAR(255),
                to_location VARCHAR(255),
                purpose TEXT,
                km_distance NUMERIC(8,2),
                rate_per_km NUMERIC(6,4),
                total_amount NUMERIC(8,2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        print("  ✅ Created mileage_log table")
        
        # 6. Create indexes for performance
        print("6. Creating indexes...")
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON public.expenses(category_id)",
            "CREATE INDEX IF NOT EXISTS idx_expenses_vat_rate_id ON public.expenses(vat_rate_id)",
            "CREATE INDEX IF NOT EXISTS idx_expenses_expense_type ON public.expenses(expense_type)",
            "CREATE INDEX IF NOT EXISTS idx_invoices_vat_rate_id ON public.invoices(vat_rate_id)",
            "CREATE INDEX IF NOT EXISTS idx_eworker_periods_company_id ON public.eworker_periods(company_id)",
            "CREATE INDEX IF NOT EXISTS idx_mileage_log_company_id ON public.mileage_log(company_id)"
        ]
        
        for index_sql in indexes:
            try:
                cursor.execute(index_sql)
                print(f"  ✅ Created index")
            except Exception as e:
                print(f"  ⚠️ Index creation: {e}")
        
        # 7. Update existing records with default VAT rate
        print("7. Setting default VAT rates for existing records...")
        cursor.execute("""
            UPDATE public.expenses 
            SET vat_rate_id = (SELECT id FROM public.vat_rates WHERE rate_name = 'Standard' AND country = 'Ireland' LIMIT 1)
            WHERE vat_rate_id IS NULL;
        """)
        
        cursor.execute("""
            UPDATE public.invoices 
            SET vat_rate_id = (SELECT id FROM public.vat_rates WHERE rate_name = 'Standard' AND country = 'Ireland' LIMIT 1)
            WHERE vat_rate_id IS NULL;
        """)
        
        # 8. Create trigger to calculate deductible amount
        print("8. Creating deductible amount trigger...")
        cursor.execute("""
            CREATE OR REPLACE FUNCTION public.calculate_deductible_amount()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.deductible_amount := ROUND(NEW.amount * COALESCE(NEW.business_usage_percentage, 100) / 100, 2);
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        """)
        
        cursor.execute("""
            DROP TRIGGER IF EXISTS trigger_calculate_deductible_amount ON public.expenses;
            CREATE TRIGGER trigger_calculate_deductible_amount
                BEFORE INSERT OR UPDATE ON public.expenses
                FOR EACH ROW
                EXECUTE FUNCTION public.calculate_deductible_amount();
        """)
        
        conn.commit()
        print("✅ VAT system fix completed successfully!")
        
        # Test the fix
        cursor.execute("SELECT COUNT(*) FROM public.vat_rates")
        vat_count = cursor.fetchone()[0]
        print(f"🏷️  VAT rates available: {vat_count}")
        
        cursor.execute("SELECT COUNT(*) FROM public.expense_categories")
        category_count = cursor.fetchone()[0]
        print(f"📂 Expense categories available: {category_count}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ VAT fix failed: {e}")
        return False

if __name__ == "__main__":
    success = fix_vat_migration()
    if success:
        print("\n🎉 VAT system is now properly configured!")
    else:
        print("\n💥 VAT fix failed. Please check the errors above.")