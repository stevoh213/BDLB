-- Migration: add_social_profile_fields
-- Description: Add social profile fields to profiles table for social features
-- Author: Agent 2 (Builder)
-- Date: 2026-01-19
--
-- PURPOSE:
--   Extends the profiles table with social profile fields:
--   1. User identity fields (display_name, bio, home_gym, climbing_since, favorite_style)
--   2. Cached counts for performance (follower_count, following_count, send_count)
--
-- USAGE:
--   Apply this migration in the Supabase dashboard SQL editor:
--   1. Navigate to your project in Supabase dashboard
--   2. Go to SQL Editor
--   3. Paste this entire file and execute
--   4. Verify columns exist: SELECT * FROM profiles LIMIT 1;
--
-- SAFETY:
--   - Uses IF NOT EXISTS for safe reruns
--   - All new columns are nullable or have defaults (no breaking changes)
--   - Indexes created for query performance
--
-- RELATED TABLES:
--   - follows: follower/following relationships (referenced by trigger)
--   - attempts: send tracking (referenced by trigger)
--

-- =============================================================================
-- PART 1: Add new columns to profiles table
-- =============================================================================

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS home_gym TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS climbing_since DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS favorite_style TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS follower_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS send_count INTEGER NOT NULL DEFAULT 0;

-- Add comments for documentation
COMMENT ON COLUMN profiles.display_name IS
    'User-facing display name. Can differ from @handle.';
COMMENT ON COLUMN profiles.bio IS
    'Short user biography. Max 280 characters enforced at app layer.';
COMMENT ON COLUMN profiles.home_gym IS
    'User''s home gym or crag name (free-form text).';
COMMENT ON COLUMN profiles.climbing_since IS
    'Date when user started climbing. Used for "climbing for X years" display.';
COMMENT ON COLUMN profiles.favorite_style IS
    'User''s preferred climbing style (e.g., bouldering, sport, trad).';
COMMENT ON COLUMN profiles.follower_count IS
    'Cached count of followers. Updated by trigger on follows table.';
COMMENT ON COLUMN profiles.following_count IS
    'Cached count of users this user follows. Updated by trigger.';
COMMENT ON COLUMN profiles.send_count IS
    'Cached count of successful sends. Updated by trigger on attempts table.';

-- =============================================================================
-- PART 2: Add bio length constraint
-- =============================================================================

-- Add check constraint for bio length (280 characters max, Twitter-style)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_bio_length_check'
    ) THEN
        ALTER TABLE profiles
        ADD CONSTRAINT profiles_bio_length_check
        CHECK (char_length(bio) <= 280);
    END IF;
END $$;

-- =============================================================================
-- PART 3: Create indexes for search and display
-- =============================================================================

-- Index for profile search by handle (partial match support via LIKE)
CREATE INDEX IF NOT EXISTS idx_profiles_handle_search
    ON profiles (handle varchar_pattern_ops);

-- Index for profile search by display_name (partial match support via LIKE)
CREATE INDEX IF NOT EXISTS idx_profiles_display_name_search
    ON profiles (display_name varchar_pattern_ops)
    WHERE display_name IS NOT NULL;

-- Index for public profiles (used when browsing/discovering)
CREATE INDEX IF NOT EXISTS idx_profiles_is_public
    ON profiles (is_public)
    WHERE is_public = TRUE;

-- =============================================================================
-- PART 4: Create follows table (if not exists)
-- =============================================================================

-- The follows table stores follower relationships
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL,

    -- Prevent self-follows and duplicate relationships
    CONSTRAINT follows_no_self_follow CHECK (follower_id != followee_id),
    CONSTRAINT follows_unique_relationship UNIQUE (follower_id, followee_id)
);

-- Index for efficient follower lookups
CREATE INDEX IF NOT EXISTS idx_follows_followee_id
    ON follows (followee_id)
    WHERE deleted_at IS NULL;

-- Index for efficient following lookups
CREATE INDEX IF NOT EXISTS idx_follows_follower_id
    ON follows (follower_id)
    WHERE deleted_at IS NULL;

-- Add comments for documentation
COMMENT ON TABLE follows IS
    'Follower/following relationships between users. Uses soft delete (deleted_at) for sync.';
COMMENT ON COLUMN follows.follower_id IS
    'The user who is following someone else.';
COMMENT ON COLUMN follows.followee_id IS
    'The user who is being followed.';
COMMENT ON COLUMN follows.deleted_at IS
    'Soft delete timestamp. NULL = active follow, non-NULL = unfollowed.';

-- =============================================================================
-- PART 5: RLS Policies for follows table
-- =============================================================================

-- Enable RLS on follows table
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all follow relationships (for counts and lists)
DROP POLICY IF EXISTS "follows_select_policy" ON follows;
CREATE POLICY "follows_select_policy" ON follows
    FOR SELECT
    USING (true);

-- Policy: Users can only create their own follow relationships
DROP POLICY IF EXISTS "follows_insert_policy" ON follows;
CREATE POLICY "follows_insert_policy" ON follows
    FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

-- Policy: Users can only update (soft delete) their own follow relationships
DROP POLICY IF EXISTS "follows_update_policy" ON follows;
CREATE POLICY "follows_update_policy" ON follows
    FOR UPDATE
    USING (auth.uid() = follower_id)
    WITH CHECK (auth.uid() = follower_id);

-- Policy: Users can hard delete their own follow relationships
DROP POLICY IF EXISTS "follows_delete_policy" ON follows;
CREATE POLICY "follows_delete_policy" ON follows
    FOR DELETE
    USING (auth.uid() = follower_id);

-- =============================================================================
-- PART 6: Trigger function for follower count updates
-- =============================================================================

-- Function to update follower/following counts when follows change
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT: new follow relationship
    IF TG_OP = 'INSERT' THEN
        -- Increment followee's follower_count
        UPDATE profiles
        SET follower_count = follower_count + 1,
            updated_at = NOW()
        WHERE id = NEW.followee_id;

        -- Increment follower's following_count
        UPDATE profiles
        SET following_count = following_count + 1,
            updated_at = NOW()
        WHERE id = NEW.follower_id;

        RETURN NEW;

    -- Handle UPDATE: soft delete (unfollow) or restore
    ELSIF TG_OP = 'UPDATE' THEN
        -- Unfollow: deleted_at changed from NULL to non-NULL
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
            -- Decrement followee's follower_count
            UPDATE profiles
            SET follower_count = GREATEST(0, follower_count - 1),
                updated_at = NOW()
            WHERE id = NEW.followee_id;

            -- Decrement follower's following_count
            UPDATE profiles
            SET following_count = GREATEST(0, following_count - 1),
                updated_at = NOW()
            WHERE id = NEW.follower_id;

        -- Re-follow: deleted_at changed from non-NULL to NULL
        ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
            -- Increment followee's follower_count
            UPDATE profiles
            SET follower_count = follower_count + 1,
                updated_at = NOW()
            WHERE id = NEW.followee_id;

            -- Increment follower's following_count
            UPDATE profiles
            SET following_count = following_count + 1,
                updated_at = NOW()
            WHERE id = NEW.follower_id;
        END IF;

        RETURN NEW;

    -- Handle DELETE: hard delete
    ELSIF TG_OP = 'DELETE' THEN
        -- Only decrement if the relationship was active (not soft-deleted)
        IF OLD.deleted_at IS NULL THEN
            -- Decrement followee's follower_count
            UPDATE profiles
            SET follower_count = GREATEST(0, follower_count - 1),
                updated_at = NOW()
            WHERE id = OLD.followee_id;

            -- Decrement follower's following_count
            UPDATE profiles
            SET following_count = GREATEST(0, following_count - 1),
                updated_at = NOW()
            WHERE id = OLD.follower_id;
        END IF;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on follows table
DROP TRIGGER IF EXISTS trigger_update_follow_counts ON follows;
CREATE TRIGGER trigger_update_follow_counts
    AFTER INSERT OR UPDATE OR DELETE ON follows
    FOR EACH ROW
    EXECUTE FUNCTION update_follow_counts();

-- =============================================================================
-- PART 7: Trigger function for send count updates
-- =============================================================================

-- Function to update send_count when attempts change
CREATE OR REPLACE FUNCTION update_send_count()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get user_id from the session via the climb
    IF TG_OP = 'DELETE' THEN
        SELECT s.user_id INTO v_user_id
        FROM climbs c
        JOIN sessions s ON c.session_id = s.id
        WHERE c.id = OLD.climb_id;
    ELSE
        SELECT s.user_id INTO v_user_id
        FROM climbs c
        JOIN sessions s ON c.session_id = s.id
        WHERE c.id = NEW.climb_id;
    END IF;

    -- Skip if we couldn't find the user
    IF v_user_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Handle INSERT: new send
    IF TG_OP = 'INSERT' THEN
        IF NEW.outcome = 'send' AND NEW.deleted_at IS NULL THEN
            UPDATE profiles
            SET send_count = send_count + 1,
                updated_at = NOW()
            WHERE id = v_user_id;
        END IF;
        RETURN NEW;

    -- Handle UPDATE: outcome or deleted_at changed
    ELSIF TG_OP = 'UPDATE' THEN
        -- Was a send, now isn't (outcome changed or soft deleted)
        IF OLD.outcome = 'send' AND OLD.deleted_at IS NULL AND
           (NEW.outcome != 'send' OR NEW.deleted_at IS NOT NULL) THEN
            UPDATE profiles
            SET send_count = GREATEST(0, send_count - 1),
                updated_at = NOW()
            WHERE id = v_user_id;
        -- Wasn't a send, now is (outcome changed or restored)
        ELSIF (OLD.outcome != 'send' OR OLD.deleted_at IS NOT NULL) AND
              NEW.outcome = 'send' AND NEW.deleted_at IS NULL THEN
            UPDATE profiles
            SET send_count = send_count + 1,
                updated_at = NOW()
            WHERE id = v_user_id;
        END IF;
        RETURN NEW;

    -- Handle DELETE: hard delete of a send
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.outcome = 'send' AND OLD.deleted_at IS NULL THEN
            UPDATE profiles
            SET send_count = GREATEST(0, send_count - 1),
                updated_at = NOW()
            WHERE id = v_user_id;
        END IF;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on attempts table
DROP TRIGGER IF EXISTS trigger_update_send_count ON attempts;
CREATE TRIGGER trigger_update_send_count
    AFTER INSERT OR UPDATE OR DELETE ON attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_send_count();

-- =============================================================================
-- PART 8: Update existing profiles RLS (allow profile search)
-- =============================================================================

-- Policy: Allow searching public profiles without authentication
-- (Needed for profile search/discovery feature)
DROP POLICY IF EXISTS "profiles_select_public" ON profiles;
CREATE POLICY "profiles_select_public" ON profiles
    FOR SELECT
    USING (
        -- Can always read own profile
        auth.uid() = id
        OR
        -- Can read public profiles (for search/discovery)
        is_public = TRUE
    );

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Run these queries to verify the migration:
--
-- 1. Check new columns exist:
--    SELECT column_name, data_type, is_nullable, column_default
--    FROM information_schema.columns
--    WHERE table_name = 'profiles'
--    AND column_name IN ('display_name', 'bio', 'home_gym', 'climbing_since',
--                        'favorite_style', 'follower_count', 'following_count', 'send_count');
--
-- 2. Check follows table exists:
--    SELECT * FROM follows LIMIT 1;
--
-- 3. Check triggers exist:
--    SELECT trigger_name, event_manipulation, action_statement
--    FROM information_schema.triggers
--    WHERE trigger_name IN ('trigger_update_follow_counts', 'trigger_update_send_count');
--
-- 4. Check RLS policies:
--    SELECT policyname, cmd FROM pg_policies WHERE tablename = 'follows';
--
