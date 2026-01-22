# Phase 1: Database & Models Specification

> **Feature**: Social Profile Feature - Phase 1
> **Status**: Ready for Implementation
> **Author**: Agent 1 (The Architect)
> **Created**: 2026-01-19
> **Master Document**: [SOCIAL_PROFILE_FEATURE.md](../SOCIAL_PROFILE_FEATURE.md)

---

## Table of Contents
1. [Overview](#overview)
2. [SQL Migration](#sql-migration)
3. [Swift Model Changes](#swift-model-changes)
4. [DTO Changes](#dto-changes)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose
Establish the data foundation for the social profile system by:
1. Adding new profile fields to Supabase `profiles` table
2. Extending the `SCProfile` SwiftData model with matching properties
3. Updating DTOs to support the new fields
4. Creating database trigger for cached follower/following counts

### Scope
This phase covers Tasks 1.1 through 1.6 from the master document:
- [x] 1.1 Create Supabase migration for profile fields
- [x] 1.2 Apply migration to Supabase project
- [x] 1.3 Extend SCProfile model with new properties
- [x] 1.4 Update ProfileUpdates DTO struct
- [x] 1.5 Update Supabase RLS policies
- [x] 1.6 Create database trigger for follower counts

### New Fields Summary

| Field | Type | Description | Nullable |
|-------|------|-------------|----------|
| `display_name` | TEXT | User's display name (distinct from @handle) | Yes |
| `bio` | TEXT | Short biography (max 280 chars) | Yes |
| `home_gym` | TEXT | Home gym or crag name | Yes |
| `climbing_since` | DATE | When user started climbing | Yes |
| `favorite_style` | TEXT | Preferred climbing style | Yes |
| `follower_count` | INTEGER | Cached count of followers | No (default 0) |
| `following_count` | INTEGER | Cached count of following | No (default 0) |
| `send_count` | INTEGER | Cached count of sends | No (default 0) |

---

## SQL Migration

### File Location
`/Users/skelley/Projects/SwiftClimb/Database/migrations/20260119_add_social_profile_fields.sql`

### Migration SQL

```sql
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
```

---

## Swift Model Changes

### File to Modify
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Profile.swift`

### Current SCProfile Model
```swift
@Model
final class SCProfile {
    @Attribute(.unique) var id: UUID
    var handle: String
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale
    var preferredGradeScaleRoute: GradeScale
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

    // Premium status relationship
    @Relationship(deleteRule: .cascade)
    var premiumStatus: SCPremiumStatus?

    // Sync metadata
    var needsSync: Bool
    var remoteId: UUID?
    // ... init
}
```

### Updated SCProfile Model

```swift
import SwiftData
import Foundation

@Model
final class SCProfile {
    @Attribute(.unique) var id: UUID
    var handle: String
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale
    var preferredGradeScaleRoute: GradeScale
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Social Profile Fields (Phase 1)

    /// User's display name (distinct from @handle)
    /// Example: "Alex Honnold" while handle might be "@alex_honnold"
    var displayName: String?

    /// Short user biography (max 280 characters)
    /// Validated at app layer before saving
    var bio: String?

    /// User's home gym or crag name
    /// Free-form text, not validated against a list
    var homeGym: String?

    /// Date when user started climbing
    /// Used for "climbing for X years" display
    var climbingSince: Date?

    /// User's preferred climbing style
    /// Stored as string to allow flexibility (e.g., "Bouldering", "Sport", "Trad")
    var favoriteStyle: String?

    /// Cached count of users following this user
    /// Updated by Supabase trigger, synced to device
    var followerCount: Int

    /// Cached count of users this user follows
    /// Updated by Supabase trigger, synced to device
    var followingCount: Int

    /// Cached count of successful sends
    /// Updated by Supabase trigger, synced to device
    var sendCount: Int

    // Premium status relationship
    @Relationship(deleteRule: .cascade)
    var premiumStatus: SCPremiumStatus?

    // Sync metadata
    var needsSync: Bool
    var remoteId: UUID?

    init(
        id: UUID = UUID(),
        handle: String,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: GradeScale = .v,
        preferredGradeScaleRoute: GradeScale = .yds,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        // New social profile fields
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil,
        followerCount: Int = 0,
        followingCount: Int = 0,
        sendCount: Int = 0,
        // Sync metadata
        needsSync: Bool = true,
        remoteId: UUID? = nil
    ) {
        self.id = id
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        // Social profile fields
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.sendCount = sendCount
        // Sync metadata
        self.needsSync = needsSync
        self.remoteId = remoteId
    }
}

extension SCProfile {
    /// Computed property for easy premium access
    var isPremium: Bool {
        premiumStatus?.isValidPremium ?? false
    }

    /// Computed property for "climbing for X years" display
    var yearsClimbing: Int? {
        guard let since = climbingSince else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: since, to: Date())
        return components.year
    }

    /// Validation helper for bio length
    static let maxBioLength = 280

    /// Returns true if the bio is within the allowed length
    var isBioValid: Bool {
        guard let bio = bio else { return true }
        return bio.count <= Self.maxBioLength
    }
}
```

---

## DTO Changes

### File to Modify
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift`

### Updated ProfileDTO

```swift
/// Profile data transfer object for Supabase `profiles` table.
///
/// This DTO includes all profile fields including:
/// - Core identity (id, handle, photo)
/// - Social profile (display_name, bio, home_gym, etc.)
/// - Cached counts (follower_count, following_count, send_count)
/// - Premium subscription data
///
/// ## Social Profile Fields
///
/// The social profile fields enable the social features:
/// - `displayName`: User-facing name (can differ from @handle)
/// - `bio`: Short biography (max 280 chars)
/// - `homeGym`: Home gym or crag name
/// - `climbingSince`: When user started climbing
/// - `favoriteStyle`: Preferred climbing style
///
/// ## Cached Counts
///
/// Counts are maintained by database triggers for performance:
/// - `followerCount`: Updated by follows table trigger
/// - `followingCount`: Updated by follows table trigger
/// - `sendCount`: Updated by attempts table trigger
///
/// - SeeAlso: `ProfileUpdateRequest` for partial updates.
struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let handle: String
    let photoURL: String?
    let homeZIP: String?
    let preferredGradeScaleBoulder: String
    let preferredGradeScaleRoute: String
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date

    // Social profile fields
    let displayName: String?
    let bio: String?
    let homeGym: String?
    let climbingSince: Date?
    let favoriteStyle: String?

    // Cached counts (read-only from app perspective)
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int

    // Premium subscription fields
    let premiumExpiresAt: Date?
    let premiumProductId: String?
    let premiumOriginalTransactionId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case photoURL = "photo_url"
        case homeZIP = "home_zip"
        case preferredGradeScaleBoulder = "preferred_grade_scale_boulder"
        case preferredGradeScaleRoute = "preferred_grade_scale_route"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Social profile fields
        case displayName = "display_name"
        case bio
        case homeGym = "home_gym"
        case climbingSince = "climbing_since"
        case favoriteStyle = "favorite_style"
        // Cached counts
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case sendCount = "send_count"
        // Premium fields
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}
```

### Updated ProfileUpdateRequest

```swift
/// Request object for updating profile fields.
///
/// Only include fields that should be updated. Nil fields are not sent to the server.
/// Note: Cached counts (follower_count, following_count, send_count) are read-only
/// and maintained by database triggers.
struct ProfileUpdateRequest: Codable, Sendable {
    let handle: String?
    let photoURL: String?
    let homeZIP: String?
    let preferredGradeScaleBoulder: String?
    let preferredGradeScaleRoute: String?
    let isPublic: Bool?
    // Social profile fields
    let displayName: String?
    let bio: String?
    let homeGym: String?
    let climbingSince: Date?
    let favoriteStyle: String?
    // Timestamp
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case handle
        case photoURL = "photo_url"
        case homeZIP = "home_zip"
        case preferredGradeScaleBoulder = "preferred_grade_scale_boulder"
        case preferredGradeScaleRoute = "preferred_grade_scale_route"
        case isPublic = "is_public"
        // Social profile fields
        case displayName = "display_name"
        case bio
        case homeGym = "home_gym"
        case climbingSince = "climbing_since"
        case favoriteStyle = "favorite_style"
        // Timestamp
        case updatedAt = "updated_at"
    }

    init(
        handle: String? = nil,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: String? = nil,
        preferredGradeScaleRoute: String? = nil,
        isPublic: Bool? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil
    ) {
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
        self.updatedAt = Date()
    }
}
```

### Updated ProfileUpdates Domain DTO

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/ProfileService.swift`

```swift
/// Domain-level profile update request.
///
/// Used by ProfileService and UpdateProfileUseCase to specify which fields to update.
/// This is separate from ProfileUpdateRequest (Supabase DTO) to maintain layer separation.
struct ProfileUpdates: Sendable {
    var handle: String?
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale?
    var preferredGradeScaleRoute: GradeScale?
    var isPublic: Bool?
    // Social profile fields
    var displayName: String?
    var bio: String?
    var homeGym: String?
    var climbingSince: Date?
    var favoriteStyle: String?

    init(
        handle: String? = nil,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: GradeScale? = nil,
        preferredGradeScaleRoute: GradeScale? = nil,
        isPublic: Bool? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil
    ) {
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
    }
}
```

---

## Acceptance Criteria

### Task 1.1: Create Supabase Migration
- [ ] Migration file exists at `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260119_add_social_profile_fields.sql`
- [ ] Migration adds all 8 new columns to `profiles` table
- [ ] Migration includes bio length constraint (280 chars)
- [ ] Migration creates `follows` table with proper constraints
- [ ] Migration includes search indexes for `handle` and `display_name`
- [ ] Migration uses `IF NOT EXISTS` for safe reruns

### Task 1.2: Apply Migration to Supabase
- [ ] All new columns exist in Supabase `profiles` table
- [ ] `follows` table exists with proper structure
- [ ] Triggers are created and functional
- [ ] Indexes are created

### Task 1.3: Extend SCProfile Model
- [ ] SCProfile includes all 8 new properties
- [ ] Init method updated with new parameters (all with defaults)
- [ ] Computed property `yearsClimbing` added
- [ ] Bio validation helper added
- [ ] Code compiles without errors

### Task 1.4: Update ProfileUpdates DTO
- [ ] ProfileUpdates struct includes social profile fields
- [ ] ProfileDTO includes all new fields with correct CodingKeys
- [ ] ProfileUpdateRequest includes social profile fields
- [ ] Code compiles without errors

### Task 1.5: Update Supabase RLS Policies
- [ ] RLS enabled on `follows` table
- [ ] Users can view all follow relationships
- [ ] Users can only create/update/delete their own follows
- [ ] Public profiles can be searched without auth
- [ ] Verified by running test queries

### Task 1.6: Create Database Triggers
- [ ] `update_follow_counts()` trigger function exists
- [ ] `update_send_count()` trigger function exists
- [ ] Triggers fire on INSERT, UPDATE, DELETE
- [ ] Counts update correctly when follows change
- [ ] Counts update correctly when sends are logged
- [ ] GREATEST(0, count - 1) prevents negative counts

---

## Builder Handoff Notes

### Dependencies
1. **No blocking dependencies** - Phase 1 can begin immediately
2. The `follows` table references `profiles(id)` - profiles must exist first (they do)
3. The send count trigger references `sessions`, `climbs`, and `attempts` tables - these exist

### Order of Operations
1. **First**: Create and apply SQL migration (Tasks 1.1, 1.2)
   - Run migration in Supabase SQL Editor
   - Verify with provided verification queries
2. **Second**: Update Swift models (Task 1.3)
   - Modify `Profile.swift`
   - Ensure app compiles
3. **Third**: Update DTOs (Task 1.4)
   - Modify `ProfilesTable.swift`
   - Modify `ProfileService.swift`
   - Ensure app compiles
4. **Fourth**: Verify RLS and triggers work (Tasks 1.5, 1.6)
   - Test follow insert/update/delete
   - Verify counts update

### Known Considerations

1. **Bio Length Validation**: The 280-character limit is enforced both:
   - At database level (CHECK constraint)
   - At app level (validation helper on SCProfile)

2. **Cached Counts Are Read-Only**: The `follower_count`, `following_count`, and `send_count` fields:
   - Should NOT be included in ProfileUpdateRequest
   - Are updated only by database triggers
   - Are synced from Supabase to local SwiftData

3. **Date Handling for `climbingSince`**:
   - Database uses DATE type (no time component)
   - Swift uses Date type
   - Ensure proper date-only formatting when sending to Supabase

4. **Soft Delete Pattern**: The `follows` table uses `deleted_at` for soft deletes:
   - Triggers handle both soft delete (UPDATE) and hard delete (DELETE)
   - Counts only affected when `deleted_at` changes state

### Testing Verification

After implementation, run these manual tests:

1. **Migration Test**:
   ```sql
   -- Insert a test profile update
   UPDATE profiles SET display_name = 'Test', bio = 'Test bio' WHERE id = 'YOUR_USER_ID';
   SELECT display_name, bio, follower_count FROM profiles WHERE id = 'YOUR_USER_ID';
   ```

2. **Follow Trigger Test**:
   ```sql
   -- Before: check follower_count
   SELECT id, follower_count, following_count FROM profiles WHERE id IN ('USER_A', 'USER_B');

   -- Insert follow
   INSERT INTO follows (follower_id, followee_id) VALUES ('USER_A', 'USER_B');

   -- After: verify counts
   SELECT id, follower_count, following_count FROM profiles WHERE id IN ('USER_A', 'USER_B');
   ```

3. **Swift Compilation Test**:
   ```bash
   cd /Users/skelley/Projects/SwiftClimb
   xcodebuild -workspace SwiftClimb.xcworkspace -scheme SwiftClimb -sdk iphonesimulator build
   ```

### Files Modified Summary

| File | Action | Priority |
|------|--------|----------|
| `Database/migrations/20260119_add_social_profile_fields.sql` | CREATE | 1 |
| `Domain/Models/Profile.swift` | MODIFY | 2 |
| `Integrations/Supabase/Tables/ProfilesTable.swift` | MODIFY | 3 |
| `Domain/Services/ProfileService.swift` | MODIFY | 3 |

---

## Appendix: Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      PHASE 1 DATA FLOW                          │
└─────────────────────────────────────────────────────────────────┘

User Action: Update Profile
              │
              ▼
┌─────────────────────┐
│    SwiftUI View     │  @MainActor
│   (EditProfileView) │
└──────────┬──────────┘
           │ ProfileUpdates
           ▼
┌─────────────────────┐
│  UpdateProfileUseCase│  (Phase 3)
└──────────┬──────────┘
           │
           ├────────────────────────────┐
           │                            │
           ▼                            ▼
┌─────────────────────┐     ┌─────────────────────┐
│     SwiftData       │     │     SyncActor       │  background
│  (SCProfile @Model) │     └──────────┬──────────┘
└─────────────────────┘                │
                                       ▼
                            ┌─────────────────────┐
                            │     Supabase        │
                            │  (profiles table)   │
                            └─────────────────────┘

Follow Action Flow:
              │
              ▼
┌─────────────────────┐     ┌─────────────────────┐
│  INSERT into follows│ ──► │  TRIGGER fires      │
└─────────────────────┘     │  update_follow_counts│
                            └──────────┬──────────┘
                                       │
                                       ▼
                            ┌─────────────────────┐
                            │  UPDATE profiles    │
                            │  follower_count++   │
                            │  following_count++  │
                            └─────────────────────┘
```

---

**Document Version**: 1.0
**Last Updated**: 2026-01-19
**Author**: Agent 1 (The Architect)
**Next Phase**: Phase 2 (Services) - depends on Phase 1 completion
