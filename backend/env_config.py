"""
Environment Configuration Management for PSC Accounting API
Handles loading, validation, and secure management of environment variables.
"""

import os
import sys
from pathlib import Path
from typing import Optional, Dict, Any
from dotenv import load_dotenv
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EnvironmentConfig:
    """Centralized environment configuration management"""
    
    def __init__(self, env_file: Optional[str] = None):
        """
        Initialize environment configuration
        
        Args:
            env_file: Path to .env file (optional, defaults to backend/.env)
        """
        self.env_file = env_file or self._find_env_file()
        self.config = {}
        self.load_environment()
    
    def _find_env_file(self) -> str:
        """Find the .env file in the backend directory"""
        backend_dir = Path(__file__).parent
        env_path = backend_dir / '.env'
        return str(env_path)
    
    def load_environment(self) -> None:
        """Load environment variables from .env file and validate required variables"""
        try:
            # Load .env file if it exists
            if os.path.exists(self.env_file):
                load_dotenv(self.env_file)
                logger.info(f"✅ Loaded environment from: {self.env_file}")
            else:
                logger.warning(f"⚠️ No .env file found at: {self.env_file}")
                logger.info("Using system environment variables only")
            
            # Optionally load from AWS Secrets Manager (if configured)
            self._load_aws_secrets_into_env()

            # Load configuration values
            self._load_config_values()
            
            # Validate required environment variables
            self._validate_required_vars()
            
            # Log configuration summary (without sensitive data)
            self._log_config_summary()
            
        except Exception as e:
            logger.error(f"❌ Failed to load environment configuration: {e}")
            sys.exit(1)
    
    def _load_config_values(self) -> None:
        """Load all configuration values from environment variables"""
        
        # Application Configuration
        self.config.update({
            # Storage
            'STORAGE_MODE': self.get_env('STORAGE_MODE', 'local'),
            'UPLOAD_DIR': self.get_env('UPLOAD_DIR', 'uploads'),
            
            # API Configuration
            'API_HOST': self.get_env('API_HOST', '0.0.0.0'),
            'API_PORT': int(self.get_env('API_PORT', '8000')),
            
            # Environment
            'DEBUG': self.get_env('DEBUG', 'false').lower() == 'true',
            'ENVIRONMENT': self.get_env('ENVIRONMENT', 'development'),
            'LOG_LEVEL': self.get_env('LOG_LEVEL', 'INFO'),
            
            # Database Configuration
            'DB_HOST': self.get_env('DB_HOST'),
            'DB_PORT': int(self.get_env('DB_PORT', '5432')),
            'DB_NAME': self.get_env('DB_NAME'),
            'DB_USER': self.get_env('DB_USER'),
            'DB_PASSWORD': self.get_env('DB_PASSWORD'),
            'DB_SSL_MODE': self.get_env('DB_SSL_MODE', 'prefer'),
            'DB_MIN_CONNECTIONS': int(self.get_env('DB_MIN_CONNECTIONS', '1')),
            'DB_MAX_CONNECTIONS': int(self.get_env('DB_MAX_CONNECTIONS', '20')),
            'DB_ECHO': self.get_env('DB_ECHO', 'false').lower() == 'true',
            'DB_SCHEMA': self.get_env('DB_SCHEMA', 'public'),
            
            # Security
            'JWT_SECRET': self.get_env('JWT_SECRET'),
            'API_SECRET_KEY': self.get_env('API_SECRET_KEY'),
            'CORS_ORIGINS': self.get_env('CORS_ORIGINS', '*').split(','),
            
            # External Services (optional)
            'GOOGLE_APPLICATION_CREDENTIALS': self.get_env('GOOGLE_APPLICATION_CREDENTIALS'),
            'FIREBASE_PROJECT_ID': self.get_env('FIREBASE_PROJECT_ID'),
            'SMTP_HOST': self.get_env('SMTP_HOST'),
            'SMTP_PORT': int(self.get_env('SMTP_PORT', '587')) if self.get_env('SMTP_PORT') else None,
            'SMTP_USER': self.get_env('SMTP_USER'),
            'SMTP_PASSWORD': self.get_env('SMTP_PASSWORD'),
            'AWS_ACCESS_KEY_ID': self.get_env('AWS_ACCESS_KEY_ID'),
            'AWS_SECRET_ACCESS_KEY': self.get_env('AWS_SECRET_ACCESS_KEY'),
            'AWS_S3_BUCKET': self.get_env('AWS_S3_BUCKET'),
            'AWS_REGION': self.get_env('AWS_REGION', 'eu-west-1'),
            'AWS_SECRETS_MANAGER_SECRET_ID': self.get_env('AWS_SECRETS_MANAGER_SECRET_ID'),
        })

    def _load_aws_secrets_into_env(self) -> None:
        """If configured, fetch secrets from AWS Secrets Manager and inject into os.environ.

        Expects:
          - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (or an IAM role in env)
          - AWS_REGION (defaults to eu-west-1 if missing)
          - AWS_SECRETS_MANAGER_SECRET_ID (the Secret ARN or name)
        Secret value should be a JSON object with keys like DB_HOST, DB_PORT, DB_NAME, DB_USER,
        DB_PASSWORD, JWT_SECRET, API_SECRET_KEY, etc.
        """
        secret_id = os.getenv('AWS_SECRETS_MANAGER_SECRET_ID') or os.getenv('AWS_SECRET_ARN')
        if not secret_id:
            return
        try:
            # Import boto3 lazily to avoid hard dependency if not used
            import boto3
            from botocore.exceptions import BotoCoreError, ClientError

            region = os.getenv('AWS_REGION', 'eu-west-1')
            client = boto3.client('secretsmanager', region_name=region)
            resp = client.get_secret_value(SecretId=secret_id)
            secret_str = resp.get('SecretString')
            if not secret_str and 'SecretBinary' in resp:
                secret_str = resp['SecretBinary'].decode('utf-8')

            if not secret_str:
                logger.warning("AWS Secrets Manager returned empty secret value")
                return

            data = json.loads(secret_str)
            if not isinstance(data, dict):
                logger.warning("AWS secret is not a JSON object; skipping")
                return

            # Inject into process env if not already set
            for k, v in data.items():
                if k and v is not None and os.getenv(k) is None:
                    os.environ[k] = str(v)

            logger.info("🔐 Loaded configuration from AWS Secrets Manager")
        except Exception as e:
            logger.warning(f"⚠️ Could not load AWS Secrets Manager secret: {e}")
    
    def _validate_required_vars(self) -> None:
        """Validate that all required environment variables are set"""
        
        required_vars = [
            'DB_HOST',
            'DB_NAME', 
            'DB_USER',
            'DB_PASSWORD'
        ]
        
        # Additional requirements based on environment
        if self.config.get('ENVIRONMENT') == 'production':
            required_vars.extend([
                'JWT_SECRET',
                'API_SECRET_KEY'
            ])
        
        missing_vars = []
        for var in required_vars:
            if not self.config.get(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error(f"❌ Missing required environment variables: {missing_vars}")
            logger.error("Please check your .env file or set these environment variables")
            sys.exit(1)
    
    def _log_config_summary(self) -> None:
        """Log configuration summary (excluding sensitive information)"""
        
        safe_config = {}
        sensitive_keys = ['DB_PASSWORD', 'JWT_SECRET', 'API_SECRET_KEY', 'SMTP_PASSWORD', 
                         'AWS_SECRET_ACCESS_KEY', 'GOOGLE_APPLICATION_CREDENTIALS']
        
        for key, value in self.config.items():
            if key in sensitive_keys:
                safe_config[key] = '***MASKED***' if value else None
            else:
                safe_config[key] = value
        
        logger.info("📋 Configuration Summary:")
        logger.info(f"  Environment: {safe_config.get('ENVIRONMENT')}")
        logger.info(f"  Debug: {safe_config.get('DEBUG')}")
        logger.info(f"  Database: {safe_config.get('DB_HOST')}:{safe_config.get('DB_PORT')}/{safe_config.get('DB_NAME')}")
        logger.info(f"  Schema: {safe_config.get('DB_SCHEMA')}")
        logger.info(f"  Storage Mode: {safe_config.get('STORAGE_MODE')}")
        logger.info(f"  API: {safe_config.get('API_HOST')}:{safe_config.get('API_PORT')}")
    
    @staticmethod
    def get_env(key: str, default: Optional[str] = None) -> Optional[str]:
        """
        Get environment variable value
        
        Args:
            key: Environment variable name
            default: Default value if not found
            
        Returns:
            Environment variable value or default
        """
        return os.getenv(key, default)
    
    def get_config(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value
        
        Args:
            key: Configuration key
            default: Default value if not found
            
        Returns:
            Configuration value or default
        """
        return self.config.get(key, default)
    
    def get_database_url(self) -> str:
        """
        Generate database connection URL
        
        Returns:
            PostgreSQL connection URL
        """
        host = self.config['DB_HOST']
        port = self.config['DB_PORT']
        db_name = self.config['DB_NAME']
        user = self.config['DB_USER']
        password = self.config['DB_PASSWORD']
        ssl_mode = self.config['DB_SSL_MODE']
        
        return f"postgresql://{user}:{password}@{host}:{port}/{db_name}?sslmode={ssl_mode}"
    
    def is_development(self) -> bool:
        """Check if running in development mode"""
        return self.config.get('ENVIRONMENT') == 'development'
    
    def is_production(self) -> bool:
        """Check if running in production mode"""
        return self.config.get('ENVIRONMENT') == 'production'
    
    def validate_database_connection(self) -> bool:
        """
        Validate database connection settings
        
        Returns:
            True if valid, False otherwise
        """
        required_db_vars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
        return all(self.config.get(var) for var in required_db_vars)


# Global configuration instance
env_config = EnvironmentConfig()

# Convenience functions for backward compatibility
def get_env(key: str, default: Optional[str] = None) -> Optional[str]:
    """Get environment variable (backward compatibility)"""
    return env_config.get_env(key, default)

def get_config(key: str, default: Any = None) -> Any:
    """Get configuration value (backward compatibility)"""
    return env_config.get_config(key, default)