-- DDL script to add missing company fields and ensure proper structure
-- Run this script to update the companies table with all required fields

-- Add missing columns to companies table if they don't exist
DO $$ 
BEGIN
    -- Add vat_number column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'vat_number') THEN
        ALTER TABLE public.companies ADD COLUMN vat_number VARCHAR(20);
        PRINT 'Added vat_number column to companies table';
    END IF;
    
    -- Add country column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'country') THEN
        ALTER TABLE public.companies ADD COLUMN country VARCHAR(64) DEFAULT 'Ireland';
        PRINT 'Added country column to companies table';
    END IF;
    
    -- Add currency column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'currency') THEN
        ALTER TABLE public.companies ADD COLUMN currency VARCHAR(10) DEFAULT 'EUR';
        PRINT 'Added currency column to companies table';
    END IF;
    
    -- Add is_demo column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'is_demo') THEN
        ALTER TABLE public.companies ADD COLUMN is_demo BOOLEAN DEFAULT FALSE;
        PRINT 'Added is_demo column to companies table';
    END IF;
    
    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'updated_at') THEN
        ALTER TABLE public.companies ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
        PRINT 'Added updated_at column to companies table';
    END IF;
    
    -- Add status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'status') THEN
        ALTER TABLE public.companies ADD COLUMN status VARCHAR(50) DEFAULT 'active';
        PRINT 'Added status column to companies table';
    END IF;
    
    -- Add owner_email column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'owner_email') THEN
        ALTER TABLE public.companies ADD COLUMN owner_email VARCHAR(255);
        PRINT 'Added owner_email column to companies table';
    END IF;
    
    -- Add phone column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'phone') THEN
        ALTER TABLE public.companies ADD COLUMN phone VARCHAR(50);
        PRINT 'Added phone column to companies table';
    END IF;
    
    -- Add address column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'address') THEN
        ALTER TABLE public.companies ADD COLUMN address TEXT;
        PRINT 'Added address column to companies table';
    END IF;
    
    -- Add subscription_plan column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'companies' AND column_name = 'subscription_plan') THEN
        ALTER TABLE public.companies ADD COLUMN subscription_plan VARCHAR(50);
        PRINT 'Added subscription_plan column to companies table';
    END IF;
    
END $$;

-- Update existing companies to have proper default values
UPDATE public.companies 
SET 
    country = COALESCE(country, 'Ireland'),
    currency = COALESCE(currency, 'EUR'),
    is_demo = COALESCE(is_demo, FALSE),
    status = COALESCE(status, 'active'),
    updated_at = COALESCE(updated_at, CURRENT_TIMESTAMP)
WHERE country IS NULL OR currency IS NULL OR is_demo IS NULL OR status IS NULL OR updated_at IS NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_companies_is_demo ON public.companies(is_demo);
CREATE INDEX IF NOT EXISTS idx_companies_status ON public.companies(status);
CREATE INDEX IF NOT EXISTS idx_companies_currency ON public.companies(currency);

-- Display current companies table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'companies' 
ORDER BY ordinal_position;
