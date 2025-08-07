CREATE SCHEMA IF NOT EXISTS prod;
SET search_path TO prod;


-- 1. Users
CREATE TABLE prod.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Companies
CREATE TABLE prod.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES prod.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    vat_number VARCHAR(20),
    country VARCHAR(64) DEFAULT 'Ireland',
    currency VARCHAR(10) DEFAULT 'EUR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Invoices
CREATE TABLE prod.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES prod.companies(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    customer_name VARCHAR(255),
    net_amount NUMERIC(10,2) NOT NULL,
    vat_rate NUMERIC(5,2) DEFAULT 23.00,
    vat_amount NUMERIC(10,2) GENERATED ALWAYS AS (net_amount * vat_rate / 100) STORED,
    gross_amount NUMERIC(10,2) GENERATED ALWAYS AS (net_amount + (net_amount * vat_rate / 100)) STORED,
    paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Expenses
CREATE TABLE prod.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES prod.companies(id) ON DELETE CASCADE,
    expense_date DATE NOT NULL,
    category VARCHAR(100),
    description TEXT,
    net_amount NUMERIC(10,2) NOT NULL,
    vat_rate NUMERIC(5,2) DEFAULT 23.00,
    vat_amount NUMERIC(10,2) GENERATED ALWAYS AS (net_amount * vat_rate / 100) STORED,
    gross_amount NUMERIC(10,2) GENERATED ALWAYS AS (net_amount + (net_amount * vat_rate / 100)) STORED,
    supplier_name VARCHAR(255),
    paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Bank Statements
CREATE TABLE prod.bank_statements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES prod.companies(id) ON DELETE CASCADE,
    statement_date DATE NOT NULL,
    transaction_type VARCHAR(50),
    description TEXT,
    amount NUMERIC(10,2),
    balance NUMERIC(10,2),
    reference VARCHAR(255),
    reconciled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Reconciliations
CREATE TABLE prod.reconciliations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_statement_id UUID REFERENCES prod.bank_statements(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES prod.invoices(id) ON DELETE SET NULL,
    expense_id UUID REFERENCES prod.expenses(id) ON DELETE SET NULL,
    reconciled_by UUID REFERENCES prod.users(id),
    reconciled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. VAT Returns
CREATE TABLE prod.vat_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES prod.companies(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_sales NUMERIC(12,2),
    total_output_vat NUMERIC(12,2),
    total_purchases NUMERIC(12,2),
    total_input_vat NUMERIC(12,2),
    net_vat_due NUMERIC(12,2),
    submitted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Payroll
CREATE TABLE prod.payroll (
    id SERIAL PRIMARY KEY,
    company_id VARCHAR(36) NOT NULL,
    period VARCHAR(100),
    employee_name VARCHAR(255),
    gross_pay NUMERIC(10,2),
    deductions NUMERIC(10,2),
    net_pay NUMERIC(10,2),
    pay_date DATE,
    employee_id VARCHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Employees
CREATE TABLE prod.employees (
    id SERIAL PRIMARY KEY,
    company_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone_number VARCHAR(20),
    position VARCHAR(100),
    department VARCHAR(100),
    base_salary NUMERIC(10,2),
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. Attachments
CREATE TABLE prod.attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    related_type VARCHAR(50) NOT NULL,
    related_id UUID NOT NULL,
    filename VARCHAR(255),
    file_url TEXT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);