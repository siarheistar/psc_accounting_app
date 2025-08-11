# PSC Accounting Application

A comprehensive financial management application built with Flutter (frontend) and FastAPI (backend), designed for small to medium businesses to manage their accounting operations.

## 🚀 Features

### Core Functionality
- **Invoice Management**: Create, read, update, and delete invoices with client tracking
- **Expense Tracking**: Comprehensive expense management with categorization
- **Payroll Management**: Employee payroll processing and management
- **Bank Statement Integration**: Import and manage bank statements
- **Dashboard Analytics**: Real-time financial metrics and reporting

### Technical Features
- **Multi-platform**: Flutter app supports iOS, Android, Web, macOS, Windows, and Linux
- **RESTful API**: FastAPI backend with comprehensive endpoints
- **Database Support**: PostgreSQL and MySQL database schemas
- **Authentication**: Firebase Authentication integration
- **Comprehensive Testing**: Full Postman API test suite with 43+ tests
- **CRUD Operations**: Complete Create, Read, Update, Delete functionality for all entities

## 🏗️ Architecture

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **State Management**: Provider pattern
- **Authentication**: Firebase Auth
- **UI Components**: Material Design
- **Platforms**: iOS, Android, Web, Desktop

### Backend (FastAPI)
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL/MySQL
- **API Documentation**: Auto-generated OpenAPI/Swagger
- **Authentication**: Firebase Admin SDK
- **Testing**: Postman collection with environment

### Database
- **Primary**: PostgreSQL
- **Alternative**: MySQL
- **Schemas**: Pre-built DDL scripts included
- **Tables**: Companies, Users, Invoices, Expenses, Payroll, Bank Statements

## 📦 Project Structure

```
psc_accounting_app/
├── lib/                    # Flutter application source
│   ├── auth/              # Authentication screens and logic
│   ├── pages/             # Main application pages
│   ├── services/          # API and business logic services
│   ├── models/            # Data models
│   ├── widgets/           # Reusable UI components
│   └── main.dart          # Application entry point
├── backend/               # FastAPI backend
│   ├── main.py           # FastAPI application and endpoints
│   ├── database.py       # Database connection and utilities
│   ├── requirements.txt  # Python dependencies
│   └── *.postman_*       # Postman test collections
├── dbscripts/            # Database schema scripts
│   ├── postgresql_ddl.sql
│   └── mysql_ddl.sql
└── assets/               # Static assets
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Python 3.8+
- PostgreSQL or MySQL
- Node.js (for some development tools)

### Backend Setup
1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up environment variables:
   ```bash
   # For development
   cp .env.development .env
   # OR use the automated setup script
   ./setup_secrets.sh
   # Edit .env with your actual database credentials
   ```

4. Run database migrations:
   ```bash
   python create_tables.py
   ```

5. Start the backend server:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

### Frontend Setup
1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```

### Database Setup
1. Create a PostgreSQL/MySQL database
2. Run the appropriate DDL script from `dbscripts/`
3. Update database connection settings in backend configuration

## 🧪 Testing

### API Testing with Postman
The project includes a comprehensive Postman collection with 43+ tests:

1. Import `backend/PSC_Accounting_API.postman_collection.json`
2. Import `backend/PSC_Accounting_Local.postman_environment.json`
3. Run the collection to test all endpoints

### Test Coverage
- ✅ Authentication flow
- ✅ CRUD operations for all entities
- ✅ Dashboard metrics and analytics
- ✅ Error handling and edge cases
- ✅ Dynamic state management tests

## 📊 API Endpoints

### Core Entities
- `GET/POST /companies` - Company management
- `GET/POST/PUT/DELETE /invoices` - Invoice operations
- `GET/POST/PUT/DELETE /expenses` - Expense management
- `GET/POST/PUT/DELETE /payroll` - Payroll processing
- `GET/POST/PUT/DELETE /bank-statements` - Bank statement management

### Analytics
- `GET /dashboard/metrics` - Financial dashboard data
- `GET /dashboard/{company_id}` - Company-specific metrics

### Utilities
- `GET /health` - API health check
- `GET /employees` - Employee list from payroll data

## 🛠️ Development

### Current Status
- ✅ Complete CRUD functionality for all entities
- ✅ Working FastAPI backend with PostgreSQL
- ✅ Flutter frontend with Firebase authentication
- ✅ Comprehensive API test suite
- ✅ Database schemas and migrations
- ✅ Dynamic testing with state management

### Development Branch
- **Main Branch**: `master` - Stable releases
- **Feature Branch**: `feat/initial` - Current development

## 📝 Environment Configuration

### Environment Setup
The project uses environment-specific configuration files:
- `.env.development` - Development settings (local database, debug enabled)
- `.env.staging` - Staging environment settings
- `.env.production` - Production settings (secure, optimized)
- `.env.example` - Generic template

### Automated Setup
Use the included setup script for secure configuration:
```bash
./setup_secrets.sh
```

### Manual Setup
```bash
cd backend/
cp .env.development .env  # For development
# Edit .env with your actual credentials
```

### Key Environment Variables
```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=psc_accounting_dev
DB_USER=postgres
DB_PASSWORD=your-password

# Application Settings
ENVIRONMENT=development
DEBUG=true
API_PORT=8000

# Security (auto-generated for production)
JWT_SECRET=your-jwt-secret
API_SECRET_KEY=your-api-secret
```

### Firebase Configuration
- Set up Firebase project for authentication
- Download service account credentials
- Configure Firebase in Flutter app

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🏢 About PSC

This application is designed for PSC (Professional Services Company) accounting needs, providing a comprehensive solution for financial management, reporting, and business analytics.

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the documentation in the `backend/` directory
- Review the Postman collection for API examples

---

**Repository**: https://github.com/siarheistar/psc_accounting_app  
**Demo**: Available on request  
**Documentation**: See `/backend/README.md` for detailed API documentation
