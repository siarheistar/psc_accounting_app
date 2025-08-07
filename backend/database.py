import os
import psycopg2
from psycopg2 import pool
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT', 5432),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD')
}

# Create connection pool
connection_pool = None

def initialize_db_pool():
    """Initialize the database connection pool"""
    global connection_pool
    try:
        connection_pool = psycopg2.pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            **DB_CONFIG
        )
        print(f"🗄️ [Database] Connected to PostgreSQL at {DB_CONFIG['host']}:{DB_CONFIG['port']}")
        print(f"📊 [Database] Database: {DB_CONFIG['database']}")
        return True
    except Exception as e:
        print(f"❌ [Database] Failed to connect: {e}")
        return False

def get_db_connection():
    """Get a database connection from the pool"""
    global connection_pool
    if connection_pool:
        return connection_pool.getconn()
    return None

def return_db_connection(conn):
    """Return a database connection to the pool"""
    global connection_pool
    if connection_pool:
        connection_pool.putconn(conn)

def close_db_pool():
    """Close all database connections"""
    global connection_pool
    if connection_pool:
        connection_pool.closeall()
        print("🗄️ [Database] Connection pool closed")

# Database operations
def execute_query(query, params=None, fetch=False):
    """Execute a database query"""
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if not conn:
            raise Exception("Failed to get database connection")
        
        cursor = conn.cursor()
        cursor.execute(query, params)
        
        if fetch:
            if query.strip().upper().startswith('SELECT'):
                # Get column names
                columns = [desc[0] for desc in cursor.description]
                # Fetch all rows and convert to list of dictionaries
                rows = cursor.fetchall()
                result = [dict(zip(columns, row)) for row in rows]
                print(f"🔍 [Database] Query executed: {query[:50]}... | Found {len(result)} rows")
                return result
            else:
                # INSERT, UPDATE, DELETE with RETURNING - need to commit AND fetch result
                result = cursor.fetchone()
                conn.commit()  # CRITICAL: Commit the transaction!
                print(f"✅ [Database] Query executed: {query[:50]}... | Committed to database")
                print(f"🔍 [Database] Raw result: {result}, type: {type(result)}")
                return result
        else:
            conn.commit()
            print(f"✅ [Database] Query executed: {query[:50]}... | Committed to database")
            return cursor.rowcount
            
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"❌ [Database] Query failed: {query[:50]}...")
        print(f"❌ [Database] Error details: {e}")
        print(f"❌ [Database] Error type: {type(e)}")
        raise e
    finally:
        if cursor:
            cursor.close()
        if conn:
            return_db_connection(conn)