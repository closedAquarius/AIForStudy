USE ai_for_study;

ALTER TABLE daily_review_tasks
  MODIFY source_type ENUM('wrong_question', 'weak_knowledge', 'favorite') NOT NULL,
  MODIFY status ENUM('pending', 'completed', 'skipped', 'postponed') NOT NULL DEFAULT 'pending',
  ADD COLUMN postponed_to DATE NULL AFTER completed_at;
