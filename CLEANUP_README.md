# PSC Accounting App - Cleanup Tools

This directory contains automated tools for analyzing and cleaning up obsolete and unused files in the PSC Accounting App project.

## 🔍 Available Scripts

### 1. `analyze_project.sh` - Project Analysis Tool
**Purpose**: Analyzes the project to identify potentially unused files, dependencies, and directories.

**Usage**:
```bash
./analyze_project.sh
```

**What it analyzes**:
- 📁 Unused Dart files in `lib/` directory
- 🐍 Unused Python files in `backend/` directory  
- 📂 Empty directories
- ⚙️ Configuration files status
- 🧪 Test and temporary files
- 🔐 Credential files location
- 📦 Potentially unused dependencies
- 💾 Directory disk usage

### 2. `cleanup_project.sh` - Automated Cleanup Tool
**Purpose**: Safely removes identified obsolete, unused, and temporary files.

**Usage**:
```bash
./cleanup_project.sh
```

**What it removes**:
- 🏗️ Build artifacts (`build/`, `.dart_tool/build/`)
- 📄 Test PDF files (`test_*.pdf`)
- 🔄 Backup files (`*_backup.*`, `main.py.backup`)
- 🧪 Test scripts and files
- 🗑️ OS-specific files (`.DS_Store`, `Thumbs.db`)
- 🐍 Python cache files (`__pycache__/`, `*.pyc`)

## 🚀 Quick Start

1. **First, analyze your project**:
   ```bash
   ./analyze_project.sh
   ```
   Review the output to understand what files might be obsolete.

2. **Run the cleanup**:
   ```bash
   ./cleanup_project.sh
   ```
   The script will prompt you for confirmation on optional cleanups.

3. **Verify everything works**:
   ```bash
   flutter clean
   flutter pub get
   flutter analyze
   ```

## 📋 Files Identified for Removal

### ✅ Safe to Remove (Automated)
- `test_download*.pdf` - Test PDF files
- `test_payroll_functionality.sh` - Test script
- `backend/main*_backup.py` - Python backup files
- `backend/test*.py` - Backend test files  
- `backend/test*.pdf` - Backend test PDFs
- `build/` directory - Flutter build artifacts
- Python cache files and directories

### ⚠️ Review Before Removing (Manual Confirmation)
- `lib/debug/company_context_test.dart` - Debug test file (unused)
- `lib/widgets/database_connection_test.dart` - Test widget (unused)
- `venv/` - Python virtual environment
- `node_modules/` - Node.js dependencies (if using Python backend)
- `.idea/` and `*.iml` files - IntelliJ IDEA files

### 🔍 Needs Manual Review
- `backend/routes/` - Node.js routes (if using Python backend)
- `backend/services/*.js` - Node.js services (if using Python backend)
- `backend/uploads/` - Upload directory contents
- Configuration files with credentials

## 🛡️ Safety Features

- **Interactive prompts** for potentially destructive operations
- **Colored output** to distinguish different types of actions
- **Verification checks** to ensure you're in the right directory
- **Detailed logging** of all actions performed
- **Preservation** of all essential project files

## 📊 Expected Results

### Before Cleanup
```
Project Size: ~500MB+ (with build artifacts)
- build/: ~200MB
- node_modules/: ~100MB  
- venv/: ~50MB
- Test files: ~10MB
```

### After Cleanup
```
Project Size: ~50-100MB (essential files only)
- Source code: ~30MB
- Assets: ~10MB
- Configuration: ~5MB
```

## 🔧 Customization

To modify what gets cleaned up, edit the respective scripts:

- **Add new patterns**: Update the file pattern arrays
- **Change behavior**: Modify the `safe_remove()` function
- **Add new checks**: Extend the analysis sections

## ⚡ Integration with Development Workflow

### Git Integration
Add to your `.gitignore`:
```
build/
.dart_tool/build/
**/*.pyc
**/__pycache__/
*.log
*.tmp
test_*.pdf
*_backup.*
```

### Regular Maintenance
Run these scripts:
- **Weekly**: `./analyze_project.sh` to monitor project health
- **Before commits**: `./cleanup_project.sh` to remove temporary files
- **Before releases**: Full cleanup with all optional removals

## 🆘 Troubleshooting

### Script won't run
```bash
chmod +x cleanup_project.sh analyze_project.sh
```

### False positives in analysis
Some files may be marked as unused but are actually needed:
- Files loaded dynamically
- Configuration files used by external tools
- Platform-specific files

### Accidentally removed important files
- Check git history: `git log --oneline`
- Restore from backup: `git checkout HEAD~1 -- <filename>`

## 📞 Support

If you encounter issues:
1. Check the script output for error messages
2. Verify you're in the project root directory
3. Ensure you have proper file permissions
4. Review the git status before and after cleanup

---

**⚠️ Important**: Always commit your work to git before running cleanup scripts!
