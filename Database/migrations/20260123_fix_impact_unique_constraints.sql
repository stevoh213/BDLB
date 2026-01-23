-- Fix unique constraints on impact tables to support soft-delete pattern
-- The existing constraints blocked new inserts when old records were soft-deleted
-- because they didn't consider deleted_at

-- Technique impacts: drop old constraint, add partial unique index
ALTER TABLE technique_impacts
  DROP CONSTRAINT IF EXISTS technique_impacts_user_id_climb_id_tag_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS technique_impacts_user_climb_tag_unique
  ON technique_impacts (user_id, climb_id, tag_id)
  WHERE deleted_at IS NULL;

-- Skill impacts: drop old constraint, add partial unique index
ALTER TABLE skill_impacts
  DROP CONSTRAINT IF EXISTS skill_impacts_user_id_climb_id_tag_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS skill_impacts_user_climb_tag_unique
  ON skill_impacts (user_id, climb_id, tag_id)
  WHERE deleted_at IS NULL;

-- Wall style impacts: drop old constraint, add partial unique index
ALTER TABLE wall_style_impacts
  DROP CONSTRAINT IF EXISTS wall_style_impacts_user_id_climb_id_tag_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS wall_style_impacts_user_climb_tag_unique
  ON wall_style_impacts (user_id, climb_id, tag_id)
  WHERE deleted_at IS NULL;
