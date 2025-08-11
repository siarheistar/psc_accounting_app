#!/usr/bin/env python3
"""
Recreate VAT Tables - Recreate VAT tables with correct data types
"""

import psycopg2
from env_config import env_config

def recreate_vat_tables():
    """Recreate VAT tables with correct data types"""
    
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
        
        print("🗑️ Dropping existing VAT tables...")
        
        # Drop existing tables (they have wrong data types)
        cursor.execute("DROP TABLE IF EXISTS public.mileage_log CASCADE")
        cursor.execute("DROP TABLE IF EXISTS public.eworker_periods CASCADE")  
        cursor.execute("DROP TABLE IF EXISTS public.expense_categories CASCADE")
        cursor.execute("DROP TABLE IF EXISTS public.business_usage_options CASCADE")
        cursor.execute("DROP TABLE IF EXISTS public.vat_rates CASCADE")
        
        print("🏗️ Creating VAT tables with correct data types...")
        
        # 1. Create VAT Rates Table (with INTEGER primary key)
        cursor.execute("""
            CREATE TABLE public.vat_rates (
                id SERIAL PRIMARY KEY,
                country VARCHAR(64) NOT NULL DEFAULT 'Ireland',
                rate_name VARCHAR(50) NOT NULL,
                rate_percentage NUMERIC(5,2) NOT NULL,
                description TEXT,
                is_active BOOLEAN DEFAULT TRUE,
                effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
                effective_until DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        print("✅ Created vat_rates table")
        
        # 2. Create Expense Categories Table
        cursor.execute("""
            CREATE TABLE public.expense_categories (
                id SERIAL PRIMARY KEY,
                category_name VARCHAR(100) NOT NULL,
                category_type VARCHAR(50) NOT NULL,
                default_vat_rate_id INTEGER REFERENCES public.vat_rates(id),
                supports_business_usage BOOLEAN DEFAULT FALSE,
                default_business_usage NUMERIC(5,2) DEFAULT 100.00,
                requires_receipt BOOLEAN DEFAULT TRUE,
                description TEXT,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        print("✅ Created expense_categories table")
        
        # 3. Create Business Usage Options Table
        cursor.execute("""
            CREATE TABLE public.business_usage_options (
                id SERIAL PRIMARY KEY,
                percentage NUMERIC(5,2) NOT NULL,
                label VARCHAR(20) NOT NULL,
                description TEXT,
                is_default BOOLEAN DEFAULT FALSE
            );
        """)
        print("✅ Created business_usage_options table")
        
        # 4. Create E-Worker Periods Table
        cursor.execute("""
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
        print("✅ Created eworker_periods table")
        
        # 5. Create Mileage Log Table
        cursor.execute("""
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
        print("✅ Created mileage_log table")
        
        print("📊 Inserting base data...")
        
        # Insert VAT rates
        cursor.execute("""
            INSERT INTO public.vat_rates (country, rate_name, rate_percentage, description) VALUES
            ('Ireland', 'Standard', 23.00, 'Standard VAT rate for most goods and services'),
            ('Ireland', 'Reduced', 13.50, 'Reduced rate for certain goods and services'),
            ('Ireland', 'Second Reduced', 9.00, 'Second reduced rate for tourism, newspapers, etc.'),
            ('Ireland', 'Zero', 0.00, 'Zero rate for exports, certain foods, books, etc.'),
            ('Ireland', 'Exempt', 0.00, 'Exempt supplies (education, health, insurance, etc.)'),
            ('Ireland', 'Home Office', 0.00, 'Home office usage - non-deductible VAT'),
            ('EU', 'Reverse Charge', 0.00, 'EU B2B transactions - reverse charge mechanism'),
            ('Non-EU', 'Import VAT', 21.00, 'Import VAT on goods from non-EU countries');
        """)
        print("✅ Inserted VAT rates")
        
        # Insert expense categories
        cursor.execute("""
            INSERT INTO public.expense_categories (category_name, category_type, supports_business_usage, default_business_usage, requires_receipt, description) VALUES
            ('Office Supplies', 'general', FALSE, 100.00, TRUE, 'Stationery, printer supplies, etc.'),
            ('Professional Services', 'general', FALSE, 100.00, TRUE, 'Legal, accounting, consultancy fees'),
            ('Software & Subscriptions', 'general', FALSE, 100.00, TRUE, 'Business software licenses and subscriptions'),
            ('Marketing & Advertising', 'general', FALSE, 100.00, TRUE, 'Website, ads, promotional materials'),
            ('Training & Development', 'general', FALSE, 100.00, TRUE, 'Courses, seminars, professional development'),
            ('Internet & Broadband', 'general', TRUE, 100.00, TRUE, 'Internet connection costs'),
            ('Mobile Phone', 'general', TRUE, 75.00, TRUE, 'Mobile phone bills and costs'),
            ('Landline Phone', 'general', TRUE, 100.00, TRUE, 'Landline telephone costs'),
            ('Utilities - Electricity', 'general', TRUE, 25.00, TRUE, 'Home office electricity usage'),
            ('Utilities - Gas/Heating', 'general', TRUE, 25.00, TRUE, 'Home office heating costs'),
            ('Home Office Equipment', 'general', TRUE, 100.00, TRUE, 'Desk, chair, computer equipment for home office'),
            ('Rent - Home Office', 'general', TRUE, 10.00, TRUE, 'Portion of rent for home office use'),
            ('E-Worker Rate', 'eworker', FALSE, 100.00, FALSE, 'Daily/hourly rate for e-worker services'),
            ('E-Worker Expenses', 'eworker', FALSE, 100.00, TRUE, 'Reimbursable expenses for e-worker'),
            ('Business Mileage', 'mileage', FALSE, 100.00, FALSE, 'Mileage for business trips'),
            ('Client Visit Mileage', 'mileage', FALSE, 100.00, FALSE, 'Mileage for client visits'),
            ('Business Meals', 'subsistence', FALSE, 100.00, TRUE, 'Meals during business travel'),
            ('Accommodation', 'subsistence', FALSE, 100.00, TRUE, 'Hotel and accommodation costs'),
            ('Travel Expenses', 'subsistence', FALSE, 100.00, TRUE, 'Transport costs for business travel');
        """)
        print("✅ Inserted expense categories")
        
        # Insert business usage options
        cursor.execute("""
            INSERT INTO public.business_usage_options (percentage, label, description, is_default) VALUES
            (100.00, '100%', 'Full business use', TRUE),
            (75.00, '75%', 'Mostly business use', FALSE),
            (50.00, '50%', 'Half business use', FALSE),
            (25.00, '25%', 'Limited business use', FALSE),
            (10.00, '10%', 'Minimal business use', FALSE),
            (0.00, '0%', 'Personal use only', FALSE);
        """)
        print("✅ Inserted business usage options")
        
        conn.commit()
        print("✅ VAT tables recreated successfully!")
        
        # Test the tables
        cursor.execute("SELECT COUNT(*) FROM public.vat_rates")
        vat_count = cursor.fetchone()[0]
        print(f"🏷️  VAT rates: {vat_count}")
        
        cursor.execute("SELECT COUNT(*) FROM public.expense_categories")
        category_count = cursor.fetchone()[0]
        print(f"📂 Expense categories: {category_count}")
        
        cursor.execute("SELECT COUNT(*) FROM public.business_usage_options")
        usage_count = cursor.fetchone()[0]
        print(f"📊 Business usage options: {usage_count}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ VAT table recreation failed: {e}")
        return False

if __name__ == "__main__":
    success = recreate_vat_tables()
    if success:
        print("\n🎉 VAT tables are now properly configured!")
    else:
        print("\n💥 VAT table recreation failed. Please check the errors above.")