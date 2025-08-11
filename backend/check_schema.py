#!/usr/bin/env python3
"""
Schema Checker - Check current database structure
"""

import psycopg2
from env_config import env_config

def check_schema():
    """Check current database structure"""
    
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
        
        # Check tables in public schema
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name
        """)
        
        tables = cursor.fetchall()
        print(f"📋 Tables in public schema: {[table[0] for table in tables]}")
        
        # Check companies table structure
        if any('companies' in table for table in tables):
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_name = 'companies' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            
            columns = cursor.fetchall()
            print(f"\n🏢 Companies table structure:")
            for col in columns:
                print(f"  {col[0]}: {col[1]} ({'NULL' if col[2] == 'YES' else 'NOT NULL'})")
        
        # Check expenses table structure if it exists
        if any('expenses' in table for table in tables):
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_name = 'expenses' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            
            columns = cursor.fetchall()
            print(f"\n💰 Expenses table structure:")
            for col in columns:
                print(f"  {col[0]}: {col[1]} ({'NULL' if col[2] == 'YES' else 'NOT NULL'})")
        
        # Check invoices table structure if it exists
        if any('invoices' in table for table in tables):
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_name = 'invoices' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            
            columns = cursor.fetchall()
            print(f"\n📄 Invoices table structure:")
            for col in columns:
                print(f"  {col[0]}: {col[1]} ({'NULL' if col[2] == 'YES' else 'NOT NULL'})")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Schema check failed: {e}")
        return False

if __name__ == "__main__":
    check_schema()