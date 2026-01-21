-- Migration: Create climbs table with RLS
-- Version: 20260121
-- Description: Sets up the climbs table for individual climb tracking within sessions

-- Create table
CREATE TABLE IF NOT EXISTS public.climbs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    discipline TEXT NOT NULL CHECK (discipline IN ('bouldering', 'sport', 'trad', 'top_rope')),
    is_outdoor BOOLEAN NOT NULL DEFAULT false,
    name TEXT,
    grade_original TEXT,
    grade_scale TEXT CHECK (grade_scale IN ('V', 'YDS', 'FRENCH', 'UIAA')),
    grade_score_min INTEGER,
    grade_score_max INTEGER,
    open_beta_climb_id TEXT,
    open_beta_area_id TEXT,
    location_display TEXT,
    belay_partner_user_id UUID REFERENCES auth.users(id),
    belay_partner_name TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_climbs_user_id ON climbs(user_id);
CREATE INDEX IF NOT EXISTS idx_climbs_session_id ON climbs(session_id);
CREATE INDEX IF NOT EXISTS idx_climbs_created_at ON climbs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_climbs_updated_at ON climbs(updated_at);
CREATE INDEX IF NOT EXISTS idx_climbs_grade_score ON climbs(grade_score_min);

-- Enable RLS
ALTER TABLE climbs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (for idempotent re-runs)
DROP POLICY IF EXISTS "Users can view own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can insert own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can update own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can delete own climbs" ON climbs;
DROP POLICY IF EXISTS "Authenticated users can view public session climbs" ON climbs;

-- Create policies
CREATE POLICY "Users can view own climbs" ON climbs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own climbs" ON climbs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own climbs" ON climbs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own climbs" ON climbs
    FOR DELETE USING (auth.uid() = user_id);

-- View public climbs through public sessions
CREATE POLICY "Authenticated users can view public session climbs" ON climbs
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM sessions
            WHERE sessions.id = climbs.session_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_climbs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS climbs_updated_at_trigger ON climbs;
CREATE TRIGGER climbs_updated_at_trigger
    BEFORE UPDATE ON climbs
    FOR EACH ROW
    EXECUTE FUNCTION update_climbs_updated_at();
