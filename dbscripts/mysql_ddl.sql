-- Create database (schema)
CREATE DATABASE IF NOT EXISTS pscdb;
USE pscdb;

-- 1. Users
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    firebase_uid VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Companies
CREATE TABLE companies (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36),
    name VARCHAR(255) NOT NULL,
    vat_number VARCHAR(20),
    country VARCHAR(64) DEFAULT 'Ireland',
    currency VARCHAR(10) DEFAULT 'EUR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 3. Invoices
CREATE TABLE invoices (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    company_id CHAR(36),
    invoice_number VARCHAR(50) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    customer_name VARCHAR(255),
    net_amount DECIMAL(10,2) NOT NULL,
    vat_rate DECIMAL(5,2) DEFAULT 23.00,
    vat_amount DECIMAL(10,2) GENERATED ALWAYS AS (net_amount * vat_rate / 100) STORED,
    gross_amount DECIMAL(10,2) GENERATED ALWAYS AS (net_amount + (net_amount * vat_rate / 100)) STORED,
    paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

-- 4. Expenses
CREATE TABLE expenses (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    company_id CHAR(36),
    expense_date DATE NOT NULL,
    category VARCHAR(100),
    description TEXT,
    net_amount DECIMAL(10,2) NOT NULL,
    vat_rate DECIMAL(5,2) DEFAULT 23.00,
    vat_amount DECIMAL(10,2) GENERATED ALWAYS AS (net_amount * vat_rate / 100) STORED,
    gross_amount DECIMAL(10,2) GENERATED ALWAYS AS (net_amount + (net_amount * vat_rate / 100)) STORED,
    supplier_name VARCHAR(255),
    paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

-- 5. Bank Statements
CREATE TABLE bank_statements (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    company_id CHAR(36),
    statement_date DATE NOT NULL,
    transaction_type VARCHAR(50),
    description TEXT,
    amount DECIMAL(10,2),
    balance DECIMAL(10,2),
    reference VARCHAR(255),
    reconciled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

-- 6. Reconciliations
CREATE TABLE reconciliations (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    bank_statement_id CHAR(36),
    invoice_id CHAR(36),
    expense_id CHAR(36),
    reconciled_by CHAR(36),
    reconciled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bank_statement_id) REFERENCES bank_statements(id) ON DELETE CASCADE,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
    FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE SET NULL,
    FOREIGN KEY (reconciled_by) REFERENCES users(id)
);

-- 7. VAT Returns
CREATE TABLE vat_returns (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    company_id CHAR(36),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_sales DECIMAL(12,2),
    total_output_vat DECIMAL(12,2),
    total_purchases DECIMAL(12,2),
    total_input_vat DECIMAL(12,2),
    net_vat_due DECIMAL(12,2),
    submitted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

-- 8. Attachments
CREATE TABLE attachments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    related_type VARCHAR(50) NOT NULL,
    related_id CHAR(36) NOT NULL,
    filename VARCHAR(255),
    file_url TEXT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);