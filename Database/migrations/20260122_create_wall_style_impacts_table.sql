-- Migration: Create wall_style_impacts table with RLS
-- Version: 20260122
-- Description: Stores user-tagged wall style impacts for climbs

-- Create table
CREATE TABLE IF NOT EXISTS public.wall_style_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES public.climbs(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL,
    impact TEXT NOT NULL CHECK (impact IN ('helped', 'hindered', 'neutral')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    -- Prevent duplicate tag per climb
    CONSTRAINT unique_wall_style_impact UNIQUE (climb_id, tag_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_wall_style_impacts_user_id ON wall_style_impacts(user_id);
CREATE INDEX IF NOT EXISTS idx_wall_style_impacts_climb_id ON wall_style_impacts(climb_id);
CREATE INDEX IF NOT EXISTS idx_wall_style_impacts_tag_id ON wall_style_impacts(tag_id);
CREATE INDEX IF NOT EXISTS idx_wall_style_impacts_updated_at ON wall_style_impacts(updated_at);

-- Enable RLS
ALTER TABLE wall_style_impacts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (idempotent)
DROP POLICY IF EXISTS "Users can view own wall style impacts" ON wall_style_impacts;
DROP POLICY IF EXISTS "Users can insert own wall style impacts" ON wall_style_impacts;
DROP POLICY IF EXISTS "Users can update own wall style impacts" ON wall_style_impacts;
DROP POLICY IF EXISTS "Users can delete own wall style impacts" ON wall_style_impacts;
DROP POLICY IF EXISTS "Authenticated users can view public session wall style impacts" ON wall_style_impacts;

-- Create policies
CREATE POLICY "Users can view own wall style impacts" ON wall_style_impacts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wall style impacts" ON wall_style_impacts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wall style impacts" ON wall_style_impacts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wall style impacts" ON wall_style_impacts
    FOR DELETE USING (auth.uid() = user_id);

-- View public impacts through public sessions
CREATE POLICY "Authenticated users can view public session wall style impacts" ON wall_style_impacts
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM climbs
            JOIN sessions ON sessions.id = climbs.session_id
            WHERE climbs.id = wall_style_impacts.climb_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
            AND climbs.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_wall_style_impacts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS wall_style_impacts_updated_at_trigger ON wall_style_impacts;
CREATE TRIGGER wall_style_impacts_updated_at_trigger
    BEFORE UPDATE ON wall_style_impacts
    FOR EACH ROW
    EXECUTE FUNCTION update_wall_style_impacts_updated_at();
