-- VAT Enhancement Script for PSC Accounting (Public Schema)
-- This script adds comprehensive VAT handling and enhanced expense categories
-- Compatible with existing public schema using integer company IDs

SET search_path TO public;

-- 1. Create VAT Rates Configuration Table
CREATE TABLE IF NOT EXISTS public.vat_rates (
    id SERIAL PRIMARY KEY,
    country VARCHAR(64) NOT NULL DEFAULT 'Ireland',
    rate_name VARCHAR(50) NOT NULL, -- 'Standard', 'Reduced', 'Zero', 'Exempt'
    rate_percentage NUMERIC(5,2) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Insert Irish VAT Rates (as per Revenue requirements)
INSERT INTO public.vat_rates (country, rate_name, rate_percentage, description) VALUES
('Ireland', 'Standard', 23.00, 'Standard VAT rate for most goods and services'),
('Ireland', 'Reduced', 13.50, 'Reduced rate for certain goods and services'),
('Ireland', 'Second Reduced', 9.00, 'Second reduced rate for tourism, newspapers, etc.'),
('Ireland', 'Zero', 0.00, 'Zero rate for exports, certain foods, books, etc.'),
('Ireland', 'Exempt', 0.00, 'Exempt supplies (education, health, insurance, etc.)'),
('Ireland', 'Home Office', 0.00, 'Home office usage - non-deductible VAT'),
('EU', 'Reverse Charge', 0.00, 'EU B2B transactions - reverse charge mechanism'),
('Non-EU', 'Import VAT', 21.00, 'Import VAT on goods from non-EU countries')
ON CONFLICT DO NOTHING;

-- 3. Create Enhanced Expense Categories Table
CREATE TABLE IF NOT EXISTS public.expense_categories (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    category_type VARCHAR(50) NOT NULL, -- 'general', 'eworker', 'mileage', 'subsistence'
    default_vat_rate_id INTEGER REFERENCES public.vat_rates(id),
    supports_business_usage BOOLEAN DEFAULT FALSE,
    default_business_usage NUMERIC(5,2) DEFAULT 100.00, -- Percentage
    requires_receipt BOOLEAN DEFAULT TRUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Insert Enhanced Expense Categories
INSERT INTO public.expense_categories (category_name, category_type, supports_business_usage, default_business_usage, requires_receipt, description) VALUES
-- General Business Expenses
('Office Supplies', 'general', FALSE, 100.00, TRUE, 'Stationery, printer supplies, etc.'),
('Professional Services', 'general', FALSE, 100.00, TRUE, 'Legal, accounting, consultancy fees'),
('Software & Subscriptions', 'general', FALSE, 100.00, TRUE, 'Business software licenses and subscriptions'),
('Marketing & Advertising', 'general', FALSE, 100.00, TRUE, 'Website, ads, promotional materials'),
('Training & Development', 'general', FALSE, 100.00, TRUE, 'Courses, seminars, professional development'),

-- Expenses with Business Usage Options
('Internet & Broadband', 'general', TRUE, 100.00, TRUE, 'Internet connection costs'),
('Mobile Phone', 'general', TRUE, 75.00, TRUE, 'Mobile phone bills and costs'),
('Landline Phone', 'general', TRUE, 100.00, TRUE, 'Landline telephone costs'),
('Utilities - Electricity', 'general', TRUE, 25.00, TRUE, 'Home office electricity usage'),
('Utilities - Gas/Heating', 'general', TRUE, 25.00, TRUE, 'Home office heating costs'),
('Home Office Equipment', 'general', TRUE, 100.00, TRUE, 'Desk, chair, computer equipment for home office'),
('Rent - Home Office', 'general', TRUE, 10.00, TRUE, 'Portion of rent for home office use'),

-- E-Worker Specific Categories
('E-Worker Rate', 'eworker', FALSE, 100.00, FALSE, 'Daily/hourly rate for e-worker services'),
('E-Worker Expenses', 'eworker', FALSE, 100.00, TRUE, 'Reimbursable expenses for e-worker'),

-- Mileage Categories
('Business Mileage', 'mileage', FALSE, 100.00, FALSE, 'Mileage for business trips'),
('Client Visit Mileage', 'mileage', FALSE, 100.00, FALSE, 'Mileage for client visits'),

-- Subsistence Categories
('Business Meals', 'subsistence', FALSE, 100.00, TRUE, 'Meals during business travel'),
('Accommodation', 'subsistence', FALSE, 100.00, TRUE, 'Hotel and accommodation costs'),
('Travel Expenses', 'subsistence', FALSE, 100.00, TRUE, 'Transport costs for business travel')
ON CONFLICT DO NOTHING;

-- 5. Create Business Usage Percentage Options Table
CREATE TABLE IF NOT EXISTS public.business_usage_options (
    id SERIAL PRIMARY KEY,
    percentage NUMERIC(5,2) NOT NULL,
    label VARCHAR(20) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE
);

-- Insert Business Usage Percentage Options
INSERT INTO public.business_usage_options (percentage, label, description, is_default) VALUES
(100.00, '100%', 'Full business use', TRUE),
(75.00, '75%', 'Mostly business use', FALSE),
(50.00, '50%', 'Half business use', FALSE),
(25.00, '25%', 'Limited business use', FALSE),
(10.00, '10%', 'Minimal business use', FALSE),
(0.00, '0%', 'Personal use only', FALSE)
ON CONFLICT DO NOTHING;

-- 6. Update Expenses Table to Support Enhanced Features (if it exists)
-- First check if expenses table exists and get its current structure
DO $$
BEGIN
    -- Add new columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'category_id') THEN
        ALTER TABLE public.expenses ADD COLUMN category_id INTEGER REFERENCES public.expense_categories(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'vat_rate_id') THEN
        ALTER TABLE public.expenses ADD COLUMN vat_rate_id INTEGER REFERENCES public.vat_rates(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'business_usage_percentage') THEN
        ALTER TABLE public.expenses ADD COLUMN business_usage_percentage NUMERIC(5,2) DEFAULT 100.00;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'deductible_amount') THEN
        ALTER TABLE public.expenses ADD COLUMN deductible_amount NUMERIC(10,2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'expense_type') THEN
        ALTER TABLE public.expenses ADD COLUMN expense_type VARCHAR(50) DEFAULT 'general';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'eworker_days') THEN
        ALTER TABLE public.expenses ADD COLUMN eworker_days NUMERIC(5,2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'eworker_rate') THEN
        ALTER TABLE public.expenses ADD COLUMN eworker_rate NUMERIC(8,2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'mileage_km') THEN
        ALTER TABLE public.expenses ADD COLUMN mileage_km NUMERIC(8,2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'mileage_rate') THEN
        ALTER TABLE public.expenses ADD COLUMN mileage_rate NUMERIC(6,4) DEFAULT 0.3708;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'receipt_required') THEN
        ALTER TABLE public.expenses ADD COLUMN receipt_required BOOLEAN DEFAULT TRUE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'expenses' AND column_name = 'notes') THEN
        ALTER TABLE public.expenses ADD COLUMN notes TEXT;
    END IF;
END $$;

-- 7. Update Invoices Table for Enhanced VAT Support (if it exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoices' AND column_name = 'vat_rate_id') THEN
        ALTER TABLE public.invoices ADD COLUMN vat_rate_id INTEGER REFERENCES public.vat_rates(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoices' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.invoices ADD COLUMN invoice_type VARCHAR(50) DEFAULT 'standard';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoices' AND column_name = 'customer_vat_number') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_vat_number VARCHAR(30);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invoices' AND column_name = 'customer_country') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_country VARCHAR(64) DEFAULT 'Ireland';
    END IF;
END $$;

-- 8. Create E-Worker Periods Table (with INTEGER company_id)
CREATE TABLE IF NOT EXISTS public.eworker_periods (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES public.companies(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_days NUMERIC(5,2),
    daily_rate NUMERIC(8,2),
    total_amount NUMERIC(10,2),
    status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'logged', 'paid'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Create Mileage Log Table (with INTEGER company_id and expense_id)
CREATE TABLE IF NOT EXISTS public.mileage_log (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES public.companies(id) ON DELETE CASCADE,
    expense_id INTEGER REFERENCES public.expenses(id) ON DELETE CASCADE,
    trip_date DATE NOT NULL,
    from_location VARCHAR(255),
    to_location VARCHAR(255),
    purpose TEXT,
    km_distance NUMERIC(8,2),
    rate_per_km NUMERIC(6,4),
    total_amount NUMERIC(8,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON public.expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_vat_rate_id ON public.expenses(vat_rate_id);
CREATE INDEX IF NOT EXISTS idx_expenses_expense_type ON public.expenses(expense_type);
CREATE INDEX IF NOT EXISTS idx_invoices_vat_rate_id ON public.invoices(vat_rate_id);
CREATE INDEX IF NOT EXISTS idx_eworker_periods_company_id ON public.eworker_periods(company_id);
CREATE INDEX IF NOT EXISTS idx_mileage_log_company_id ON public.mileage_log(company_id);

-- 11. Create Views for Easy Data Access
CREATE OR REPLACE VIEW public.v_expenses_with_categories AS
SELECT 
    e.*,
    ec.category_name,
    ec.category_type,
    ec.supports_business_usage,
    vr.rate_name as vat_rate_name,
    vr.rate_percentage as vat_rate_percentage,
    CASE 
        WHEN e.expense_type = 'eworker' THEN e.eworker_days * e.eworker_rate
        WHEN e.expense_type = 'mileage' THEN e.mileage_km * e.mileage_rate
        ELSE e.amount
    END as calculated_net_amount
FROM public.expenses e
LEFT JOIN public.expense_categories ec ON e.category_id = ec.id
LEFT JOIN public.vat_rates vr ON e.vat_rate_id = vr.id;

CREATE OR REPLACE VIEW public.v_invoices_with_vat AS
SELECT 
    i.*,
    vr.rate_name as vat_rate_name,
    vr.rate_percentage as vat_rate_percentage
FROM public.invoices i
LEFT JOIN public.vat_rates vr ON i.vat_rate_id = vr.id;

-- 12. Insert sample data to link existing records (if they exist)
DO $$
BEGIN
    -- Only update if expenses table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expenses' AND table_schema = 'public') THEN
        UPDATE public.expenses 
        SET vat_rate_id = (SELECT id FROM public.vat_rates WHERE rate_name = 'Standard' AND country = 'Ireland' LIMIT 1)
        WHERE vat_rate_id IS NULL;
    END IF;
    
    -- Only update if invoices table exists  
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoices' AND table_schema = 'public') THEN
        UPDATE public.invoices 
        SET vat_rate_id = (SELECT id FROM public.vat_rates WHERE rate_name = 'Standard' AND country = 'Ireland' LIMIT 1)
        WHERE vat_rate_id IS NULL;
    END IF;
END $$;

-- 13. Create function to calculate VAT amount based on rate_id
CREATE OR REPLACE FUNCTION public.calculate_vat_amount(net_amount NUMERIC, vat_rate_id INTEGER)
RETURNS NUMERIC AS $$
DECLARE
    vat_percentage NUMERIC;
BEGIN
    SELECT rate_percentage INTO vat_percentage 
    FROM public.vat_rates 
    WHERE id = vat_rate_id AND is_active = TRUE;
    
    IF vat_percentage IS NULL THEN
        vat_percentage := 23.00; -- Default to standard rate
    END IF;
    
    RETURN ROUND(net_amount * vat_percentage / 100, 2);
END;
$$ LANGUAGE plpgsql;

-- 14. Add trigger to automatically calculate deductible_amount
CREATE OR REPLACE FUNCTION public.calculate_deductible_amount()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate deductible amount based on business usage percentage
    NEW.deductible_amount := ROUND(NEW.amount * NEW.business_usage_percentage / 100, 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger if expenses table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expenses' AND table_schema = 'public') THEN
        -- Drop trigger if it exists
        DROP TRIGGER IF EXISTS trigger_calculate_deductible_amount ON public.expenses;
        -- Create the trigger
        CREATE TRIGGER trigger_calculate_deductible_amount
            BEFORE INSERT OR UPDATE ON public.expenses
            FOR EACH ROW
            EXECUTE FUNCTION public.calculate_deductible_amount();
    END IF;
END $$;

COMMIT;