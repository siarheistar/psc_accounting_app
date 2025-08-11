#!/usr/bin/env python3
"""
VAT Migration Runner
Runs the VAT enhancement migration script
"""

import psycopg2
from env_config import env_config

def run_migration():
    """Run the VAT enhancement migration"""
    
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
        
        # Read the migration script
        with open('../dbscripts/add_vat_enhancements_public.sql', 'r') as f:
            migration_script = f.read()
        
        print("📋 Executing VAT enhancement migration...")
        
        # Execute the migration
        cursor.execute(migration_script)
        conn.commit()
        
        print("✅ VAT enhancement migration completed successfully!")
        
        # Test the migration by checking if tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('vat_rates', 'expense_categories', 'business_usage_options')
        """)
        
        tables = cursor.fetchall()
        print(f"📊 Created tables: {[table[0] for table in tables]}")
        
        # Check VAT rates data
        cursor.execute("SELECT COUNT(*) FROM public.vat_rates")
        vat_count = cursor.fetchone()[0]
        print(f"🏷️  VAT rates loaded: {vat_count}")
        
        # Check expense categories data
        cursor.execute("SELECT COUNT(*) FROM public.expense_categories")
        category_count = cursor.fetchone()[0]
        print(f"📂 Expense categories loaded: {category_count}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

if __name__ == "__main__":
    success = run_migration()
    if success:
        print("\n🎉 VAT system is ready!")
    else:
        print("\n💥 Migration failed. Please check the errors above.")