-- Migration: Add storage RLS policies for avatars bucket
-- Applied: 2026-01-20
--
-- This migration adds Row Level Security policies to the storage.objects table
-- to allow authenticated users to manage their profile photos in the avatars bucket.
--
-- IMPORTANT: UUID case sensitivity
-- Swift's UUID().uuidString returns UPPERCASE (e.g., F73D4C07-643E-4FB9-8006-AD2A770B0526)
-- Supabase's auth.uid() returns lowercase (e.g., f73d4c07-643e-4fb9-8006-ad2a770b0526)
-- All policies use lower() for case-insensitive comparison to handle this mismatch.

-- Enable RLS on storage.objects (should already be enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can upload to their own folder in avatars bucket
-- Path pattern: avatars/{userId}/filename.jpg
CREATE POLICY "Users can upload own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars' AND
    lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

-- Policy: Authenticated users can update their own avatars (for upsert)
CREATE POLICY "Users can update own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
)
WITH CHECK (
    bucket_id = 'avatars' AND
    lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

-- Policy: Authenticated users can delete their own avatars
CREATE POLICY "Users can delete own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

-- Policy: Anyone can read avatars (public bucket for profile photos)
CREATE POLICY "Anyone can read avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');
