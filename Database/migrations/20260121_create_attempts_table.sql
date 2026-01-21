-- Migration: Create attempts table with RLS
-- Version: 20260121
-- Description: Sets up the attempts table for tracking individual climb attempts

-- Create table
CREATE TABLE IF NOT EXISTS public.attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES public.climbs(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number >= 1),
    outcome TEXT NOT NULL CHECK (outcome IN ('try', 'send')),
    send_type TEXT CHECK (send_type IN ('onsight', 'flash', 'redpoint', 'pinkpoint', 'project')),
    occurred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    -- Only allow send_type when outcome is 'send'
    CONSTRAINT send_type_requires_send CHECK (
        (outcome = 'send' AND send_type IS NOT NULL) OR
        (outcome = 'try' AND send_type IS NULL)
    ),

    -- Unique attempt number per climb
    CONSTRAINT unique_attempt_number UNIQUE (climb_id, attempt_number)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_session_id ON attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_attempts_climb_id ON attempts(climb_id);
CREATE INDEX IF NOT EXISTS idx_attempts_created_at ON attempts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_attempts_updated_at ON attempts(updated_at);

-- Enable RLS
ALTER TABLE attempts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can insert own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can update own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can delete own attempts" ON attempts;
DROP POLICY IF EXISTS "Authenticated users can view public session attempts" ON attempts;

-- Create policies
CREATE POLICY "Users can view own attempts" ON attempts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own attempts" ON attempts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own attempts" ON attempts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own attempts" ON attempts
    FOR DELETE USING (auth.uid() = user_id);

-- View public attempts through public sessions
CREATE POLICY "Authenticated users can view public session attempts" ON attempts
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM sessions
            WHERE sessions.id = attempts.session_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_attempts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS attempts_updated_at_trigger ON attempts;
CREATE TRIGGER attempts_updated_at_trigger
    BEFORE UPDATE ON attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_attempts_updated_at();
