#!/bin/bash

# PSC Accounting App - Merge Feature Branch to Master Script
# This script automates the complete process of merging a feature branch to master

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the current directory (should be run from project root)
PROJECT_ROOT=$(pwd)

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ] || [ ! -d "backend" ]; then
    print_error "This script must be run from the project root directory!"
    print_error "Expected to find: pubspec.yaml, lib/, and backend/ directories"
    exit 1
fi

print_status "Starting merge process for PSC Accounting App..."
print_status "Project root: $PROJECT_ROOT"

# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)
print_status "Current branch: $CURRENT_BRANCH"

# Check if we're not already on master
if [ "$CURRENT_BRANCH" = "master" ]; then
    print_error "Already on master branch! Please switch to a feature branch first."
    exit 1
fi

# Confirm the merge
echo ""
print_warning "This script will:"
echo "  1. Add and commit all pending changes on '$CURRENT_BRANCH'"
echo "  2. Switch to master branch"
echo "  3. Pull latest changes from origin/master"
echo "  4. Merge '$CURRENT_BRANCH' into master"
echo "  5. Push merged changes to origin/master"
echo "  6. Optionally delete the feature branch"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Merge cancelled by user."
    exit 0
fi

# Step 1: Check git status and commit pending changes
print_status "Step 1: Checking git status and committing pending changes..."

# Check if there are any changes
if ! git diff-index --quiet HEAD --; then
    print_status "Found uncommitted changes. Adding and committing..."
    
    # Show what will be committed
    echo ""
    print_status "Files to be committed:"
    git status --porcelain
    echo ""
    
    # Add all changes
    git add .
    
    # Get commit message from user
    echo "Enter commit message for pending changes:"
    read -p "Commit message: " COMMIT_MESSAGE
    
    if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="Auto-commit: Merge preparation for $CURRENT_BRANCH to master"
    fi
    
    git commit -m "$COMMIT_MESSAGE"
    print_success "Changes committed successfully."
else
    print_status "No uncommitted changes found."
fi

# Step 2: Switch to master branch
print_status "Step 2: Switching to master branch..."
git checkout master
print_success "Switched to master branch."

# Step 3: Pull latest changes from origin/master
print_status "Step 3: Pulling latest changes from origin/master..."
git pull origin master
print_success "Master branch updated."

# Step 4: Merge feature branch into master
print_status "Step 4: Merging '$CURRENT_BRANCH' into master..."

# Check if merge will be fast-forward
MERGE_BASE=$(git merge-base master $CURRENT_BRANCH)
MASTER_HEAD=$(git rev-parse master)

if [ "$MERGE_BASE" = "$MASTER_HEAD" ]; then
    print_status "Fast-forward merge possible."
    git merge $CURRENT_BRANCH
else
    print_status "Non-fast-forward merge required."
    git merge --no-ff $CURRENT_BRANCH -m "Merge branch '$CURRENT_BRANCH' into master"
fi

print_success "Branch '$CURRENT_BRANCH' merged into master successfully."

# Step 5: Push merged changes to origin/master
print_status "Step 5: Pushing merged changes to origin/master..."
git push origin master
print_success "Changes pushed to origin/master."

# Step 6: Optional cleanup - delete feature branch
echo ""
print_warning "Cleanup: Delete feature branch '$CURRENT_BRANCH'?"
echo "This will delete both local and remote branches."
read -p "Delete '$CURRENT_BRANCH' branch? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deleting local branch '$CURRENT_BRANCH'..."
    
    # Force delete local branch (since we just merged it)
    git branch -D $CURRENT_BRANCH
    print_success "Local branch '$CURRENT_BRANCH' deleted."
    
    # Delete remote branch if it exists
    if git ls-remote --heads origin $CURRENT_BRANCH | grep -q $CURRENT_BRANCH; then
        print_status "Deleting remote branch 'origin/$CURRENT_BRANCH'..."
        git push origin --delete $CURRENT_BRANCH
        print_success "Remote branch 'origin/$CURRENT_BRANCH' deleted."
    else
        print_warning "Remote branch 'origin/$CURRENT_BRANCH' not found or already deleted."
    fi
else
    print_warning "Feature branch '$CURRENT_BRANCH' preserved."
    print_status "You can delete it later with: git branch -D $CURRENT_BRANCH"
    print_status "And remote with: git push origin --delete $CURRENT_BRANCH"
fi

# Final status
echo ""
print_success "=== MERGE COMPLETED SUCCESSFULLY ==="
print_success "✓ Branch '$CURRENT_BRANCH' merged into master"
print_success "✓ Changes pushed to origin/master"
print_success "✓ Currently on master branch"

# Show final git status
echo ""
print_status "Final git status:"
git status --short
git log --oneline -5

echo ""
print_success "Merge process completed! 🎉"
print_status "Master branch is now updated with all changes from '$CURRENT_BRANCH'."

# Optional: Show what was merged
echo ""
print_status "Summary of merged changes:"
git diff --name-status HEAD~1 HEAD | head -20
if [ $(git diff --name-status HEAD~1 HEAD | wc -l) -gt 20 ]; then
    echo "... and $(( $(git diff --name-status HEAD~1 HEAD | wc -l) - 20 )) more files"
fi
