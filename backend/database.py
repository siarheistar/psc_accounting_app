import os
import psycopg2
from psycopg2 import pool
from dotenv import load_dotenv
import logging
from env_config import env_config
from schema_manager import schema_manager, convert_legacy_query

# Configure logging
logger = logging.getLogger(__name__)

# Load environment variables (backward compatibility)
load_dotenv()

# Database configuration using new environment config system
DB_CONFIG = {
    'host': env_config.get_config('DB_HOST'),
    'port': int(env_config.get_config('DB_PORT', 5432)),
    'database': env_config.get_config('DB_NAME'),
    'user': env_config.get_config('DB_USER'),
    'password': env_config.get_config('DB_PASSWORD'),
    'sslmode': env_config.get_config('DB_SSL_MODE', 'prefer')
}

# Create connection pool
connection_pool = None

def initialize_db_pool():
    """Initialize the database connection pool"""
    global connection_pool
    try:
        # Validate database configuration before connecting
        if not env_config.validate_database_connection():
            logger.error("❌ [Database] Invalid database configuration")
            return False
            
        connection_pool = psycopg2.pool.SimpleConnectionPool(
            minconn=env_config.get_config('DB_MIN_CONNECTIONS', 1),
            maxconn=env_config.get_config('DB_MAX_CONNECTIONS', 10),
            **DB_CONFIG
        )
        logger.info(f"🗄️ [Database] Connected to PostgreSQL at {DB_CONFIG['host']}:{DB_CONFIG['port']}")
        logger.info(f"📊 [Database] Database: {DB_CONFIG['database']}")
        logger.info(f"📋 [Database] Schema: {schema_manager.get_schema()}")
        logger.info(f"🔐 [Database] SSL Mode: {DB_CONFIG.get('sslmode', 'prefer')}")
        return True
    except Exception as e:
        logger.error(f"❌ [Database] Failed to connect: {e}")
        logger.error(f"❌ [Database] Configuration: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
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
    """Execute a database query with automatic schema conversion"""
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if not conn:
            raise Exception("Failed to get database connection")
        
        # Convert legacy queries with hardcoded 'public.' schema
        schema_aware_query = convert_legacy_query(query)
        
        cursor = conn.cursor()
        cursor.execute(schema_aware_query, params)
        
        if fetch:
            if query.strip().upper().startswith('SELECT'):
                # Get column names
                columns = [desc[0] for desc in cursor.description]
                # Fetch all rows and convert to list of dictionaries
                rows = cursor.fetchall()
                result = [dict(zip(columns, row)) for row in rows]
                print(f"🔍 [Database] Query executed: {schema_aware_query[:50]}... | Found {len(result)} rows")
                return result
            else:
                # INSERT, UPDATE, DELETE with RETURNING - need to commit AND fetch result
                result = cursor.fetchone()
                conn.commit()  # CRITICAL: Commit the transaction!
                print(f"✅ [Database] Query executed: {schema_aware_query[:50]}... | Committed to database")
                print(f"🔍 [Database] Raw result: {result}, type: {type(result)}")
                return result
        else:
            conn.commit()
            print(f"✅ [Database] Query executed: {schema_aware_query[:50]}... | Committed to database")
            return cursor.rowcount
            
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"❌ [Database] Query failed: {schema_aware_query[:50]}...")
        print(f"❌ [Database] Error details: {e}")
        print(f"❌ [Database] Error type: {type(e)}")
        raise e
    finally:
        if cursor:
            cursor.close()
        if conn:
            return_db_connection(conn)