USE ai_for_study;

CREATE TABLE IF NOT EXISTS review_schedules (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  review_stage TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=today, 1=tomorrow, 2=3 days, 3=7 days',
  next_review_date DATE NOT NULL,
  last_result ENUM('unknown', 'correct', 'wrong') NOT NULL DEFAULT 'unknown',
  consecutive_correct INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('active', 'mastered') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_review_schedules_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_review_schedules_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_review_schedules_user_question (user_id, question_id),
  INDEX idx_review_schedules_due (user_id, status, next_review_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS daily_review_plans (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  plan_date DATE NOT NULL,
  target_count INT UNSIGNED NOT NULL DEFAULT 0,
  completed_count INT UNSIGNED NOT NULL DEFAULT 0,
  mood_adjustment INT NOT NULL DEFAULT 0,
  mood_summary VARCHAR(255) NULL,
  generation_reason VARCHAR(500) NULL,
  practice_session_id BIGINT UNSIGNED NULL,
  status ENUM('pending', 'in_progress', 'completed') NOT NULL DEFAULT 'pending',
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_daily_review_plans_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_daily_review_plans_session
    FOREIGN KEY (practice_session_id) REFERENCES practice_sessions(id)
    ON DELETE SET NULL,
  UNIQUE KEY uk_daily_review_plans_user_date (user_id, plan_date),
  INDEX idx_daily_review_plans_user_status (user_id, status, plan_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS daily_review_tasks (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  plan_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  source_type ENUM('wrong_question', 'weak_knowledge') NOT NULL,
  knowledge_point VARCHAR(255) NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('pending', 'completed') NOT NULL DEFAULT 'pending',
  is_correct TINYINT(1) NULL,
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_daily_review_tasks_plan
    FOREIGN KEY (plan_id) REFERENCES daily_review_plans(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_daily_review_tasks_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_daily_review_tasks_plan_question (plan_id, question_id),
  INDEX idx_daily_review_tasks_plan_status (plan_id, status, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
