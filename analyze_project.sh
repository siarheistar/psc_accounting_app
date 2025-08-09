#!/bin/bash

# PSC Accounting App - File Usage Analysis Script
# This script analyzes which files are actually used in the project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 PSC Accounting App - File Usage Analysis${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ]; then
    echo -e "${RED}❌ This script must be run from the root of the PSC Accounting App project${NC}"
    exit 1
fi

# Create temporary file for analysis
TEMP_FILE=$(mktemp)
UNUSED_FILE=$(mktemp)

echo -e "${BLUE}📋 Analyzing Flutter lib/ directory imports...${NC}"

# Function to check if a file is imported anywhere
check_file_usage() {
    local file_path="$1"
    local relative_path=$(echo "$file_path" | sed 's|.*/lib/||')
    local import_pattern="import.*${relative_path}"
    
    # Search for imports of this file (excluding the file itself)
    grep -r --include="*.dart" "$import_pattern" lib/ | grep -v "^${file_path}:" | wc -l
}

# Analyze Dart files in lib/
echo -e "\n${YELLOW}🔎 Scanning for potentially unused Dart files...${NC}"
echo ""

find lib/ -name "*.dart" -type f | while read dart_file; do
    usage_count=$(check_file_usage "$dart_file")
    if [ "$usage_count" -eq 0 ]; then
        echo -e "${YELLOW}❓ Potentially unused: $dart_file${NC}"
        echo "$dart_file" >> "$UNUSED_FILE"
    fi
done

echo -e "\n${BLUE}📊 Backend Python files analysis...${NC}"

# Check Python backend files
if [ -d "backend" ]; then
    echo -e "\n${YELLOW}🐍 Checking Python backend files...${NC}"
    
    # Check if main.py imports these files
    if [ -f "backend/main.py" ]; then
        echo -e "\n${GREEN}Files imported by main.py:${NC}"
        grep "^import\|^from.*import" backend/main.py | grep -v "^#" | while read import_line; do
            echo "  $import_line"
        done
        
        echo -e "\n${YELLOW}Potentially unused Python files in backend/:${NC}"
        find backend/ -name "*.py" -type f | while read py_file; do
            filename=$(basename "$py_file" .py)
            # Skip main.py and check if it's imported
            if [ "$filename" != "main" ]; then
                if ! grep -q "$filename" backend/main.py 2>/dev/null; then
                    echo -e "${YELLOW}❓ $py_file${NC}"
                fi
            fi
        done
    fi
fi

echo -e "\n${BLUE}📁 Directory usage analysis...${NC}"

# Check for empty or potentially unused directories
echo -e "\n${YELLOW}📂 Checking for empty directories...${NC}"
find . -type d -empty 2>/dev/null | while read empty_dir; do
    # Skip hidden directories and common build directories
    if [[ ! "$empty_dir" =~ ^\./\. ]] && [[ ! "$empty_dir" =~ build ]] && [[ ! "$empty_dir" =~ node_modules ]]; then
        echo -e "${YELLOW}📁 Empty directory: $empty_dir${NC}"
    fi
done

echo -e "\n${BLUE}🗂️  Configuration files analysis...${NC}"

# Check for duplicate or unused configuration files
echo -e "\n${YELLOW}⚙️  Configuration files review:${NC}"

config_files=(
    "firebase.json"
    "firestore.rules" 
    "firestore.indexes.json"
    "storage.rules"
    ".firebaserc"
    "docker-compose.yml"
    "package.json"
    "requirements.txt"
)

for config_file in "${config_files[@]}"; do
    if [ -f "$config_file" ]; then
        echo -e "${GREEN}✓ $config_file${NC}"
    else
        echo -e "${RED}✗ $config_file (missing)${NC}"
    fi
done

echo -e "\n${BLUE}📄 Test and temporary files analysis...${NC}"

# Find test and temporary files
echo -e "\n${YELLOW}🧪 Test and temporary files found:${NC}"
test_patterns=(
    "test_*.pdf"
    "test_*.py"
    "test_*.dart"
    "test_*.sh"
    "*_backup.*"
    "*_test.*"
    "*.tmp"
    "*.log"
)

for pattern in "${test_patterns[@]}"; do
    find . -name "$pattern" -type f 2>/dev/null | while read test_file; do
        echo -e "${YELLOW}📝 $test_file${NC}"
    done
done

echo -e "\n${BLUE}🔐 Secrets and credentials analysis...${NC}"

# Check for credential files that might need attention
echo -e "\n${YELLOW}🔑 Credential files found:${NC}"
find . -name "*secret*" -o -name "*key*" -o -name "*.pem" -o -name "*credential*" 2>/dev/null | while read cred_file; do
    echo -e "${YELLOW}🔐 $cred_file${NC}"
done

echo -e "\n${BLUE}📦 Dependencies analysis...${NC}"

# Check pubspec.yaml for unused dependencies (basic check)
if [ -f "pubspec.yaml" ]; then
    echo -e "\n${YELLOW}📋 Flutter dependencies declared in pubspec.yaml:${NC}"
    awk '/dependencies:/,/dev_dependencies:/' pubspec.yaml | grep '  [a-zA-Z]' | grep -v 'dependencies:' | while read dep; do
        dep_name=$(echo "$dep" | cut -d':' -f1 | xargs)
        # Simple check if dependency is used in Dart files
        if [ -n "$dep_name" ] && ! grep -r --include="*.dart" "$dep_name" lib/ >/dev/null 2>&1; then
            echo -e "${YELLOW}❓ Potentially unused: $dep_name${NC}"
        fi
    done
fi

echo -e "\n${BLUE}💾 Disk usage analysis...${NC}"

# Show disk usage of major directories
echo -e "\n${YELLOW}💿 Directory sizes:${NC}"
for dir in build node_modules .dart_tool backend/uploads backend/__pycache__ venv; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo -e "${BLUE}📁 $dir: $size${NC}"
    fi
done

echo -e "\n${BLUE}📋 Summary and Recommendations${NC}"
echo -e "${BLUE}==============================${NC}"

echo -e "\n${GREEN}✅ Analysis completed!${NC}"

echo -e "\n${YELLOW}🎯 Key findings:${NC}"
echo "1. Run './cleanup_project.sh' to remove identified obsolete files"
echo "2. Review potentially unused Dart files before removing"
echo "3. Consider moving credential files to secure locations"
echo "4. Clean up test files that are no longer needed"

echo -e "\n${YELLOW}⚠️  Manual review recommended for:${NC}"
echo "- Files marked as 'potentially unused' (may be used in ways not detected)"
echo "- Configuration files (ensure they're actually needed)"
echo "- Credential files (verify they're properly secured)"

# Cleanup temp files
rm -f "$TEMP_FILE" "$UNUSED_FILE"

echo -e "\n${GREEN}🏁 Analysis complete!${NC}"
