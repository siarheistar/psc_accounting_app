#!/usr/bin/env python3
"""
Attachment Migration Script
Migrates PDF documents from database storage to new local attachment system
"""

import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

# Add the backend directory to Python path
sys.path.insert(0, str(Path(__file__).parent))

from database import execute_query, initialize_db_pool, close_db_pool
from attachment_manager import AttachmentManager

def run_sql_migration():
    """Run the SQL migration script to create tables"""
    
    print("🔄 Running SQL migration script...")
    
    sql_file = Path(__file__).parent / "migration_attachments.sql"
    
    if not sql_file.exists():
        print(f"❌ SQL migration file not found: {sql_file}")
        return False
    
    try:
        with open(sql_file, 'r') as f:
            sql_content = f.read()
        
        # Split by semicolon and execute each statement
        statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
        
        for statement in statements:
            if statement and not statement.startswith('--'):
                try:
                    execute_query(statement, fetch=False)
                except Exception as e:
                    print(f"⚠️ Warning executing SQL: {e}")
                    # Continue with other statements
        
        print("✅ SQL migration completed")
        return True
        
    except Exception as e:
        print(f"❌ Failed to run SQL migration: {e}")
        return False

def migrate_documents(company_id=None, dry_run=False):
    """Migrate documents from database to local storage"""
    
    print(f"🔄 Starting document migration (dry_run={dry_run})...")
    
    if company_id:
        print(f"📊 Migrating documents for company {company_id}")
    else:
        print("📊 Migrating documents for all companies")
    
    # Initialize attachment manager
    attachment_manager = AttachmentManager()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No files will be moved")
        return analyze_migration(company_id)
    
    # Run the actual migration
    try:
        migration_stats = attachment_manager.migrate_from_database_storage(company_id)
        
        print(f"\\n📊 Migration Results:")
        print(f"   Total files processed: {migration_stats['total_files']}")
        print(f"   Successfully migrated: {migration_stats['migrated']}")
        print(f"   Failed migrations: {migration_stats['failed']}")
        
        if migration_stats['errors']:
            print(f"\\n❌ Errors:")
            for error in migration_stats['errors']:
                print(f"   - {error}")
        
        if migration_stats['migrated'] > 0:
            print(f"\\n✅ Migration completed successfully!")
            
            # Clean up empty directories
            attachment_manager.cleanup_empty_directories()
            
            # Show final statistics
            stats = attachment_manager.get_attachment_stats(company_id)
            print(f"\\n📈 Final Statistics:")
            print(f"   Total attachments: {stats['total_attachments']}")
            print(f"   Total size: {stats['total_size_human']}")
            print(f"   Categories: {', '.join(stats['by_category'].keys())}")
        
        return migration_stats
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return None

def analyze_migration(company_id=None):
    """Analyze what would be migrated without actually doing it"""
    
    print("🔍 Analyzing documents for migration...")
    
    # Query for database-stored documents
    query = """
        SELECT 
            entity_type,
            company_id,
            COUNT(*) as count,
            SUM(file_size) as total_size,
            AVG(file_size) as avg_size
        FROM document_attachments 
        WHERE storage_type = 'database'
    """
    
    params = []
    if company_id is not None:
        query += " AND company_id = %s"
        params.append(company_id)
    
    query += " GROUP BY entity_type, company_id ORDER BY company_id, entity_type"
    
    results = execute_query(query, params, fetch=True)
    result_list = results if isinstance(results, list) else [results] if results else []
    
    if not result_list:
        print("✅ No documents found that need migration")
        return {"total_files": 0, "total_size": 0}
    
    print(f"\\n📊 Documents to migrate:")
    print(f"{'Company':<10} {'Entity Type':<15} {'Count':<8} {'Total Size':<12} {'Avg Size':<10}")
    print("-" * 65)
    
    total_files = 0
    total_size = 0
    
    for row in result_list:
        if isinstance(row, tuple):
            entity_type, comp_id, count, size, avg_size = row
        else:
            entity_type = row['entity_type']
            comp_id = row['company_id']
            count = row['count']
            size = row['total_size']
            avg_size = row['avg_size']
        
        total_files += count
        total_size += size
        
        size_mb = size / (1024 * 1024) if size else 0
        avg_mb = avg_size / (1024 * 1024) if avg_size else 0
        
        print(f"{comp_id:<10} {entity_type:<15} {count:<8} {size_mb:>8.1f} MB {avg_mb:>8.1f} MB")
    
    print("-" * 65)
    print(f"{'TOTAL':<26} {total_files:<8} {total_size/(1024*1024):>8.1f} MB")
    
    return {"total_files": total_files, "total_size": total_size}

def create_directory_structure():
    """Create the attachment directory structure"""
    
    print("📁 Creating attachment directory structure...")
    
    try:
        attachment_manager = AttachmentManager()
        print("✅ Directory structure created")
        
        # Show the structure
        attachments_dir = attachment_manager.attachments_dir
        print(f"\\n📂 Attachment directory: {attachments_dir.absolute()}")
        
        if attachments_dir.exists():
            for item in attachments_dir.iterdir():
                if item.is_dir():
                    print(f"   📁 {item.name}/")
        
        return True
        
    except Exception as e:
        print(f"❌ Failed to create directory structure: {e}")
        return False

def cleanup_old_data(confirm=False):
    """Clean up old document_attachments data that has been migrated"""
    
    if not confirm:
        print("⚠️ This will delete old document_attachments records marked as 'migrated'")
        print("   Use --confirm to actually perform the cleanup")
        return
    
    print("🗑️ Cleaning up migrated document_attachments records...")
    
    try:
        # Count records to be deleted
        count_query = "SELECT COUNT(*) FROM document_attachments WHERE storage_type = 'migrated'"
        result = execute_query(count_query, fetch=True)
        count = result[0] if isinstance(result, tuple) else result['count']
        
        if count == 0:
            print("✅ No migrated records found to clean up")
            return
        
        print(f"🗑️ Deleting {count} migrated document_attachments records...")
        
        # Delete migrated records
        delete_query = "DELETE FROM document_attachments WHERE storage_type = 'migrated'"
        execute_query(delete_query, fetch=False)
        
        print(f"✅ Cleaned up {count} old records")
        
    except Exception as e:
        print(f"❌ Cleanup failed: {e}")

def show_statistics(company_id=None):
    """Show current attachment statistics"""
    
    print("📊 Current attachment statistics...")
    
    try:
        attachment_manager = AttachmentManager()
        stats = attachment_manager.get_attachment_stats(company_id)
        
        print(f"\\n📈 Statistics" + (f" for company {company_id}" if company_id else " (all companies)") + ":")
        print(f"   Total attachments: {stats['total_attachments']:,}")
        print(f"   Total size: {stats['total_size_human']}")
        
        if stats.get('disk_usage_human'):
            print(f"   Disk usage: {stats['disk_usage_human']}")
        
        if stats['by_category']:
            print(f"\\n📂 By category:")
            for category, cat_stats in stats['by_category'].items():
                print(f"   {category:<12}: {cat_stats['count']:>4} files, {cat_stats['total_size_human']:>8}")
        
        print(f"\\n🔧 Supported file types:")
        types_per_line = 8
        types = stats['supported_types']
        for i in range(0, len(types), types_per_line):
            line_types = types[i:i+types_per_line]
            print(f"   {', '.join(line_types)}")
        
    except Exception as e:
        print(f"❌ Failed to get statistics: {e}")

def main():
    """Main migration script"""
    
    parser = argparse.ArgumentParser(description="PSC Accounting Attachment Migration Tool")
    parser.add_argument('--action', choices=['migrate', 'analyze', 'setup', 'cleanup', 'stats'], 
                       default='analyze', help='Action to perform')
    parser.add_argument('--company-id', type=int, help='Migrate only for specific company')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be migrated without doing it')
    parser.add_argument('--confirm', action='store_true', help='Confirm destructive operations')
    
    args = parser.parse_args()
    
    print("🚀 PSC Accounting Attachment Migration Tool")
    print(f"   Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   Action: {args.action}")
    
    # Initialize database connection
    if not initialize_db_pool():
        print("❌ Failed to connect to database")
        return 1
    
    try:
        if args.action == 'setup':
            # Create directory structure and run SQL migration
            success = run_sql_migration() and create_directory_structure()
            return 0 if success else 1
            
        elif args.action == 'analyze':
            # Analyze what would be migrated
            analyze_migration(args.company_id)
            return 0
            
        elif args.action == 'migrate':
            # Run the actual migration
            result = migrate_documents(args.company_id, args.dry_run)
            return 0 if result else 1
            
        elif args.action == 'cleanup':
            # Clean up old data
            cleanup_old_data(args.confirm)
            return 0
            
        elif args.action == 'stats':
            # Show statistics
            show_statistics(args.company_id)
            return 0
            
        else:
            print(f"❌ Unknown action: {args.action}")
            return 1
            
    except KeyboardInterrupt:
        print("\\n⏹️ Migration interrupted by user")
        return 1
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return 1
        
    finally:
        close_db_pool()

if __name__ == "__main__":
    exit(main())
