USE ai_for_study;

UPDATE users
SET avatar_url = 'ailearning_icon.png'
WHERE avatar_url IS NULL OR TRIM(avatar_url) = '';

ALTER TABLE users
  MODIFY COLUMN avatar_url VARCHAR(512)
  NOT NULL DEFAULT 'ailearning_icon.png';
