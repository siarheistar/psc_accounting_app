-- Add VAT amount columns to invoices and expenses tables
-- This script adds the missing net_amount, vat_amount, and gross_amount columns

-- Update invoices table
ALTER TABLE public.invoices 
ADD COLUMN IF NOT EXISTS net_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS vat_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS gross_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS description TEXT;

-- Update expenses table  
ALTER TABLE public.expenses
ADD COLUMN IF NOT EXISTS vat_rate NUMERIC(5,2),
ADD COLUMN IF NOT EXISTS net_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS vat_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS gross_amount NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending';

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_invoices_net_amount ON public.invoices(net_amount);
CREATE INDEX IF NOT EXISTS idx_invoices_gross_amount ON public.invoices(gross_amount);
CREATE INDEX IF NOT EXISTS idx_expenses_net_amount ON public.expenses(net_amount);
CREATE INDEX IF NOT EXISTS idx_expenses_gross_amount ON public.expenses(gross_amount);

-- Add comments for documentation
COMMENT ON COLUMN public.invoices.net_amount IS 'Amount excluding VAT';
COMMENT ON COLUMN public.invoices.vat_amount IS 'VAT amount calculated';
COMMENT ON COLUMN public.invoices.gross_amount IS 'Total amount including VAT';
COMMENT ON COLUMN public.expenses.vat_rate IS 'VAT rate percentage (e.g., 23.00 for 23%)';
COMMENT ON COLUMN public.expenses.net_amount IS 'Amount excluding VAT';
COMMENT ON COLUMN public.expenses.vat_amount IS 'VAT amount calculated';
COMMENT ON COLUMN public.expenses.gross_amount IS 'Total amount including VAT';

PRINT 'VAT amount columns added successfully to invoices and expenses tables';