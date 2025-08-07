# PSC Accounting API - Postman Testing Suite

This directory contains comprehensive Postman collection and environment files for testing the PSC Accounting API with your real company data.

## Files

### 1. `PSC_Accounting_API.postman_collection.json`
Complete Postman collection with all API endpoints and automated tests.

### 2. `PSC_Accounting_Local.postman_environment.json`
Environment configuration for local development testing.

## API Endpoints Covered

### Companies
- **GET** `/companies` - Get all companies for a user
- Tests: Response structure, real company data validation, demo mode checks

### Invoices  
- **GET** `/invoices` - Get all invoices for a company
- Tests: Data structure, amount validation, real data existence

### Expenses
- **GET** `/expenses` - Get all expenses for a company  
- Tests: Field validation, amount checks, category verification

### Payroll
- **GET** `/payroll` - Get all payroll entries for a company
- Tests: Employee data, salary calculations, period validation

### Bank Statements
- **GET** `/bank-statements` - Get all bank statements for a company
- Tests: Transaction data, balance calculations, date validation

### Dashboard
- **GET** `/dashboard/metrics` - Get dashboard metrics (query parameter)
- **GET** `/dashboard/{company_id}` - Get dashboard metrics (path parameter)
- Tests: Calculation accuracy, data consistency, net profit validation

### Health Check
- **GET** `/health` - API health status
- Tests: Service availability, storage mode configuration

## Expected Real Data

Based on your current database state:
- **Company**: "Siarhei Test" (ID: 1, Owner: siarhei.star@gmail.com)
- **Invoices**: 2 invoices totaling $3,500
- **Expenses**: 1 expense totaling $100  
- **Net Profit**: $3,400
- **Payroll**: 3+ entries with various employees

## How to Import and Use

### Method 1: Import in Postman Desktop/Web
1. Open Postman
2. Click "Import" button
3. Select both JSON files:
   - `PSC_Accounting_API.postman_collection.json`
   - `PSC_Accounting_Local.postman_environment.json`
4. Select the "PSC Accounting - Local" environment
5. Run individual requests or the entire collection

### Method 2: Command Line with Newman
```bash
# Install Newman (Postman CLI)
npm install -g newman

# Run the entire collection
newman run PSC_Accounting_API.postman_collection.json \
  -e PSC_Accounting_Local.postman_environment.json \
  --reporters cli,json \
  --reporter-json-export results.json

# Run with detailed output
newman run PSC_Accounting_API.postman_collection.json \
  -e PSC_Accounting_Local.postman_environment.json \
  --reporters cli,html \
  --reporter-html-export report.html
```

## Test Validation

### Automated Checks
- ✅ HTTP status codes (200 OK)
- ✅ Response data structure validation
- ✅ Required field presence
- ✅ Data type validation (numbers, strings, dates)
- ✅ Business logic validation (calculations, relationships)
- ✅ Real data vs expected values
- ✅ Cross-endpoint data consistency

### Key Test Scenarios
1. **Company Data**: Validates "Siarhei Test" company exists and is not demo
2. **Financial Calculations**: Verifies net profit = income - expenses  
3. **Data Relationships**: Ensures invoice/expense IDs match company context
4. **API Health**: Confirms service is operational with correct storage mode

## Environment Variables

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `base_url` | `http://localhost:8000` | API base URL |
| `owner_email` | `siarhei.star@gmail.com` | Your email address |
| `company_id` | `1` | Company ID (auto-set from first request) |
| `company_name` | `Siarhei Test` | Company name (auto-set) |
| `invoice_id` | (auto-set) | Latest invoice ID for testing |
| `expense_id` | (auto-set) | Latest expense ID for testing |
| `payroll_id` | (auto-set) | Latest payroll ID for testing |
| `bank_statement_id` | (auto-set) | Latest bank statement ID for testing |

## Test Results Interpretation

### ✅ All Tests Pass
- API is working correctly with real data
- Database connections are functional  
- Business logic calculations are accurate

### ❌ Test Failures
Common issues and solutions:

1. **Connection Refused**: Backend server not running
   ```bash
   cd backend && source ../venv/bin/activate && python -m uvicorn main:app --host 0.0.0.0 --port 8000
   ```

2. **404 Not Found**: Endpoint missing or incorrect URL
   - Check base_url environment variable
   - Verify API endpoint paths

3. **Data Validation Errors**: Database schema mismatch
   - Check database connection
   - Verify table structures match expected schema

4. **Calculation Errors**: Business logic issues
   - Review SQL queries in backend
   - Check data consistency in database

## Extending the Tests

To add new endpoints or modify existing tests:

1. **Add New Request**: 
   - Create new request in appropriate folder
   - Set proper HTTP method and URL
   - Add query parameters or request body as needed

2. **Add Tests**:
   ```javascript
   pm.test("Your test description", function () {
       pm.response.to.have.status(200);
       // Add your assertions here
   });
   ```

3. **Environment Variables**:
   ```javascript
   // Set variable
   pm.environment.set("variable_name", value);
   
   // Get variable  
   pm.environment.get("variable_name");
   ```

## Continuous Integration

For automated testing in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run API Tests
  run: |
    newman run PSC_Accounting_API.postman_collection.json \
      -e PSC_Accounting_Local.postman_environment.json \
      --reporters junit \
      --reporter-junit-export results.xml
```

## Support

For issues with the API tests:
1. Check backend server logs for errors
2. Verify database connectivity  
3. Review environment variable settings
4. Run individual requests to isolate problems

The test suite is designed to validate your real company data and ensure the API maintains data integrity across all accounting operations.
