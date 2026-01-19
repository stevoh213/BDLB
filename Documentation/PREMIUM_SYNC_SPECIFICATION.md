# Premium Sync to Supabase Specification

**Document Version:** 1.0
**Author:** Agent 1 (Architect)
**Date:** 2026-01-19
**Status:** Ready for Implementation

---

## 1. Executive Summary

This specification defines the changes needed to sync premium subscription status to Supabase so the support team can query user premium status directly from the database. Currently, `PremiumSync.swift` sends premium data to Supabase, but:

1. The `profiles` table lacks the required columns
2. `ProfileDTO` does not include premium fields for reading the data back
3. The `fetchRemotePremiumStatus` method returns `nil` (marked as TODO)

This document provides the complete implementation plan to resolve these gaps.

---

## 2. Current State Analysis

### 2.1 Existing Profiles Table Schema

From Supabase, the current `profiles` table has these columns:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key, references auth.users |
| `handle` | text | Unique username |
| `photo_url` | text | Nullable |
| `home_zip` | text | Nullable |
| `preferred_grade_scale_boulder` | text | Default 'v_scale' |
| `preferred_grade_scale_route` | text | Default 'yds' |
| `is_public` | boolean | Default false |
| `created_at` | timestamptz | Default now() |
| `updated_at` | timestamptz | Default now() |

**Missing:** Premium-related columns (`premium_expires_at`, `premium_product_id`, `premium_original_transaction_id`)

### 2.2 Current PremiumSync Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift`

The `PremiumSyncImpl` actor already:
- Defines `PremiumUpdateRequest` with the correct field mappings
- Calls `repository.update()` to push premium data to profiles

**Issue:** The update will fail because the columns do not exist in Supabase.

```swift
struct PremiumUpdateRequest: Codable, Sendable {
    let premiumExpiresAt: Date?
    let premiumProductId: String?
    let premiumOriginalTransactionId: String?

    enum CodingKeys: String, CodingKey {
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}
```

### 2.3 Current ProfileDTO

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift`

```swift
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
    // MISSING: premium fields
}
```

**Issue:** Cannot decode profiles with premium fields. The `fetchRemotePremiumStatus` method in `PremiumSync.swift` returns `nil` with a TODO comment.

---

## 3. Required Changes

### 3.1 SQL Migration

**Migration Name:** `add_premium_fields_to_profiles`

```sql
-- Migration: add_premium_fields_to_profiles
-- Description: Add premium subscription fields to profiles table for support team queries
-- Author: Agent 1 (Architect)
-- Date: 2026-01-19

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
```

### 3.2 ProfileDTO Changes

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift`

Update `ProfileDTO` to include premium fields:

```swift
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
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}
```

**Rationale:** All three premium fields are nullable (`Date?`, `String?`), so existing profiles without these fields will decode correctly with `nil` values.

### 3.3 PremiumSync Changes

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift`

Update the `fetchRemotePremiumStatus` method to properly map from `ProfileDTO`:

```swift
func fetchRemotePremiumStatus(userId: UUID) async throws -> RemotePremiumStatus? {
    let profiles: [ProfileDTO] = try await repository.select(
        from: "profiles",
        where: ["id": userId.uuidString],
        limit: 1
    )

    guard let profile = profiles.first else { return nil }

    return RemotePremiumStatus(
        expiresAt: profile.premiumExpiresAt,
        productId: profile.premiumProductId
    )
}
```

**Change Summary:**
- Replace `profiles.first != nil` check with proper guard let
- Map `profile.premiumExpiresAt` and `profile.premiumProductId` to `RemotePremiumStatus`
- Remove the `// TODO` comment and `return nil` placeholder

---

## 4. Support Team Query Examples

Once the migration is applied, support team can query premium status using these SQL queries in the Supabase dashboard:

### 4.1 Check if a Specific User is Premium

```sql
-- Check premium status for a user by email
SELECT
    p.id,
    p.handle,
    au.email,
    p.premium_expires_at,
    p.premium_product_id,
    CASE
        WHEN p.premium_expires_at IS NULL THEN 'Free'
        WHEN p.premium_expires_at > NOW() THEN 'Premium (Active)'
        ELSE 'Premium (Expired)'
    END AS premium_status
FROM profiles p
JOIN auth.users au ON p.id = au.id
WHERE au.email = 'user@example.com';
```

### 4.2 Find All Active Premium Users

```sql
-- List all users with active premium subscriptions
SELECT
    p.id,
    p.handle,
    au.email,
    p.premium_product_id,
    p.premium_expires_at,
    p.premium_expires_at - NOW() AS time_remaining
FROM profiles p
JOIN auth.users au ON p.id = au.id
WHERE p.premium_expires_at > NOW()
ORDER BY p.premium_expires_at ASC;
```

### 4.3 Find Premium Subscriptions Expiring Soon

```sql
-- Find subscriptions expiring in the next 7 days
SELECT
    p.id,
    p.handle,
    au.email,
    p.premium_product_id,
    p.premium_expires_at,
    EXTRACT(DAY FROM p.premium_expires_at - NOW()) AS days_remaining
FROM profiles p
JOIN auth.users au ON p.id = au.id
WHERE p.premium_expires_at > NOW()
  AND p.premium_expires_at < NOW() + INTERVAL '7 days'
ORDER BY p.premium_expires_at ASC;
```

### 4.4 Premium User Statistics

```sql
-- Get premium subscription statistics
SELECT
    premium_product_id,
    COUNT(*) AS subscriber_count,
    COUNT(*) FILTER (WHERE premium_expires_at > NOW()) AS active_count,
    COUNT(*) FILTER (WHERE premium_expires_at <= NOW()) AS expired_count
FROM profiles
WHERE premium_product_id IS NOT NULL
GROUP BY premium_product_id;
```

### 4.5 Recently Expired Subscriptions

```sql
-- Find subscriptions that expired in the last 30 days
SELECT
    p.id,
    p.handle,
    au.email,
    p.premium_product_id,
    p.premium_expires_at,
    NOW() - p.premium_expires_at AS time_since_expiry
FROM profiles p
JOIN auth.users au ON p.id = au.id
WHERE p.premium_expires_at < NOW()
  AND p.premium_expires_at > NOW() - INTERVAL '30 days'
ORDER BY p.premium_expires_at DESC;
```

### 4.6 User Lookup by Transaction ID (for Support Tickets)

```sql
-- Find user by StoreKit transaction ID (useful for support tickets)
SELECT
    p.id,
    p.handle,
    au.email,
    p.premium_product_id,
    p.premium_expires_at,
    p.premium_original_transaction_id
FROM profiles p
JOIN auth.users au ON p.id = au.id
WHERE p.premium_original_transaction_id = '1000000123456789';
```

---

## 5. Implementation Sequence

### Step 1: Apply Supabase Migration

Use the Supabase MCP tool to apply the migration:

```
Migration Name: add_premium_fields_to_profiles
SQL: (see Section 3.1)
```

**Verification:** Query the profiles table to confirm new columns exist:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name LIKE 'premium%';
```

### Step 2: Update ProfileDTO

Modify `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift`:

1. Add three new properties to `ProfileDTO`
2. Add corresponding `CodingKeys` cases

### Step 3: Update PremiumSync

Modify `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift`:

1. Update `fetchRemotePremiumStatus` to map from `ProfileDTO` premium fields
2. Remove the TODO comment and placeholder return

### Step 4: Test the Integration

1. Build the app to verify no compilation errors
2. Test premium sync by:
   - Verifying premium data is written to Supabase on purchase
   - Verifying premium data is readable via `fetchRemotePremiumStatus`
3. Run support queries in Supabase dashboard to confirm data visibility

---

## 6. Files to Modify

| File | Change Type | Description |
|------|-------------|-------------|
| Supabase (migration) | CREATE | Add premium columns to profiles table |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift` | MODIFY | Add premium fields to ProfileDTO |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift` | MODIFY | Implement fetchRemotePremiumStatus mapping |

---

## 7. Acceptance Criteria

### 7.1 Database
- [ ] Profiles table has `premium_expires_at` column (TIMESTAMPTZ, nullable)
- [ ] Profiles table has `premium_product_id` column (TEXT, nullable)
- [ ] Profiles table has `premium_original_transaction_id` column (TEXT, nullable)
- [ ] Index exists on `premium_expires_at` for query performance

### 7.2 ProfileDTO
- [ ] `ProfileDTO` includes `premiumExpiresAt: Date?`
- [ ] `ProfileDTO` includes `premiumProductId: String?`
- [ ] `ProfileDTO` includes `premiumOriginalTransactionId: String?`
- [ ] CodingKeys map to snake_case column names

### 7.3 PremiumSync
- [ ] `syncPremiumStatus` successfully writes premium data to Supabase
- [ ] `fetchRemotePremiumStatus` returns valid `RemotePremiumStatus` when premium data exists
- [ ] `fetchRemotePremiumStatus` returns `RemotePremiumStatus` with nil fields for free users

### 7.4 Support Queries
- [ ] Support team can query premium status by user email
- [ ] Support team can list all active premium subscribers
- [ ] Support team can find subscriptions expiring within a date range

---

## 8. Risk Assessment

### 8.1 Migration Risk: Low
- Adding nullable columns does not affect existing data
- No existing code depends on these columns yet
- Rollback is simple: DROP COLUMN statements

### 8.2 DTO Compatibility Risk: Low
- New fields are optional (`Date?`, `String?`)
- JSONDecoder handles missing keys with nil for optionals
- Existing profiles will decode correctly

### 8.3 Sync Timing Risk: Low
- Premium sync is already implemented but was writing to non-existent columns
- After migration, existing `syncPremiumStatus` calls will succeed
- No change to sync timing or frequency needed

---

## 9. Architecture Decision Record

### ADR-004: Premium Data in Profiles Table (Not Separate Table)

**Context:** Should premium subscription data be stored in the `profiles` table or a separate `premium_subscriptions` table?

**Decision:** Store premium fields directly in the `profiles` table.

**Rationale:**
1. **Simplicity:** One-to-one relationship with user profile
2. **Query efficiency:** No joins needed for common support queries
3. **Existing pattern:** `PremiumSync` already targets the profiles table
4. **Data volume:** Only 3 additional columns, not a high-volume dataset
5. **Consistency:** Matches the pattern in `PREMIUM_SYSTEM_SPECIFICATION.md`

**Consequences:**
- Simple queries for support team
- Profile reads include premium data (minor overhead)
- Future premium features may need schema updates (acceptable trade-off)

**Alternative considered:** Separate `premium_subscriptions` table with foreign key to profiles. Rejected due to added complexity for minimal benefit.

---

## 10. Handoff to Builder (Agent 2)

### Prerequisites
- Supabase project access for migration execution
- Understanding of existing `ProfileDTO` and `PremiumSync` patterns

### Implementation Order
1. Apply Supabase migration (creates columns)
2. Update `ProfileDTO` (add fields and coding keys)
3. Update `PremiumSync.fetchRemotePremiumStatus` (implement mapping)
4. Build and verify no compilation errors

### Test Scenarios for Validator (Agent 3)
1. **Sync write test:** Call `syncPremiumStatus`, verify data in Supabase
2. **Sync read test:** Call `fetchRemotePremiumStatus`, verify returned data matches
3. **Free user test:** Verify free user profile returns nil premium fields
4. **Support query test:** Run support queries in Supabase dashboard

---

**End of Specification**

*This document is ready for handoff to Agent 2 (Builder) for implementation.*
