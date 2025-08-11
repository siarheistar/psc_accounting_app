-- Simple migration script for attachments table
-- PSC Accounting App - Attachment Management System

-- Create the new attachments table
CREATE TABLE IF NOT EXISTS public.attachments (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER NOT NULL,
    company_id INTEGER NOT NULL,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    file_path TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_attachments_entity ON public.attachments (entity_type, entity_id, company_id);
CREATE INDEX IF NOT EXISTS idx_attachments_company ON public.attachments (company_id);
CREATE INDEX IF NOT EXISTS idx_attachments_category ON public.attachments (category);
CREATE INDEX IF NOT EXISTS idx_attachments_created ON public.attachments (created_at);

-- Add columns to existing document_attachments table if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='document_attachments' AND column_name='storage_type') THEN
        ALTER TABLE public.document_attachments ADD COLUMN storage_type VARCHAR(20) DEFAULT 'database';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='document_attachments' AND column_name='file_path') THEN
        ALTER TABLE public.document_attachments ADD COLUMN file_path TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='document_attachments' AND column_name='updated_at') THEN
        ALTER TABLE public.document_attachments ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attachments TO postgres;
GRANT USAGE, SELECT ON SEQUENCE attachments_id_seq TO postgres;
