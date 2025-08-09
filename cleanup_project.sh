#!/bin/bash

# PSC Accounting App - Project Cleanup Script
# This script removes obsolete, unused, and temporary files from the project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 PSC Accounting App - Project Cleanup Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to log actions
log_action() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to safely remove files/directories
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        echo -e "${YELLOW}Removing: $description${NC}"
        echo "  Path: $path"
        rm -rf "$path"
        if [ $? -eq 0 ]; then
            log_action "Removed: $description"
        else
            log_error "Failed to remove: $description"
        fi
    else
        echo -e "${BLUE}Not found (already clean): $description${NC}"
    fi
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ]; then
    log_error "This script must be run from the root of the PSC Accounting App project"
    exit 1
fi

echo -e "${BLUE}🔍 Analyzing project structure...${NC}"
echo ""

# 1. Remove build artifacts and cache directories
echo -e "${BLUE}1. Cleaning build artifacts and cache directories...${NC}"
safe_remove "build/" "Flutter build directory"
safe_remove ".dart_tool/build/" "Dart tool build cache"
safe_remove ".flutter-plugins" "Flutter plugins cache"
safe_remove ".flutter-plugins-dependencies" "Flutter plugins dependencies cache"

# 2. Remove test files and development artifacts
echo -e "\n${BLUE}2. Removing test files and development artifacts...${NC}"
safe_remove "test_download.pdf" "Test download PDF file"
safe_remove "test_download_2.pdf" "Test download PDF file #2"
safe_remove "test_cyrillic_download.pdf" "Test Cyrillic download PDF file"
safe_remove "test_fixed_download.pdf" "Test fixed download PDF file"
safe_remove "test_payroll_functionality.sh" "Test payroll functionality script"

# 3. Remove backend backup and test files
echo -e "\n${BLUE}3. Cleaning backend backup and test files...${NC}"
safe_remove "backend/main.py.backup" "Main Python backup file"
safe_remove "backend/main_backup.py" "Main backup Python file"
safe_remove "backend/main_original_backup.py" "Original backup Python file"
safe_remove "backend/main_corrupted_backup.py" "Corrupted backup Python file"
safe_remove "backend/main_clean.py" "Clean main Python file"
safe_remove "backend/main_first_500.py" "First 500 main Python file"
safe_remove "backend/test.pdf" "Backend test PDF file"
safe_remove "backend/test_attachment.txt" "Backend test attachment file"
safe_remove "backend/test_final_download.pdf" "Backend test final download PDF"
safe_remove "backend/test_attachments.py" "Backend test attachments script"
safe_remove "backend/test_attachment_system.py" "Backend test attachment system script"
safe_remove "backend/test_database_migration.py" "Backend test database migration script"

# 4. Remove unused Flutter debug/test files
echo -e "\n${BLUE}4. Removing unused Flutter debug/test files...${NC}"
safe_remove "lib/debug/company_context_test.dart" "Company context test file (unused)"
safe_remove "lib/widgets/database_connection_test.dart" "Database connection test widget (unused)"

# 5. Clean up development environment files (optional - but preserve venv)
echo -e "\n${BLUE}5. Cleaning development environment files...${NC}"
log_warning "Python venv/ directory is PRESERVED - it's required for backend dependencies"

read -p "Remove Node.js modules? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_remove "node_modules/" "Node.js modules"
    log_warning "You can recreate with: npm install"
fi

# 6. Remove obsolete Firebase and Google client files
echo -e "\n${BLUE}6. Checking for obsolete configuration files...${NC}"
if [ -f "lib/client_secret_45935620915-6crd3a9o1pn8cvhr6f0kt1imff0uefvp.apps.googleusercontent.com.json" ]; then
    log_warning "Found Google client secret in lib/ directory - consider moving to assets/ or backend/config/"
    echo "  Path: lib/client_secret_45935620915-6crd3a9o1pn8cvhr6f0kt1imff0uefvp.apps.googleusercontent.com.json"
fi

# 7. Remove IDE-specific files (optional)
echo -e "\n${BLUE}7. IDE-specific files cleanup...${NC}"
read -p "Remove IntelliJ IDEA files (.idea/, *.iml)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_remove ".idea/" "IntelliJ IDEA directory"
    safe_remove "psc_accounting_app.iml" "IntelliJ IDEA module file"
    safe_remove "android/psc_accounting_app_android.iml" "Android IntelliJ IDEA module file"
fi

# 8. Clean up obsolete Node.js/backend JS files (if using Python backend)
echo -e "\n${BLUE}8. Checking for obsolete Node.js backend files...${NC}"
if [ -d "backend/routes" ] && [ -f "backend/main.py" ]; then
    log_warning "Found both Python backend (main.py) and Node.js routes - consider cleanup"
    read -p "Remove Node.js backend files (routes/, services/, middleware/)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        safe_remove "backend/routes/" "Node.js routes directory"
        safe_remove "backend/services/" "Node.js services directory (keeping Python files)"
        safe_remove "backend/middleware/" "Node.js middleware directory"
        safe_remove "package.json" "Node.js package.json"
        safe_remove "package-lock.json" "Node.js package-lock.json"
    fi
fi

# 9. Clean up upload directories (CAREFULLY - preserve active attachments)
echo -e "\n${BLUE}9. Checking upload directories...${NC}"
log_warning "backend/uploads/ is COMPLETELY PRESERVED - including empty folders (part of required architecture)"

if [ -d "backend/uploads/" ]; then
    echo "  backend/uploads/ directory preserved with all subdirectories (required architecture)"
else
    echo "  No backend/uploads/ directory found"
fi

# Check for other potential upload directories
for dir in "uploads/" "files/" "attachments/" "temp_uploads/"; do
    if [ -d "$dir" ] && [ "$dir" != "backend/uploads/" ]; then
        read -p "Remove '$dir' directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            safe_remove "$dir" "upload directory"
        fi
    fi
done

# 10. Remove OS-specific files
echo -e "\n${BLUE}10. Removing OS-specific files...${NC}"
find . -name ".DS_Store" -type f -delete 2>/dev/null && log_action "Removed .DS_Store files" || echo "No .DS_Store files found"
find . -name "Thumbs.db" -type f -delete 2>/dev/null && log_action "Removed Thumbs.db files" || echo "No Thumbs.db files found"
find . -name "desktop.ini" -type f -delete 2>/dev/null && log_action "Removed desktop.ini files" || echo "No desktop.ini files found"

# 11. Clean up Python cache files
echo -e "\n${BLUE}11. Cleaning Python cache files...${NC}"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null && log_action "Removed __pycache__ directories" || echo "No __pycache__ directories found"
find . -name "*.pyc" -type f -delete 2>/dev/null && log_action "Removed .pyc files" || echo "No .pyc files found"
find . -name "*.pyo" -type f -delete 2>/dev/null && log_action "Removed .pyo files" || echo "No .pyo files found"

# 12. Summary and recommendations
echo -e "\n${BLUE}📊 Cleanup Summary and Recommendations${NC}"
echo -e "${BLUE}=====================================${NC}"

echo -e "\n${GREEN}✅ Cleanup completed successfully!${NC}"

echo -e "\n${YELLOW}📋 Recommended next steps:${NC}"
echo "1. Run 'flutter clean' to ensure Flutter build cache is cleared"
echo "2. Run 'flutter pub get' to reinstall dependencies"
echo "3. Run 'dart analyze' to check for any issues"
echo "4. Test your application to ensure everything works correctly"

echo -e "\n${YELLOW}📁 Directories that were preserved:${NC}"
echo "- lib/ (your Flutter source code)"
echo "- backend/ (main Python backend files)"
echo "- backend/uploads/ (file attachment system - including all subdirectories)"
echo "- venv/ (Python virtual environment)"
echo "- android/, ios/, web/, windows/, linux/, macos/ (platform-specific code)"
echo "- assets/ (application assets)"
echo "- test/ (official Flutter test directory)"

echo -e "\n${YELLOW}🔧 Optional manual cleanup:${NC}"
echo "1. Review backend/attachments/ directory for old test files"
echo "2. Check backend/config/ for unused configuration files"
echo "3. Review any custom scripts in the root directory"
echo "4. Consider cleaning up old migration files if no longer needed"

echo -e "\n${BLUE}💾 To save disk space regularly, add these to your .gitignore:${NC}"
echo "build/"
echo ".dart_tool/build/"
echo "**/*.pyc"
echo "**/__pycache__/"
echo "*.log"
echo "*.tmp"

echo -e "\n${GREEN}🎉 Project cleanup completed!${NC}"
