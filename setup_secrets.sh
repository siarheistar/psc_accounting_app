#!/bin/bash

# PSC Accounting App - Secrets Setup Script
# This script helps set up secure environment configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 PSC Accounting App - Secrets Setup${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Function to generate secure passwords
generate_password() {
    local length=${1:-32}
    python3 -c "import secrets; import string; chars = string.ascii_letters + string.digits + '!@#$%^&*'; print(''.join(secrets.choice(chars) for _ in range($length)))"
}

# Function to generate URL-safe tokens
generate_token() {
    local length=${1:-32}
    python3 -c "import secrets; print(secrets.token_urlsafe($length))"
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "backend" ]; then
    echo -e "${RED}❌ This script must be run from the root of the PSC Accounting App project${NC}"
    exit 1
fi

# Navigate to backend directory
cd backend/

echo -e "${BLUE}📁 Setting up environment configuration...${NC}"

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️ .env file already exists${NC}"
    read -p "Do you want to backup the existing .env file? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✅ Backed up existing .env file${NC}"
    fi
    
    read -p "Do you want to overwrite the existing .env file? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Exiting without changes${NC}"
        exit 0
    fi
fi

# Copy template file
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo -e "${GREEN}✅ Created .env from template${NC}"
else
    echo -e "${RED}❌ .env.example not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔧 Configuring database credentials...${NC}"

# Get database configuration from user
read -p "Enter database host: " db_host
read -p "Enter database port [5432]: " db_port
db_port=${db_port:-5432}
read -p "Enter database name: " db_name  
read -p "Enter database username: " db_user
read -s -p "Enter database password: " db_password
echo ""

# Ask about environment
echo ""
echo -e "${BLUE}🌍 Environment configuration...${NC}"
echo "1) Development (debug enabled, local settings)"
echo "2) Staging (production-like, but with debug info)"
echo "3) Production (optimized, secure)"
read -p "Select environment [1]: " env_choice
env_choice=${env_choice:-1}

case $env_choice in
    1)
        environment="development"
        debug="true"
        ;;
    2)
        environment="staging" 
        debug="false"
        ;;
    3)
        environment="production"
        debug="false"
        ;;
    *)
        environment="development"
        debug="true"
        ;;
esac

# Generate secure keys for production/staging
if [[ $environment != "development" ]]; then
    echo ""
    echo -e "${BLUE}🔑 Generating secure keys...${NC}"
    jwt_secret=$(generate_token 32)
    api_secret=$(generate_token 32)
    echo -e "${GREEN}✅ Generated JWT secret key${NC}"
    echo -e "${GREEN}✅ Generated API secret key${NC}"
else
    jwt_secret="development-jwt-key-not-secure"
    api_secret="development-api-key-not-secure"
fi

# Update .env file with actual values
echo ""
echo -e "${BLUE}📝 Writing configuration to .env file...${NC}"

# Use sed to replace values in .env file
sed -i.bak "s|DB_HOST=.*|DB_HOST=$db_host|g" .env
sed -i.bak "s|DB_PORT=.*|DB_PORT=$db_port|g" .env  
sed -i.bak "s|DB_NAME=.*|DB_NAME=$db_name|g" .env
sed -i.bak "s|DB_USER=.*|DB_USER=$db_user|g" .env
sed -i.bak "s|DB_PASSWORD=.*|DB_PASSWORD=$db_password|g" .env
sed -i.bak "s|ENVIRONMENT=.*|ENVIRONMENT=$environment|g" .env
sed -i.bak "s|DEBUG=.*|DEBUG=$debug|g" .env
sed -i.bak "s|JWT_SECRET=.*|JWT_SECRET=$jwt_secret|g" .env
sed -i.bak "s|API_SECRET_KEY=.*|API_SECRET_KEY=$api_secret|g" .env

# Remove backup file created by sed
rm -f .env.bak

echo -e "${GREEN}✅ Configuration written to .env file${NC}"

# Set proper file permissions
chmod 600 .env
echo -e "${GREEN}✅ Set secure file permissions (600) on .env file${NC}"

# Verify .env is in .gitignore
cd ..
if ! grep -q "\.env" .gitignore; then
    echo ""
    echo -e "${YELLOW}⚠️ Adding .env to .gitignore for security${NC}"
    echo ".env" >> .gitignore
    echo "backend/.env" >> .gitignore
fi

echo ""
echo -e "${BLUE}🧪 Testing database connection...${NC}"
cd backend/

# Test database connection
python3 -c "
try:
    from env_config import env_config
    from database import initialize_db_pool
    
    print('📋 Configuration loaded successfully')
    print(f'🌍 Environment: {env_config.get_config(\"ENVIRONMENT\")}')
    print(f'🗄️ Database: {env_config.get_config(\"DB_HOST\")}:{env_config.get_config(\"DB_PORT\")}/{env_config.get_config(\"DB_NAME\")}')
    
    # Test database connection
    if initialize_db_pool():
        print('✅ Database connection successful!')
    else:
        print('❌ Database connection failed!')
        
except ImportError as e:
    print(f'⚠️ Import error: {e}')
    print('Make sure to install dependencies: pip install -r requirements.txt')
except Exception as e:
    print(f'❌ Configuration error: {e}')
"

echo ""
echo -e "${GREEN}🎉 Secrets setup completed!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo -e "  Environment: $environment"
echo -e "  Database: $db_host:$db_port/$db_name"
echo -e "  Configuration file: backend/.env"
echo -e "  File permissions: 600 (secure)"
echo ""
echo -e "${YELLOW}🔒 Security reminders:${NC}"
echo -e "  • Never commit .env file to version control"
echo -e "  • Keep database credentials secure"
echo -e "  • Use different passwords for each environment"
echo -e "  • Regularly rotate credentials"
echo ""
echo -e "${BLUE}🚀 Next steps:${NC}"
echo -e "  1. Install dependencies: cd backend && pip install -r requirements.txt"
echo -e "  2. Start the API server: cd backend && python main.py"
echo -e "  3. Test the API: curl http://localhost:8000/health"
echo ""
echo -e "${GREEN}✅ Setup complete! Your secrets are now properly configured.${NC}"