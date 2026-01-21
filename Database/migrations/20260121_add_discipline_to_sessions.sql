-- Migration: Add discipline column to sessions table
-- Version: 20260121
-- Description: Sessions now require a discipline selection

-- Add discipline column (nullable initially for migration)
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS discipline TEXT;

-- Set default for existing sessions (bouldering as safe default)
UPDATE public.sessions
SET discipline = 'bouldering'
WHERE discipline IS NULL;

-- Make column non-nullable
ALTER TABLE public.sessions
ALTER COLUMN discipline SET NOT NULL;

-- Add check constraint
ALTER TABLE public.sessions
ADD CONSTRAINT valid_discipline
CHECK (discipline IN ('bouldering', 'sport', 'trad', 'top_rope'));

-- Create index for filtering by discipline
CREATE INDEX IF NOT EXISTS idx_sessions_discipline ON sessions(discipline);
