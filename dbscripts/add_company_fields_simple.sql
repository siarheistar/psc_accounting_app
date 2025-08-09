-- Simple DDL script to add missing company fields
-- Run this script to ensure companies table has all required columns

-- Add missing columns (will be ignored if they already exist)
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS vat_number VARCHAR(20);
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS country VARCHAR(64) DEFAULT 'Ireland';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'EUR';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS is_demo BOOLEAN DEFAULT FALSE;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS owner_email VARCHAR(255);
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS subscription_plan VARCHAR(50);
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS slug VARCHAR(255);

-- Update existing companies to have proper default values
UPDATE public.companies 
SET 
    country = COALESCE(country, 'Ireland'),
    currency = COALESCE(currency, 'EUR'),
    is_demo = COALESCE(is_demo, FALSE),
    status = COALESCE(status, 'active'),
    updated_at = COALESCE(updated_at, CURRENT_TIMESTAMP)
WHERE country IS NULL OR currency IS NULL OR is_demo IS NULL OR status IS NULL OR updated_at IS NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_companies_is_demo ON public.companies(is_demo);
CREATE INDEX IF NOT EXISTS idx_companies_status ON public.companies(status);
CREATE INDEX IF NOT EXISTS idx_companies_currency ON public.companies(currency);
CREATE INDEX IF NOT EXISTS idx_companies_slug ON public.companies(slug);

-- Show the current structure
\d public.companies;
