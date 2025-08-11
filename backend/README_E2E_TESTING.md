# PSC Accounting App - E2E Testing Guide

## Overview

This document provides comprehensive testing instructions for the PSC Accounting App API endpoints, covering company and user CRUD operations using Postman collections.

## Test Coverage

### Company Operations
- ✅ Create Company (valid data, minimal data, validation testing)
- ✅ Read Company (get all, get by ID, verify data structure)
- ✅ Update Company (full update, partial update, non-existent handling)
- ✅ Delete Company (success, cleanup, non-existent handling)

### User Operations
- 🔄 Create User (ready for implementation)
- 🔄 Read User (ready for implementation)
- 🔄 Update User (ready for implementation)
- 🔄 Delete User (ready for implementation)

### Data Validation Tests
- ✅ VAT Number format validation
- ✅ Country-based currency assignment
- ✅ Required field validation
- ✅ Error handling scenarios

## Setup Instructions

### 1. Import Postman Collection

1. Open Postman
2. Click "Import" in the top left
3. Select `PSC_Accounting_E2E_Tests.postman_collection.json`
4. Click "Import"

### 2. Import Environment

1. In Postman, click the environment dropdown (top right)
2. Click "Import"
3. Select `PSC_Accounting_E2E.postman_environment.json`
4. Click "Import"
5. Select "PSC Accounting E2E Environment" as active environment

### 3. Start Backend Server

Ensure your backend is running on `http://localhost:8000`:

```bash
cd backend
python main.py
```

### 4. Verify Database Connection

Ensure PostgreSQL is running and the database schema includes:
- `companies` table with all required fields
- Proper indexes and constraints

## Running Tests

### Option 1: Run Complete Collection

1. In Postman, right-click on "PSC Accounting App - E2E Tests"
2. Select "Run collection"
3. Choose "PSC Accounting E2E Environment"
4. Click "Run PSC Accounting App - E2E Tests"

### Option 2: Run Individual Test Folders

#### Company Operations
- Navigate to "Company Operations" folder
- Right-click → "Run folder"
- This will test all company CRUD operations sequentially

#### User Operations
- Navigate to "User Operations" folder
- Right-click → "Run folder"
- Note: These tests expect user endpoints to be implemented

#### Data Validation Tests
- Navigate to "Data Validation Tests" folder
- Right-click → "Run folder"
- Tests various validation scenarios

### Option 3: Run Individual Tests

Click on any individual test and use the "Send" button to run specific scenarios.

## Test Data

### Sample Company Data

#### Full Company Creation
```json
{
    "name": "Test Company Ltd",
    "owner_email": "owner@testcompany.com",
    "phone": "+353-1-555-0123",
    "address": "123 Business Park, Dublin 2, Ireland",
    "country": "Ireland",
    "currency": "EUR",
    "vat_number": "IE1234567T",
    "subscription_plan": "basic",
    "is_demo": false,
    "status": "active"
}
```

#### Minimal Company Creation
```json
{
    "name": "Minimal Company",
    "owner_email": "minimal@company.com"
}
```

### Sample User Data (for future implementation)

```json
{
    "firebase_uid": "test-firebase-uid-123",
    "email": "testuser@example.com",
    "display_name": "Test User",
    "phone_number": "+353-1-555-0100"
}
```

## Expected Test Results

### Company Tests
- **12 tests** covering complete CRUD lifecycle
- All tests should pass with 200/201 status codes for success scenarios
- Error tests should return appropriate 4xx status codes
- Response time should be under 2000ms for most operations

### User Tests
- **4 tests** ready for when user endpoints are implemented
- Currently expected to return 404/405 (not implemented)
- Will automatically pass when endpoints are added

### Validation Tests
- **4 tests** for data validation scenarios
- Tests VAT number formats, currency assignment, and edge cases

## Database Verification

After running tests, verify in your database:

### Check Company Creation
```sql
SELECT * FROM companies WHERE name LIKE '%Test%';
```

### Verify Field Updates
```sql
SELECT id, name, vat_number, country, currency, updated_at 
FROM companies 
WHERE name LIKE '%Updated%';
```

### Confirm Deletions
```sql
SELECT COUNT(*) FROM companies WHERE name LIKE '%Test%';
-- Should return 0 after cleanup
```

## Enhanced Company Dialogs

The app now includes comprehensive company creation and editing dialogs with the following improvements:

### Create Company Dialog (`create_company_dialog.dart`)
- **Business Information**: Company name, owner email, phone, address
- **Location & Tax**: Country selection, auto-currency assignment, VAT number validation
- **Subscription**: Plan selection with descriptions
- **Validation**: Email format, VAT format by country, required fields

### Edit Company Dialog (`edit_company_dialog.dart`)
- **Enhanced Fields**: All company fields now editable
- **Comprehensive Layout**: Sectioned form with logical grouping
- **Data Persistence**: Full API integration with error handling
- **Status Management**: Company status and subscription plan editing

### Key Features
- 🌍 **Country-based currency auto-assignment**
- 📝 **VAT number format validation by country**
- 📧 **Email validation**
- 📱 **Phone number formatting**
- 🔄 **Real-time form validation**
- 💾 **Complete database persistence**
- 🎨 **Professional UI with sectioned layout**

## API Endpoints Tested

### Company Endpoints
- `POST /companies` - Create company
- `GET /companies?owner_email={email}` - Get companies by owner
- `GET /companies/{id}` - Get company by ID
- `PUT /companies/{id}` - Update company
- `DELETE /companies/{id}` - Delete company

### User Endpoints (Future Implementation)
- `POST /users` - Create user
- `GET /users` - Get all users
- `GET /users/{id}` - Get user by ID
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Delete user

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Ensure backend server is running on port 8000
   - Check if PostgreSQL database is accessible

2. **Test Failures**
   - Verify database schema matches expected structure
   - Check that all required fields are in companies table

3. **Environment Variables**
   - Ensure `base_url` is set correctly in environment
   - Check that test IDs are being stored properly

### Debug Tips

- Check Postman Console for detailed error messages
- Verify database state between test runs
- Use individual test execution for debugging specific scenarios

## Next Steps

1. **Implement User Endpoints** in backend to complete user testing
2. **Add Authentication Testing** for secured endpoints
3. **Performance Testing** with larger datasets
4. **Integration Testing** with frontend components
5. **Add Invoice/Expense** endpoint testing for complete coverage

## File Structure

```
backend/
├── PSC_Accounting_E2E_Tests.postman_collection.json     # Main test collection
├── PSC_Accounting_E2E.postman_environment.json          # Environment variables
└── README_E2E_TESTING.md                                # This documentation

lib/dialogs/
├── create_company_dialog.dart                           # Enhanced creation dialog
└── edit_company_dialog.dart                             # Enhanced editing dialog
```

## Contributing

When adding new endpoints or modifying existing ones:
1. Update the Postman collection with new tests
2. Add appropriate validation scenarios
3. Update this documentation
4. Ensure all tests pass before deployment

---

**Last Updated**: August 9, 2025  
**Collection Version**: 1.0.0  
**Environment**: Local Development
