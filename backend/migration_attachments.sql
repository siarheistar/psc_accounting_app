-- Migration script to create attachments table and migrate existing documents
-- PSC Accounting App - Attachment Management System

-- Create the new attachments table
CREATE TABLE IF NOT EXISTS public.attachments (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,                    -- 'invoice', 'expense', 'payroll', 'bank_statement'
    entity_id INTEGER NOT NULL,                          -- ID of the related entity
    company_id INTEGER NOT NULL,                         -- Company ID
    filename VARCHAR(255) NOT NULL,                      -- Unique filename on disk
    original_filename VARCHAR(255) NOT NULL,             -- Original filename from upload
    file_size BIGINT NOT NULL,                          -- File size in bytes
    mime_type VARCHAR(100) NOT NULL,                    -- MIME type (application/pdf, image/jpeg, etc.)
    category VARCHAR(50) NOT NULL,                      -- File category (document, image, spreadsheet, etc.)
    file_path TEXT NOT NULL,                            -- Relative path from attachments directory
    description TEXT,                                   -- Optional description
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    CONSTRAINT attachments_entity_fk FOREIGN KEY (entity_type, entity_id, company_id) 
        REFERENCES (entity_type, entity_id, company_id) DEFERRABLE,
    INDEX idx_attachments_entity (entity_type, entity_id, company_id),
    INDEX idx_attachments_company (company_id),
    INDEX idx_attachments_category (category),
    INDEX idx_attachments_created (created_at)
);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_attachments_updated_at 
    BEFORE UPDATE ON public.attachments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add a storage_type column to existing document_attachments table to track migration status
ALTER TABLE public.document_attachments 
ADD COLUMN IF NOT EXISTS storage_type VARCHAR(20) DEFAULT 'database';

ALTER TABLE public.document_attachments 
ADD COLUMN IF NOT EXISTS file_path TEXT;

ALTER TABLE public.document_attachments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Create trigger for document_attachments updated_at
CREATE TRIGGER update_document_attachments_updated_at 
    BEFORE UPDATE ON public.document_attachments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data (optional - remove in production)
-- This shows how attachments would be linked to entities
/*
INSERT INTO public.attachments 
(entity_type, entity_id, company_id, filename, original_filename, file_size, mime_type, category, file_path, description)
VALUES 
('invoice', 1, 1, '20250807_123456_abc123.pdf', 'invoice_001.pdf', 1024000, 'application/pdf', 'document', 'document/company_1/invoice/20250807_123456_abc123.pdf', 'Invoice supporting document'),
('expense', 1, 1, '20250807_123457_def456.jpg', 'receipt.jpg', 512000, 'image/jpeg', 'image', 'image/company_1/expense/20250807_123457_def456.jpg', 'Expense receipt photo'),
('payroll', 1, 1, '20250807_123458_ghi789.xlsx', 'payroll_report.xlsx', 2048000, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'spreadsheet', 'spreadsheet/company_1/payroll/20250807_123458_ghi789.xlsx', 'Payroll calculation spreadsheet');
*/

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attachments TO postgres;
GRANT USAGE, SELECT ON SEQUENCE attachments_id_seq TO postgres;

-- Print migration information
SELECT 'Attachments table created successfully' as status;

-- Show current document_attachments that need migration
SELECT 
    COUNT(*) as total_documents,
    storage_type,
    SUM(file_size) as total_size_bytes
FROM public.document_attachments 
GROUP BY storage_type;
