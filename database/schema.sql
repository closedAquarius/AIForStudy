CREATE DATABASE IF NOT EXISTS ai_for_study
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE ai_for_study;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS ai_messages;
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS learning_analytics;
DROP TABLE IF EXISTS diary_ai_reports;
DROP TABLE IF EXISTS diary_entries;
DROP TABLE IF EXISTS daily_review_tasks;
DROP TABLE IF EXISTS daily_review_plans;
DROP TABLE IF EXISTS review_schedules;
DROP TABLE IF EXISTS practice_answers;
DROP TABLE IF EXISTS practice_sessions;
DROP TABLE IF EXISTS user_question_records;
DROP TABLE IF EXISTS question_tags;
DROP TABLE IF EXISTS question_answers;
DROP TABLE IF EXISTS question_options;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS question_import_rows;
DROP TABLE IF EXISTS question_imports;
DROP TABLE IF EXISTS generated_papers;
DROP TABLE IF EXISTS knowledge_queries;
DROP TABLE IF EXISTS document_chunks;
DROP TABLE IF EXISTS knowledge_base_documents;
DROP TABLE IF EXISTS knowledge_bases;
DROP TABLE IF EXISTS documents;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS question_banks;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS user_sessions;
DROP TABLE IF EXISTS password_reset_codes;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL UNIQUE,
  password VARCHAR(128) NOT NULL COMMENT 'Demo only: plain text password',
  nickname VARCHAR(64) NOT NULL,
  email VARCHAR(128) NULL UNIQUE,
  avatar_url VARCHAR(512) NOT NULL DEFAULT 'ailearning_icon.png',
  role ENUM('student', 'teacher', 'admin') NOT NULL DEFAULT 'student',
  status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(128) NOT NULL UNIQUE,
  expires_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE password_reset_codes (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  email VARCHAR(128) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_password_reset_codes_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_password_reset_email_created (email, created_at),
  INDEX idx_password_reset_user_active (user_id, consumed_at, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subjects (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(64) NOT NULL UNIQUE,
  stage VARCHAR(64) NULL COMMENT 'Example: middle_school, high_school, college',
  description VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_banks (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NULL,
  subject_id BIGINT UNSIGNED NULL,
  name VARCHAR(128) NOT NULL,
  description TEXT NULL,
  visibility ENUM('private', 'class', 'public') NOT NULL DEFAULT 'private',
  source_type ENUM('manual', 'excel', 'document_ai', 'paper_ai') NOT NULL DEFAULT 'manual',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_question_banks_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_question_banks_subject
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
    ON DELETE SET NULL,
  INDEX idx_question_banks_owner (owner_user_id),
  INDEX idx_question_banks_subject (subject_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tags (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL DEFAULT 'knowledge',
  color VARCHAR(16) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_tags_name_category (name, category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE documents (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  subject_id BIGINT UNSIGNED NULL,
  title VARCHAR(180) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_type ENUM('ppt', 'pptx', 'doc', 'docx', 'pdf', 'txt', 'other') NOT NULL,
  storage_path VARCHAR(512) NOT NULL,
  parse_status ENUM('uploaded', 'parsing', 'parsed', 'failed') NOT NULL DEFAULT 'uploaded',
  extracted_text LONGTEXT NULL,
  ai_summary TEXT NULL,
  metadata JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_documents_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_documents_subject
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
    ON DELETE SET NULL,
  INDEX idx_documents_owner (owner_user_id),
  INDEX idx_documents_subject (subject_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE knowledge_bases (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_knowledge_bases_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_knowledge_bases_owner_time (owner_user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE knowledge_base_documents (
  knowledge_base_id BIGINT UNSIGNED NOT NULL,
  document_id BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (knowledge_base_id, document_id),
  CONSTRAINT fk_knowledge_base_documents_base
    FOREIGN KEY (knowledge_base_id) REFERENCES knowledge_bases(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_knowledge_base_documents_document
    FOREIGN KEY (document_id) REFERENCES documents(id)
    ON DELETE CASCADE,
  INDEX idx_knowledge_base_documents_document (document_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE document_chunks (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  document_id BIGINT UNSIGNED NOT NULL,
  chunk_index INT UNSIGNED NOT NULL,
  content TEXT NOT NULL,
  char_start INT UNSIGNED NOT NULL DEFAULT 0,
  char_end INT UNSIGNED NOT NULL DEFAULT 0,
  metadata JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_document_chunks_document
    FOREIGN KEY (document_id) REFERENCES documents(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_document_chunks_document_index (document_id, chunk_index),
  FULLTEXT KEY ft_document_chunks_content (content)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE knowledge_queries (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  knowledge_base_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  question TEXT NOT NULL,
  answer LONGTEXT NOT NULL,
  sources JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_knowledge_queries_base
    FOREIGN KEY (knowledge_base_id) REFERENCES knowledge_bases(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_knowledge_queries_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_knowledge_queries_base_time (knowledge_base_id, created_at),
  INDEX idx_knowledge_queries_user_time (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE generated_papers (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  source_document_id BIGINT UNSIGNED NULL,
  question_bank_id BIGINT UNSIGNED NULL,
  title VARCHAR(180) NOT NULL,
  generation_prompt TEXT NULL,
  paper_config JSON NULL,
  status ENUM('draft', 'ready', 'archived') NOT NULL DEFAULT 'draft',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_generated_papers_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_generated_papers_document
    FOREIGN KEY (source_document_id) REFERENCES documents(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_generated_papers_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_imports (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  question_bank_id BIGINT UNSIGNED NULL,
  source_type ENUM('excel', 'document_ai') NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  status ENUM('pending', 'processing', 'success', 'failed') NOT NULL DEFAULT 'pending',
  total_rows INT UNSIGNED NOT NULL DEFAULT 0,
  success_rows INT UNSIGNED NOT NULL DEFAULT 0,
  failed_rows INT UNSIGNED NOT NULL DEFAULT 0,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_question_imports_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_question_imports_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_import_rows (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  import_id BIGINT UNSIGNED NOT NULL,
  `row_number` INT UNSIGNED NOT NULL,  -- 用反引号包裹
  raw_data JSON NOT NULL,
  status ENUM('success', 'failed') NOT NULL,
  error_message TEXT NULL,
  created_question_id BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_question_import_rows_import
    FOREIGN KEY (import_id) REFERENCES question_imports(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE questions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_bank_id BIGINT UNSIGNED NOT NULL,
  subject_id BIGINT UNSIGNED NULL,
  source_document_id BIGINT UNSIGNED NULL,
  import_id BIGINT UNSIGNED NULL,
  type ENUM('single_choice', 'multiple_choice', 'true_false', 'blank', 'short_answer', 'essay') NOT NULL,
  stem TEXT NOT NULL,
  analysis TEXT NULL,
  difficulty TINYINT UNSIGNED NOT NULL DEFAULT 3 COMMENT '1 easiest, 5 hardest',
  score DECIMAL(5,2) NOT NULL DEFAULT 1.00,
  knowledge_point VARCHAR(255) NULL,
  ai_generated TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('draft', 'active', 'archived') NOT NULL DEFAULT 'active',
  extra JSON NULL COMMENT 'Extensible fields, e.g. images, audio, formula, source page',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_questions_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_questions_subject
    FOREIGN KEY (subject_id) REFERENCES subjects(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_questions_document
    FOREIGN KEY (source_document_id) REFERENCES documents(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_questions_import
    FOREIGN KEY (import_id) REFERENCES question_imports(id)
    ON DELETE SET NULL,
  INDEX idx_questions_filter (question_bank_id, type, difficulty, status),
  FULLTEXT KEY ft_questions_stem (stem, analysis, knowledge_point)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE question_import_rows
  ADD CONSTRAINT fk_question_import_rows_question
  FOREIGN KEY (created_question_id) REFERENCES questions(id)
  ON DELETE SET NULL;

CREATE TABLE question_options (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  option_key VARCHAR(8) NOT NULL COMMENT 'A, B, C, D...',
  content TEXT NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_question_options_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_question_options_key (question_id, option_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_answers (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  answer_text TEXT NOT NULL,
  answer_json JSON NULL COMMENT 'For multi-blank, rubric, structured answer',
  is_primary TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_question_answers_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_tags (
  question_id BIGINT UNSIGNED NOT NULL,
  tag_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (question_id, tag_id),
  CONSTRAINT fk_question_tags_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_question_tags_tag
    FOREIGN KEY (tag_id) REFERENCES tags(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_question_records (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  is_favorite TINYINT(1) NOT NULL DEFAULT 0,
  note TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_question_records_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_user_question_records_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_user_question_records_user_question (user_id, question_id),
  INDEX idx_user_question_records_favorite (user_id, is_favorite, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE practice_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  question_bank_id BIGINT UNSIGNED NULL,
  mode ENUM('random', 'wrong_only', 'tag', 'paper', 'review') NOT NULL DEFAULT 'random',
  filter_config JSON NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at DATETIME NULL,
  total_count INT UNSIGNED NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  duration_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_practice_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_practice_sessions_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id)
    ON DELETE SET NULL,
  INDEX idx_practice_sessions_user_time (user_id, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE practice_answers (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  session_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  user_answer TEXT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  used_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  review_status ENUM('new', 'mastered', 'needs_review') NOT NULL DEFAULT 'new',
  answered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_practice_answers_session
    FOREIGN KEY (session_id) REFERENCES practice_sessions(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_practice_answers_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_practice_answers_question
    FOREIGN KEY (question_id) REFERENCES questions(id)
    ON DELETE CASCADE,
  INDEX idx_practice_answers_user_question (user_id, question_id),
  INDEX idx_practice_answers_user_correct (user_id, is_correct, answered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE review_schedules (
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

CREATE TABLE daily_review_plans (
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

CREATE TABLE daily_review_tasks (
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

CREATE TABLE diary_entries (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  entry_date DATE NOT NULL,
  mood_score TINYINT UNSIGNED NULL COMMENT '1-10',
  title VARCHAR(160) NULL,
  content TEXT NOT NULL,
  tags JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_diary_entries_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_diary_user_date (user_id, entry_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE diary_ai_reports (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  diary_entry_id BIGINT UNSIGNED NOT NULL,
  sentiment ENUM('positive', 'neutral', 'negative', 'mixed') NOT NULL DEFAULT 'neutral',
  summary TEXT NULL,
  suggestions TEXT NULL,
  risk_level ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'low',
  raw_result JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_diary_ai_reports_entry
    FOREIGN KEY (diary_entry_id) REFERENCES diary_entries(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE learning_analytics (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  stat_date DATE NOT NULL,
  metric_name VARCHAR(80) NOT NULL,
  metric_value DECIMAL(12,2) NOT NULL DEFAULT 0,
  dimension JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_learning_analytics_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_learning_analytics_metric (user_id, stat_date, metric_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_conversations (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(180) NOT NULL DEFAULT 'AI辅学对话',
  scene ENUM('qa', 'explain_question', 'study_plan', 'diary_analysis', 'paper_generation') NOT NULL DEFAULT 'qa',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_ai_conversations_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_messages (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  role ENUM('user', 'assistant', 'system') NOT NULL,
  content LONGTEXT NOT NULL,
  related_question_id BIGINT UNSIGNED NULL,
  token_usage JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ai_messages_conversation
    FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_ai_messages_question
    FOREIGN KEY (related_question_id) REFERENCES questions(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users (id, username, password, nickname, email, role)
VALUES
  (1, 'student1', '123456', '演示学生', 'student1@example.com', 'student'),
  (2, 'teacher1', '123456', '演示老师', 'teacher1@example.com', 'teacher');

INSERT INTO subjects (id, name, stage, description)
VALUES
  (1, '数学', 'high_school', '高中数学基础与提升'),
  (2, '英语', 'high_school', '高中英语词汇、阅读与语法');

INSERT INTO question_banks (id, owner_user_id, subject_id, name, description, visibility, source_type)
VALUES
  (1, 2, 1, '高中数学函数基础', '演示题库，后续可由 Excel 或 AI 文档生成扩充。', 'public', 'manual'),
  (2, 2, 2, '英语语法选择题', '演示英语题库。', 'public', 'manual');

INSERT INTO tags (id, name, category, color)
VALUES
  (1, '函数', 'knowledge', '#2563EB'),
  (2, '选择题', 'type', '#059669'),
  (3, '易错', 'status', '#DC2626'),
  (4, '语法', 'knowledge', '#7C3AED');

INSERT INTO questions (id, question_bank_id, subject_id, type, stem, analysis, difficulty, score, knowledge_point, ai_generated, status)
VALUES
  (1, 1, 1, 'single_choice', '函数 f(x)=2x+1，当 x=3 时，f(x) 的值是？', '把 x=3 代入 2x+1，得到 2*3+1=7。', 1, 2.00, '一次函数求值', 0, 'active'),
  (2, 1, 1, 'true_false', '若函数 y=x^2，则当 x 取相反数时，函数值不变。', '平方函数满足 f(-x)=f(x)，所以说法正确。', 2, 2.00, '偶函数性质', 0, 'active'),
  (3, 2, 2, 'single_choice', 'She ____ to school by bus every day.', '主语 She 是第三人称单数，一般现在时谓语动词用 goes。', 1, 2.00, '一般现在时', 0, 'active');

INSERT INTO question_options (question_id, option_key, content, is_correct, sort_order)
VALUES
  (1, 'A', '5', 0, 1),
  (1, 'B', '6', 0, 2),
  (1, 'C', '7', 1, 3),
  (1, 'D', '8', 0, 4),
  (3, 'A', 'go', 0, 1),
  (3, 'B', 'goes', 1, 2),
  (3, 'C', 'went', 0, 3),
  (3, 'D', 'going', 0, 4);

INSERT INTO question_answers (question_id, answer_text, answer_json, is_primary)
VALUES
  (1, 'C', JSON_OBJECT('option_keys', JSON_ARRAY('C')), 1),
  (2, '正确', JSON_OBJECT('value', true), 1),
  (3, 'B', JSON_OBJECT('option_keys', JSON_ARRAY('B')), 1);

INSERT INTO question_tags (question_id, tag_id)
VALUES
  (1, 1), (1, 2),
  (2, 1),
  (3, 2), (3, 4);

INSERT INTO diary_entries (id, user_id, entry_date, mood_score, title, content, tags)
VALUES
  (1, 1, CURRENT_DATE, 7, '第一次使用辅学 APP', '今天完成了函数基础练习，错题主要集中在概念理解。', JSON_ARRAY('数学', '复盘'));

INSERT INTO learning_analytics (user_id, stat_date, metric_name, metric_value, dimension)
VALUES
  (1, CURRENT_DATE, 'practice_count', 8, JSON_OBJECT('subject', '数学')),
  (1, CURRENT_DATE, 'accuracy_rate', 75, JSON_OBJECT('subject', '数学'));
