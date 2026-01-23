-- Migration: Create technique_impacts table with RLS
-- Version: 20260122
-- Description: Stores user-tagged technique (hold type) impacts for climbs

-- Create table
CREATE TABLE IF NOT EXISTS public.technique_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES public.climbs(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL,
    impact TEXT NOT NULL CHECK (impact IN ('helped', 'hindered', 'neutral')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    -- Prevent duplicate tag per climb
    CONSTRAINT unique_technique_impact UNIQUE (climb_id, tag_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_technique_impacts_user_id ON technique_impacts(user_id);
CREATE INDEX IF NOT EXISTS idx_technique_impacts_climb_id ON technique_impacts(climb_id);
CREATE INDEX IF NOT EXISTS idx_technique_impacts_tag_id ON technique_impacts(tag_id);
CREATE INDEX IF NOT EXISTS idx_technique_impacts_updated_at ON technique_impacts(updated_at);

-- Enable RLS
ALTER TABLE technique_impacts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (idempotent)
DROP POLICY IF EXISTS "Users can view own technique impacts" ON technique_impacts;
DROP POLICY IF EXISTS "Users can insert own technique impacts" ON technique_impacts;
DROP POLICY IF EXISTS "Users can update own technique impacts" ON technique_impacts;
DROP POLICY IF EXISTS "Users can delete own technique impacts" ON technique_impacts;
DROP POLICY IF EXISTS "Authenticated users can view public session technique impacts" ON technique_impacts;

-- Create policies
CREATE POLICY "Users can view own technique impacts" ON technique_impacts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own technique impacts" ON technique_impacts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own technique impacts" ON technique_impacts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own technique impacts" ON technique_impacts
    FOR DELETE USING (auth.uid() = user_id);

-- View public impacts through public sessions
CREATE POLICY "Authenticated users can view public session technique impacts" ON technique_impacts
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM climbs
            JOIN sessions ON sessions.id = climbs.session_id
            WHERE climbs.id = technique_impacts.climb_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
            AND climbs.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_technique_impacts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS technique_impacts_updated_at_trigger ON technique_impacts;
CREATE TRIGGER technique_impacts_updated_at_trigger
    BEFORE UPDATE ON technique_impacts
    FOR EACH ROW
    EXECUTE FUNCTION update_technique_impacts_updated_at();
