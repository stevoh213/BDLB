-- Migration: add_premium_fields_to_profiles
-- Description: Add premium subscription fields to profiles table for support team queries
-- Author: Agent 2 (Builder), Agent 4 (Scribe)
-- Date: 2026-01-19
--
-- PURPOSE:
--   Stores StoreKit 2 subscription data in Supabase for:
--   1. Support team queries (who has active subscriptions?)
--   2. Cross-device premium status sync
--   3. Analytics on subscription usage
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
--   - All columns are nullable (no breaking changes to existing rows)
--   - Index created for query performance
--
-- DATA FLOW:
--   iOS App (StoreKit 2) → PremiumSyncImpl → Supabase profiles table
--
-- SUPPORT QUERIES:
--   -- Find all active premium users
--   SELECT id, handle, premium_expires_at, premium_product_id
--   FROM profiles
--   WHERE premium_expires_at > NOW();
--
--   -- Find users whose subscription expires soon (next 7 days)
--   SELECT id, handle, premium_expires_at
--   FROM profiles
--   WHERE premium_expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days';
--

-- Add premium columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_product_id TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_original_transaction_id TEXT DEFAULT NULL;

-- Add comments for documentation
COMMENT ON COLUMN profiles.premium_expires_at IS
    'When the premium subscription expires. NULL means free user or lifetime subscription.';
COMMENT ON COLUMN profiles.premium_product_id IS
    'StoreKit product ID of active subscription (e.g., com.swiftclimb.premium.monthly)';
COMMENT ON COLUMN profiles.premium_original_transaction_id IS
    'Original transaction ID from StoreKit for subscription tracking and support queries.';

-- Create index for support queries on premium status
CREATE INDEX IF NOT EXISTS idx_profiles_premium_expires_at
    ON profiles (premium_expires_at)
    WHERE premium_expires_at IS NOT NULL;

-- Update RLS policy to allow users to update their own premium fields
-- (The existing RLS policy for profiles should already allow this since it's
-- based on auth.uid() = id, but verify this is in place)
