USE ai_for_study;

CREATE TABLE IF NOT EXISTS diary_insight_reports (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  source_diary_count INT UNSIGNED NOT NULL DEFAULT 0,
  average_mood DECIMAL(4,1) NOT NULL DEFAULT 0,
  answer_count INT UNSIGNED NOT NULL DEFAULT 0,
  accuracy_rate DECIMAL(5,1) NOT NULL DEFAULT 0,
  study_minutes INT UNSIGNED NOT NULL DEFAULT 0,
  mood_label VARCHAR(60) NOT NULL DEFAULT '',
  mood_trend TEXT NULL,
  learning_status TEXT NULL,
  summary TEXT NULL,
  goals JSON NULL,
  suggestions JSON NULL,
  weak_points JSON NULL,
  risk_level ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'low',
  is_ai_generated TINYINT(1) NOT NULL DEFAULT 0,
  raw_result JSON NULL,
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_diary_insight_reports_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_diary_insight_reports_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
