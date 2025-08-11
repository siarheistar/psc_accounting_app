"""
Schema Management Module for PSC Accounting API
Provides centralized schema configuration and query building for database operations.
"""

from env_config import env_config
import logging
from typing import Dict, List, Optional

# Configure logging
logger = logging.getLogger(__name__)

class SchemaManager:
    """Manages database schema configuration and provides schema-agnostic query building"""
    
    def __init__(self):
        self.schema = env_config.get_config('DB_SCHEMA', 'public')
        self._table_cache = {}
        logger.info(f"📊 Schema Manager initialized with schema: {self.schema}")
    
    def get_schema(self) -> str:
        """Get the current database schema"""
        return self.schema
    
    def get_table_name(self, table_name: str) -> str:
        """
        Get the fully qualified table name with schema prefix
        
        Args:
            table_name: The table name without schema (e.g., 'companies')
            
        Returns:
            Fully qualified table name (e.g., 'public.companies' or 'prod.companies')
        """
        if table_name in self._table_cache:
            return self._table_cache[table_name]
        
        qualified_name = f"{self.schema}.{table_name}"
        self._table_cache[table_name] = qualified_name
        return qualified_name
    
    def build_query(self, query_template: str, **kwargs) -> str:
        """
        Build a query by replacing table name placeholders with schema-qualified names
        
        Args:
            query_template: SQL query with {table_name} placeholders
            **kwargs: Additional parameters for string formatting
            
        Returns:
            SQL query with schema-qualified table names
            
        Example:
            query_template = "SELECT * FROM {companies} WHERE id = %s"
            Returns: "SELECT * FROM public.companies WHERE id = %s"
        """
        # Replace table name placeholders with schema-qualified names
        formatted_query = query_template
        
        # Common table names in the PSC Accounting system
        table_names = [
            'companies', 'users', 'invoices', 'expenses', 'payroll', 
            'bank_statements', 'employees', 'attachments', 'documents'
        ]
        
        for table in table_names:
            placeholder = f"{{{table}}}"
            if placeholder in formatted_query:
                formatted_query = formatted_query.replace(
                    placeholder, 
                    self.get_table_name(table)
                )
        
        # Apply any additional formatting parameters
        if kwargs:
            formatted_query = formatted_query.format(**kwargs)
        
        return formatted_query
    
    def convert_legacy_query(self, query: str) -> str:
        """
        Convert a legacy query with hardcoded 'public.' schema to use configured schema
        
        Args:
            query: SQL query with hardcoded 'public.' references
            
        Returns:
            SQL query with configured schema
            
        Example:
            Input: "SELECT * FROM public.companies WHERE ..."
            Output: "SELECT * FROM prod.companies WHERE ..." (if schema is 'prod')
        """
        if self.schema == 'public':
            # If using public schema, no conversion needed
            return query
        
        # Replace all occurrences of 'public.' with the configured schema
        converted_query = query.replace('public.', f'{self.schema}.')
        
        # Log the conversion for debugging
        if 'public.' in query:
            logger.debug(f"📊 Schema conversion: public → {self.schema}")
            logger.debug(f"   Original: {query[:100]}...")
            logger.debug(f"   Converted: {converted_query[:100]}...")
        
        return converted_query
    
    def get_schema_info(self) -> Dict[str, str]:
        """
        Get information about the current schema configuration
        
        Returns:
            Dictionary with schema configuration details
        """
        return {
            'current_schema': self.schema,
            'environment': env_config.get_config('ENVIRONMENT', 'development'),
            'database': env_config.get_config('DB_NAME'),
            'schema_source': 'DB_SCHEMA environment variable',
            'table_cache_size': len(self._table_cache),
            'cached_tables': list(self._table_cache.keys())
        }
    
    def validate_schema_name(self, schema_name: str) -> bool:
        """
        Validate that a schema name is safe to use (prevents SQL injection)
        
        Args:
            schema_name: Schema name to validate
            
        Returns:
            True if schema name is valid, False otherwise
        """
        # Schema names should only contain alphanumeric characters and underscores
        import re
        pattern = r'^[a-zA-Z][a-zA-Z0-9_]*$'
        return bool(re.match(pattern, schema_name))
    
    def create_schema_if_not_exists(self) -> str:
        """
        Generate SQL to create the configured schema if it doesn't exist
        
        Returns:
            SQL statement to create the schema
        """
        if not self.validate_schema_name(self.schema):
            raise ValueError(f"Invalid schema name: {self.schema}")
        
        return f"CREATE SCHEMA IF NOT EXISTS {self.schema};"
    
    def get_environment_schema_mappings(self) -> Dict[str, str]:
        """
        Get recommended schema mappings for different environments
        
        Returns:
            Dictionary mapping environments to recommended schema names
        """
        return {
            'development': 'public',
            'testing': 'test',
            'staging': 'staging', 
            'production': 'prod',
            'demo': 'demo'
        }
    
    def suggest_schema_for_environment(self, environment: str) -> str:
        """
        Suggest an appropriate schema name for a given environment
        
        Args:
            environment: Environment name (development, staging, production, etc.)
            
        Returns:
            Recommended schema name for the environment
        """
        mappings = self.get_environment_schema_mappings()
        return mappings.get(environment.lower(), 'public')


# Global schema manager instance
schema_manager = SchemaManager()

# Convenience functions for backward compatibility
def get_schema() -> str:
    """Get the current database schema"""
    return schema_manager.get_schema()

def get_table_name(table_name: str) -> str:
    """Get fully qualified table name with schema prefix"""
    return schema_manager.get_table_name(table_name)

def build_query(query_template: str, **kwargs) -> str:
    """Build query with schema-qualified table names"""
    return schema_manager.build_query(query_template, **kwargs)

def convert_legacy_query(query: str) -> str:
    """Convert legacy query with hardcoded public schema"""
    return schema_manager.convert_legacy_query(query)

# Table name constants for easy access
class Tables:
    """Constants for commonly used table names (schema-qualified)"""
    COMPANIES = schema_manager.get_table_name('companies')
    USERS = schema_manager.get_table_name('users') 
    INVOICES = schema_manager.get_table_name('invoices')
    EXPENSES = schema_manager.get_table_name('expenses')
    PAYROLL = schema_manager.get_table_name('payroll')
    BANK_STATEMENTS = schema_manager.get_table_name('bank_statements')
    EMPLOYEES = schema_manager.get_table_name('employees')
    ATTACHMENTS = schema_manager.get_table_name('attachments')
    DOCUMENTS = schema_manager.get_table_name('documents')