USE ai_for_study;

CREATE TABLE IF NOT EXISTS knowledge_nodes (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  question_bank_id BIGINT UNSIGNED NOT NULL,
  node_type ENUM('course', 'knowledge') NOT NULL DEFAULT 'knowledge',
  name VARCHAR(255) NOT NULL,
  description VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_knowledge_nodes_user
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_knowledge_nodes_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id) ON DELETE CASCADE,
  UNIQUE KEY uk_knowledge_node_bank_type_name (question_bank_id, node_type, name),
  INDEX idx_knowledge_nodes_owner (owner_user_id, question_bank_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS knowledge_relations (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_bank_id BIGINT UNSIGNED NOT NULL,
  source_node_id BIGINT UNSIGNED NOT NULL,
  target_node_id BIGINT UNSIGNED NOT NULL,
  relation_type ENUM('contains', 'related', 'prerequisite') NOT NULL DEFAULT 'related',
  weight DECIMAL(6,2) NOT NULL DEFAULT 1.00,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_knowledge_relations_bank
    FOREIGN KEY (question_bank_id) REFERENCES question_banks(id) ON DELETE CASCADE,
  CONSTRAINT fk_knowledge_relations_source
    FOREIGN KEY (source_node_id) REFERENCES knowledge_nodes(id) ON DELETE CASCADE,
  CONSTRAINT fk_knowledge_relations_target
    FOREIGN KEY (target_node_id) REFERENCES knowledge_nodes(id) ON DELETE CASCADE,
  UNIQUE KEY uk_knowledge_relation (source_node_id, target_node_id, relation_type),
  INDEX idx_knowledge_relations_bank (question_bank_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
