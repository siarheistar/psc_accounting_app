-- Migration script to add S3 support to attachments table
-- Add new columns for storage backend configuration

-- Add storage backend columns
ALTER TABLE public.attachments 
ADD COLUMN IF NOT EXISTS storage_backend VARCHAR(20) DEFAULT 'local' NOT NULL;

ALTER TABLE public.attachments 
ADD COLUMN IF NOT EXISTS s3_bucket VARCHAR(255);

ALTER TABLE public.attachments 
ADD COLUMN IF NOT EXISTS s3_key VARCHAR(1024);

ALTER TABLE public.attachments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Create index for efficient queries by storage backend
CREATE INDEX IF NOT EXISTS idx_attachments_storage_backend 
ON public.attachments(storage_backend);

-- Create index for efficient S3 key lookups
CREATE INDEX IF NOT EXISTS idx_attachments_s3_key 
ON public.attachments(s3_key) WHERE s3_key IS NOT NULL;

-- Update existing records to have 'local' storage backend
UPDATE public.attachments 
SET storage_backend = 'local' 
WHERE storage_backend IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN public.attachments.storage_backend IS 'Storage backend type: local or s3';
COMMENT ON COLUMN public.attachments.s3_bucket IS 'S3 bucket name (only for s3 backend)';
COMMENT ON COLUMN public.attachments.s3_key IS 'S3 object key (only for s3 backend)';
COMMENT ON COLUMN public.attachments.updated_at IS 'Last modification timestamp';

-- Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_attachments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_attachments_updated_at ON public.attachments;
CREATE TRIGGER trigger_attachments_updated_at
    BEFORE UPDATE ON public.attachments
    FOR EACH ROW
    EXECUTE FUNCTION update_attachments_updated_at();
