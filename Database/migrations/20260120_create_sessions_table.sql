-- Migration: Create sessions table with RLS
-- Version: 20260120
-- Description: Sets up the sessions table for climbing session tracking

-- Create table (idempotent)
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    mental_readiness SMALLINT CHECK (mental_readiness >= 1 AND mental_readiness <= 5),
    physical_readiness SMALLINT CHECK (physical_readiness >= 1 AND physical_readiness <= 5),
    rpe SMALLINT CHECK (rpe >= 1 AND rpe <= 10),
    pump_level SMALLINT CHECK (pump_level >= 1 AND pump_level <= 5),
    notes TEXT,
    is_private BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT valid_end_time CHECK (ended_at IS NULL OR ended_at > started_at)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_active ON sessions(user_id)
    WHERE ended_at IS NULL AND deleted_at IS NULL;

-- Enable RLS
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (for idempotent re-runs)
DROP POLICY IF EXISTS "Users can view own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON sessions;
DROP POLICY IF EXISTS "Authenticated users can view public sessions" ON sessions;

-- Create policies
CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions" ON sessions
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can view public sessions" ON sessions
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND is_private = false
        AND deleted_at IS NULL
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sessions_updated_at_trigger ON sessions;
CREATE TRIGGER sessions_updated_at_trigger
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_sessions_updated_at();
