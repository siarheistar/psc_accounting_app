#!/bin/bash

# PSC Accounting - Attachment System Setup Script
# This script helps set up the new attachment management system

echo "🚀 PSC Accounting - Attachment System Setup"
echo "============================================="

# Check if we're in the backend directory
if [ ! -f "main.py" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is required but not installed"
    exit 1
fi

# Check if database connection works
echo "🔍 Checking database connection..."
python3 -c "
from database import initialize_db_pool, close_db_pool
if initialize_db_pool():
    print('✅ Database connection successful')
    close_db_pool()
else:
    print('❌ Database connection failed')
    exit(1)
" || exit 1

# Function to run migration step
run_migration_step() {
    local step=$1
    local description=$2
    
    echo ""
    echo "📋 Step $step: $description"
    echo "----------------------------------------"
    
    case $step in
        1)
            echo "Creating attachment directory structure and database tables..."
            python3 migrate_attachments.py --action setup
            ;;
        2)
            echo "Analyzing existing documents for migration..."
            python3 migrate_attachments.py --action analyze
            ;;
        3)
            echo "Migrating documents to new system..."
            read -p "Continue with migration? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                python3 migrate_attachments.py --action migrate
            else
                echo "Migration skipped."
            fi
            ;;
        4)
            echo "Showing final statistics..."
            python3 migrate_attachments.py --action stats
            ;;
    esac
}

# Main setup process
echo ""
echo "🔧 Setting up attachment management system..."
echo ""

# Step 1: Setup
run_migration_step 1 "Database Setup"

# Step 2: Analysis
run_migration_step 2 "Document Analysis"

# Step 3: Migration
echo ""
echo "⚠️  WARNING: The next step will migrate your PDF documents to the new system."
echo "   This process is safe but makes changes to your database."
echo "   Make sure you have a backup before proceeding."
echo ""
read -p "Do you want to proceed with the migration? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_migration_step 3 "Document Migration"
    run_migration_step 4 "Final Statistics"
    
    echo ""
    echo "✅ Migration completed successfully!"
    echo ""
    echo "📚 Next steps:"
    echo "1. Update your frontend code to use the new /attachments/* endpoints"
    echo "2. Test file uploads with different file types"
    echo "3. Review the README_ATTACHMENTS.md for detailed documentation"
    echo "4. Consider cleaning up old data after verifying the migration:"
    echo "   python3 migrate_attachments.py --action cleanup --confirm"
    echo ""
    echo "🔗 New attachment endpoints are now available:"
    echo "   POST   /attachments/upload"
    echo "   GET    /attachments/download/{id}"
    echo "   GET    /attachments/{entity_type}/{entity_id}"
    echo "   DELETE /attachments/{id}"
    echo "   GET    /attachments/stats"
    echo ""
    echo "🔄 Legacy /documents/* endpoints are still available for backward compatibility"
    
else
    echo "Migration cancelled. You can run this script again when ready."
    echo ""
    echo "To run individual migration steps manually:"
    echo "  python3 migrate_attachments.py --action setup"
    echo "  python3 migrate_attachments.py --action analyze"
    echo "  python3 migrate_attachments.py --action migrate"
    echo "  python3 migrate_attachments.py --action stats"
fi

echo ""
echo "📖 For detailed information, see README_ATTACHMENTS.md"
echo "🎯 Setup complete!"
