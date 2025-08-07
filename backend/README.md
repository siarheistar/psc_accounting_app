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
