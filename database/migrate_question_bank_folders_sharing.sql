USE ai_for_study;

CREATE TABLE IF NOT EXISTS question_bank_folders (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(80) NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_question_bank_folders_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_question_bank_folders_user_name (user_id, name),
  INDEX idx_question_bank_folders_user_sort (user_id, sort_order, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE question_banks
  ADD COLUMN folder_id BIGINT UNSIGNED NULL AFTER subject_id,
  ADD CONSTRAINT fk_question_banks_folder
    FOREIGN KEY (folder_id) REFERENCES question_bank_folders(id)
    ON DELETE SET NULL,
  ADD INDEX idx_question_banks_folder (folder_id);

CREATE TABLE IF NOT EXISTS question_bank_shares (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_bank_id BIGINT UNSIGNED NOT NULL,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  share_code VARCHAR(20) NOT NULL,
  status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
  expires_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_question_bank_shares_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_question_bank_shares_owner
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uk_question_bank_shares_code (share_code),
  INDEX idx_question_bank_shares_owner_bank (owner_user_id, question_bank_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS question_bank_share_members (
  share_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (share_id, user_id),
  CONSTRAINT fk_question_bank_share_members_share
    FOREIGN KEY (share_id) REFERENCES question_bank_shares(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_question_bank_share_members_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_question_bank_share_members_user (user_id, joined_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
