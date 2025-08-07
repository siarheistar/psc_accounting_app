#!/bin/bash

# PSC Accounting App Setup Script
# This script helps you set up the backend API and database connection

echo "🚀 PSC Accounting App Setup"
echo "=========================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 14+ and try again."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm and try again."
    exit 1
fi

echo "✅ npm version: $(npm --version)"

# Create backend directory
echo "📁 Creating backend directory..."
mkdir -p backend
cd backend

# Create package.json
echo "📦 Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "psc-accounting-api",
  "version": "1.0.0",
  "description": "API for PSC Accounting App with PostgreSQL",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF

# Install dependencies
echo "📥 Installing dependencies..."
npm install

# Create .env file
echo "🔐 Creating environment configuration..."
cat > .env << 'EOF'
# Database Configuration
DB_PASSWORD=Il1k3f1sh1ngperch!
DB_HOST=pscdb.cnacsqi4u8qw.eu-west-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=pscdb
DB_USER=postgres

# Server Configuration
NODE_ENV=development
PORT=3000

# Security
JWT_SECRET=psc_accounting_jwt_secret_2024
API_KEY=psc_accounting_api_key_2024

# File Upload
MAX_FILE_SIZE=50mb
UPLOAD_PATH=./uploads
EOF

echo "⚠️  IMPORTANT: Please edit the .env file and set your actual database password!"
echo "   The file is located at: $(pwd)/.env"
echo ""

# Create the server.js file (copy the backend API code here)
echo "🖥️  Creating server.js..."
# Note: You would copy the complete server.js content from the backend API artifact here
# For brevity, I'm creating a placeholder that tells the user to add the code

cat > server.js << 'EOF'
// PSC Accounting API Server
// Copy the complete backend API code from your artifacts here

console.log('⚠️  Please copy the complete backend API code to this server.js file');
console.log('📄 The code is available in the backend_api_example artifact');
console.log('🔗 Make sure to update the database connection details');

// Placeholder to prevent crashes
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'PSC Accounting API - Please complete setup by copying the backend code',
    status: 'setup_required'
  });
});

app.listen(PORT, () => {
  console.log(`🔧 Setup server running on port ${PORT}`);
  console.log(`📝 Please complete setup by copying the backend API code`);
});
EOF

# Create startup scripts
echo "🚀 Creating startup scripts..."

# Development start script
cat > start-dev.sh << 'EOF'
#!/bin/bash
echo "🔥 Starting PSC Accounting API in development mode..."
npm run dev
EOF

# Production start script
cat > start-prod.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting PSC Accounting API in production mode..."
npm start
EOF

# Make scripts executable
chmod +x start-dev.sh start-prod.sh

# Create a README for the backend
cat > README.md << 'EOF'
# PSC Accounting API Backend

## Setup Instructions

1. **Install Dependencies** (already done by setup script)
   ```bash
   npm install
   ```

2. **Configure Environment**
   - Edit `.env` file and set your actual database password
   - Update any other configuration as needed

3. **Copy Backend Code**
   - Copy the complete backend API code to `server.js`
   - The code is available in your artifacts

4. **Start Development Server**
   ```bash
   ./start-dev.sh
   # or
   npm run dev
   ```

5. **Test the API**
   - Open http://localhost:3000/api/health
   - You should see a database connection status

## API Endpoints

- `GET /api/health` - Health check
- `GET /api/invoices` - Get all invoices
- `POST /api/invoices` - Create new invoice
- `GET /api/expenses` - Get all expenses
- `POST /api/expenses` - Create new expense
- `GET /api/companies` - Get all companies
- `GET /api/employees` - Get all employees
- `POST /api/attachments` - Upload file
- `GET /api/dashboard/metrics` - Get dashboard metrics

## Deployment

### Heroku
```bash
heroku create your-app-name
heroku config:set DB_PASSWORD=your_actual_password
git push heroku main
```

### AWS EC2
1. Launch EC2 instance
2. Install Node.js and PM2
3. Clone your repository
4. Set environment variables
5. `pm2 start server.js --name accounting-api`

## Environment Variables

- `DB_PASSWORD` - Your PostgreSQL password (REQUIRED)
- `DB_HOST` - Database host (default: your AWS RDS)
- `DB_PORT` - Database port (default: 5432)
- `NODE_ENV` - Environment (development/production)
- `PORT` - Server port (default: 3000)
EOF

# Create database test script
cat > test-db.js << 'EOF'
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function testConnection() {
  try {
    console.log('🔄 Testing database connection...');
    const client = await pool.connect();
    const result = await client.query('SELECT NOW(), version()');
    console.log('✅ Database connected successfully!');
    console.log('📅 Server time:', result.rows[0].now);
    console.log('🔢 PostgreSQL version:', result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1]);
    client.release();
    process.exit(0);
  } catch (err) {
    console.error('❌ Database connection failed:');
    console.error(err.message);
    process.exit(1);
  }
}

testConnection();
EOF

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Edit .env file and set your database password"
echo "2. Copy the complete backend API code to server.js"
echo "3. Test database connection: node test-db.js"
echo "4. Start development server: ./start-dev.sh"
echo "5. Update Flutter app with API URL: http://localhost:3000/api"
echo ""
echo "📁 Backend files created in: $(pwd)"
echo "🔧 Configuration file: .env"
echo "🖥️  Server file: server.js"
echo "📖 Documentation: README.md"
echo ""
echo "🆘 Need help? Check the README.md file for detailed instructions."