# AIForStudy 数据库设计说明

本文档说明 `schema.sql` 中创建的数据库和所有业务表。

## 1. 数据库概览

数据库名称：`ai_for_study`

数据库用途：支撑辅学 APP 的用户管理、题库管理、Excel/文档导入、AI 出题、刷题记录、错题筛选、学习日记、AI 分析、学习统计和 AI 辅学对话等功能。

设计原则：

- 题目主表、选项表、答案表、标签表分离，便于支持多种题型。
- 题库、题目、导入任务、上传文档之间保留来源关系，方便追踪题目来源。
- 刷题过程和每道题的作答记录分离，方便统计正确率、错题和复习状态。
- 日记、AI 分析、学习统计、AI 对话独立建表，便于后续扩展 AI 功能。
- 多处使用 JSON 字段保存扩展信息，方便后续增加字段而不频繁改表。

## 2. 表关系概览

主要关系如下：

- 一个用户可以拥有多个题库、上传多个文档、创建多次刷题记录、写多篇日记、发起多个 AI 对话。
- 一个题库可以包含多道题。
- 一道题可以有多个选项、多个答案、多个标签。
- 一次刷题会话可以包含多条答题记录。
- 一个文档可以作为 AI 出题或题目生成的来源。
- 一篇日记可以生成一条或多条 AI 分析报告。
- 一个 AI 对话包含多条消息。

## 3. 用户相关表

### 3.1 users

用户表，保存 APP 用户的基础信息。

主要用途：

- 注册账号。
- 登录校验。
- 区分学生、教师、管理员。
- 管理用户状态。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 用户主键 |
| username | VARCHAR(64) | 用户名，唯一 |
| password | VARCHAR(128) | 密码，当前按需求明文存储 |
| nickname | VARCHAR(64) | 昵称 |
| email | VARCHAR(128) | 邮箱，可为空，唯一 |
| avatar_url | VARCHAR(512) | 头像地址 |
| role | ENUM | 用户角色：student、teacher、admin |
| status | ENUM | 用户状态：active、disabled |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

说明：

当前阶段密码直接明文存储，方便课程项目演示。正式项目中应改为哈希加密存储。

### 3.2 user_sessions

用户登录会话表，保存登录后生成的 token。

主要用途：

- 保存用户登录状态。
- 后端通过 token 判断当前请求属于哪个用户。
- 支持登录过期。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 会话主键 |
| user_id | BIGINT UNSIGNED | 关联用户 ID |
| token | VARCHAR(128) | 登录令牌，唯一 |
| expires_at | DATETIME | 过期时间 |
| created_at | DATETIME | 创建时间 |

关系：

- `user_id` 外键关联 `users.id`。
- 用户删除后，对应会话自动删除。

## 4. 学科和题库相关表

### 4.1 subjects

学科表，用于对题库、题目、文档进行学科分类。

主要用途：

- 区分数学、英语、语文等学科。
- 后续支持按学段、学科筛选学习内容。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 学科主键 |
| name | VARCHAR(64) | 学科名称，唯一 |
| stage | VARCHAR(64) | 学习阶段，例如 high_school |
| description | VARCHAR(255) | 学科说明 |
| created_at | DATETIME | 创建时间 |

### 4.2 question_banks

题库表，用于组织题目集合。

主要用途：

- 保存用户创建的题库。
- 承载 Excel 导入题目。
- 承载 AI 从文档生成的题目。
- 后续支持公开题库、班级题库和私有题库。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 题库主键 |
| owner_user_id | BIGINT UNSIGNED | 题库创建者 |
| subject_id | BIGINT UNSIGNED | 所属学科 |
| name | VARCHAR(128) | 题库名称 |
| description | TEXT | 题库说明 |
| visibility | ENUM | 可见性：private、class、public |
| source_type | ENUM | 来源：manual、excel、document_ai、paper_ai |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

关系：

- `owner_user_id` 外键关联 `users.id`。
- `subject_id` 外键关联 `subjects.id`。

### 4.3 tags

标签表，用于保存题目的标签。

主要用途：

- 给题目打知识点标签。
- 给题目打状态标签，例如易错。
- 支持刷题时按标签筛选。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 标签主键 |
| name | VARCHAR(64) | 标签名称 |
| category | VARCHAR(64) | 标签类别，默认 knowledge |
| color | VARCHAR(16) | 标签颜色 |
| created_at | DATETIME | 创建时间 |

说明：

`name` 和 `category` 组合唯一。例如同名标签在不同类别下可以共存。

## 5. 文档与 AI 生成相关表

### 5.1 documents

上传文档表，保存用户上传的 PPT、Word、PDF 等资料。

主要用途：

- 保存上传文件的基本信息。
- 保存文档解析结果。
- 作为 AI 生成题库或试卷的来源。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 文档主键 |
| owner_user_id | BIGINT UNSIGNED | 上传用户 |
| subject_id | BIGINT UNSIGNED | 所属学科 |
| title | VARCHAR(180) | 文档标题 |
| file_name | VARCHAR(255) | 原始文件名 |
| file_type | ENUM | 文件类型：ppt、pptx、doc、docx、pdf、txt、other |
| storage_path | VARCHAR(512) | 文件存储路径 |
| parse_status | ENUM | 解析状态：uploaded、parsing、parsed、failed |
| extracted_text | LONGTEXT | 文档解析出的文本 |
| ai_summary | TEXT | AI 总结 |
| metadata | JSON | 文档元数据 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

关系：

- `owner_user_id` 外键关联 `users.id`。
- `subject_id` 外键关联 `subjects.id`。

### 5.2 generated_papers

AI 生成试卷表，保存 AI 出卷记录。

主要用途：

- 记录一次 AI 生成试卷任务。
- 保存生成提示词和生成配置。
- 关联来源文档和生成后的题库。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 试卷主键 |
| owner_user_id | BIGINT UNSIGNED | 创建用户 |
| source_document_id | BIGINT UNSIGNED | 来源文档 |
| question_bank_id | BIGINT UNSIGNED | 生成题目保存到的题库 |
| title | VARCHAR(180) | 试卷标题 |
| generation_prompt | TEXT | AI 生成提示词 |
| paper_config | JSON | 出卷配置 |
| status | ENUM | 状态：draft、ready、archived |
| created_at | DATETIME | 创建时间 |

关系：

- `owner_user_id` 外键关联 `users.id`。
- `source_document_id` 外键关联 `documents.id`。
- `question_bank_id` 外键关联 `question_banks.id`。

### 5.3 question_imports

题目导入任务表，保存一次 Excel 导入或文档 AI 生成题目的任务记录。

主要用途：

- 记录导入来源。
- 统计导入成功和失败数量。
- 保存导入失败原因。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 导入任务主键 |
| owner_user_id | BIGINT UNSIGNED | 导入用户 |
| question_bank_id | BIGINT UNSIGNED | 导入到的题库 |
| source_type | ENUM | 来源：excel、document_ai |
| file_name | VARCHAR(255) | 文件名 |
| status | ENUM | 状态：pending、processing、success、failed |
| total_rows | INT UNSIGNED | 总行数 |
| success_rows | INT UNSIGNED | 成功行数 |
| failed_rows | INT UNSIGNED | 失败行数 |
| error_message | TEXT | 错误信息 |
| created_at | DATETIME | 创建时间 |

关系：

- `owner_user_id` 外键关联 `users.id`。
- `question_bank_id` 外键关联 `question_banks.id`。

### 5.4 question_import_rows

题目导入行明细表，保存导入过程中每一行的处理结果。

主要用途：

- 记录 Excel 每一行原始数据。
- 标记每一行是否成功生成题目。
- 保存失败行的错误原因。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 行明细主键 |
| import_id | BIGINT UNSIGNED | 所属导入任务 |
| row_number | INT UNSIGNED | 原始行号 |
| raw_data | JSON | 原始行数据 |
| status | ENUM | 状态：success、failed |
| error_message | TEXT | 失败原因 |
| created_question_id | BIGINT UNSIGNED | 成功创建的题目 ID |
| created_at | DATETIME | 创建时间 |

关系：

- `import_id` 外键关联 `question_imports.id`。
- `created_question_id` 外键关联 `questions.id`。

## 6. 题目相关表

### 6.1 questions

题目主表，保存题目的核心内容。

主要用途：

- 保存题干、题型、解析、难度、分值等信息。
- 关联所属题库、学科、来源文档和导入任务。
- 支持 AI 生成题目的标识。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 题目主键 |
| question_bank_id | BIGINT UNSIGNED | 所属题库 |
| subject_id | BIGINT UNSIGNED | 所属学科 |
| source_document_id | BIGINT UNSIGNED | 来源文档 |
| import_id | BIGINT UNSIGNED | 来源导入任务 |
| type | ENUM | 题型 |
| stem | TEXT | 题干 |
| analysis | TEXT | 解析 |
| difficulty | TINYINT UNSIGNED | 难度，1 最简单，5 最难 |
| score | DECIMAL(5,2) | 分值 |
| knowledge_point | VARCHAR(255) | 知识点 |
| ai_generated | TINYINT(1) | 是否 AI 生成 |
| status | ENUM | 状态：draft、active、archived |
| extra | JSON | 扩展字段 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

题型说明：

| type | 说明 |
| --- | --- |
| single_choice | 单选题 |
| multiple_choice | 多选题 |
| true_false | 判断题 |
| blank | 填空题 |
| short_answer | 简答题 |
| essay | 作文或论述题 |

关系：

- `question_bank_id` 外键关联 `question_banks.id`。
- `subject_id` 外键关联 `subjects.id`。
- `source_document_id` 外键关联 `documents.id`。
- `import_id` 外键关联 `question_imports.id`。

### 6.2 question_options

题目选项表，保存选择题的选项。

主要用途：

- 保存单选题和多选题的 A、B、C、D 等选项。
- 标记选项是否正确。
- 控制选项展示顺序。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 选项主键 |
| question_id | BIGINT UNSIGNED | 所属题目 |
| option_key | VARCHAR(8) | 选项标识，例如 A、B、C |
| content | TEXT | 选项内容 |
| is_correct | TINYINT(1) | 是否正确选项 |
| sort_order | INT UNSIGNED | 排序 |

关系：

- `question_id` 外键关联 `questions.id`。

说明：

非选择题不一定需要使用该表。

### 6.3 question_answers

题目答案表，保存题目的标准答案。

主要用途：

- 保存标准答案文本。
- 保存结构化答案。
- 支持一个题目多个答案。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 答案主键 |
| question_id | BIGINT UNSIGNED | 所属题目 |
| answer_text | TEXT | 答案文本 |
| answer_json | JSON | 结构化答案 |
| is_primary | TINYINT(1) | 是否主答案 |

关系：

- `question_id` 外键关联 `questions.id`。

说明：

`answer_json` 可以用于多选题答案数组、填空题多个空位、简答题评分规则等。

### 6.4 question_tags

题目标签关联表。

主要用途：

- 建立题目和标签的多对多关系。
- 支持一道题多个知识点标签。
- 支持按标签筛选题目。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| question_id | BIGINT UNSIGNED | 题目 ID |
| tag_id | BIGINT UNSIGNED | 标签 ID |

关系：

- `question_id` 外键关联 `questions.id`。
- `tag_id` 外键关联 `tags.id`。

## 7. 刷题相关表

### 7.1 practice_sessions

刷题会话表，记录用户一次完整的刷题过程。

主要用途：

- 保存一次刷题开始和结束时间。
- 记录刷题模式。
- 记录本次刷题统计数据。
- 保存筛选条件。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 刷题会话主键 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| question_bank_id | BIGINT UNSIGNED | 题库 ID |
| mode | ENUM | 刷题模式 |
| filter_config | JSON | 筛选条件 |
| started_at | DATETIME | 开始时间 |
| finished_at | DATETIME | 结束时间 |
| total_count | INT UNSIGNED | 题目总数 |
| correct_count | INT UNSIGNED | 正确数量 |
| wrong_count | INT UNSIGNED | 错误数量 |
| duration_seconds | INT UNSIGNED | 用时秒数 |

刷题模式说明：

| mode | 说明 |
| --- | --- |
| random | 随机刷题 |
| wrong_only | 只刷错题 |
| tag | 按标签刷题 |
| paper | 试卷模式 |
| review | 复习模式 |

关系：

- `user_id` 外键关联 `users.id`。
- `question_bank_id` 外键关联 `question_banks.id`。

### 7.2 practice_answers

用户答题记录表，记录用户对每道题的作答情况。

主要用途：

- 判断某道题是否做过。
- 判断某道题是否做错过。
- 支持错题本。
- 支持正确率、用时、复习状态统计。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 答题记录主键 |
| session_id | BIGINT UNSIGNED | 所属刷题会话 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| question_id | BIGINT UNSIGNED | 题目 ID |
| user_answer | TEXT | 用户答案 |
| is_correct | TINYINT(1) | 是否正确 |
| used_seconds | INT UNSIGNED | 作答用时 |
| review_status | ENUM | 复习状态 |
| answered_at | DATETIME | 作答时间 |

复习状态说明：

| review_status | 说明 |
| --- | --- |
| new | 新记录 |
| mastered | 已掌握 |
| needs_review | 需要复习 |

关系：

- `session_id` 外键关联 `practice_sessions.id`。
- `user_id` 外键关联 `users.id`。
- `question_id` 外键关联 `questions.id`。

### 7.3 user_question_records

用户题目个性化记录表，用于保存每个用户自己的收藏状态和题目笔记。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 记录主键 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| question_id | BIGINT UNSIGNED | 题目 ID |
| is_favorite | TINYINT(1) | 是否收藏 |
| note | TEXT | 用户题目笔记 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

`user_id + question_id` 使用唯一索引，保证同一用户对同一道题只有一条个性化记录。

## 8. 日记与 AI 分析相关表

### 8.1 diary_entries

学习日记表，保存用户每天的学习记录和心得。

主要用途：

- 用户每天记录学习状态。
- 后续给 AI 分析学习情绪、压力和计划。
- 支持按日期查看日记。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 日记主键 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| entry_date | DATE | 日记日期 |
| mood_score | TINYINT UNSIGNED | 心情分数，建议 1 到 10 |
| title | VARCHAR(160) | 标题 |
| content | TEXT | 日记内容 |
| tags | JSON | 日记标签 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

关系：

- `user_id` 外键关联 `users.id`。
- 同一用户同一天只能有一篇日记。

### 8.2 diary_ai_reports

日记 AI 分析报告表。

主要用途：

- 保存 AI 对日记内容的情绪分析。
- 保存 AI 总结和学习建议。
- 标记风险等级。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | AI 分析报告主键 |
| diary_entry_id | BIGINT UNSIGNED | 关联日记 |
| sentiment | ENUM | 情绪倾向 |
| summary | TEXT | AI 总结 |
| suggestions | TEXT | AI 建议 |
| risk_level | ENUM | 风险等级 |
| raw_result | JSON | AI 原始返回结果 |
| created_at | DATETIME | 创建时间 |

情绪类型：

| sentiment | 说明 |
| --- | --- |
| positive | 正向 |
| neutral | 中性 |
| negative | 负向 |
| mixed | 混合 |

风险等级：

| risk_level | 说明 |
| --- | --- |
| low | 低风险 |
| medium | 中风险 |
| high | 高风险 |

关系：

- `diary_entry_id` 外键关联 `diary_entries.id`。

## 9. 学习统计表

### 9.1 learning_analytics

学习统计表，保存用户每天的各类学习指标。

主要用途：

- 首页学习数据展示。
- 正确率趋势分析。
- 刷题数量统计。
- 按学科、题库、标签做维度分析。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 统计记录主键 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| stat_date | DATE | 统计日期 |
| metric_name | VARCHAR(80) | 指标名称 |
| metric_value | DECIMAL(12,2) | 指标值 |
| dimension | JSON | 统计维度 |
| created_at | DATETIME | 创建时间 |

示例：

- `metric_name = practice_count` 表示刷题数量。
- `metric_name = accuracy_rate` 表示正确率。
- `dimension = {"subject": "数学"}` 表示统计维度是数学学科。

关系：

- `user_id` 外键关联 `users.id`。
- 同一用户、同一天、同一个指标只能有一条记录。

## 10. AI 辅学对话相关表

### 10.1 ai_conversations

AI 对话会话表，保存一次 AI 辅学对话。

主要用途：

- 保存用户和 AI 的一次完整对话。
- 区分普通问答、题目讲解、学习计划、日记分析、出卷等场景。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 对话主键 |
| user_id | BIGINT UNSIGNED | 用户 ID |
| title | VARCHAR(180) | 对话标题 |
| scene | ENUM | 对话场景 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

场景说明：

| scene | 说明 |
| --- | --- |
| qa | 普通问答 |
| explain_question | 题目讲解 |
| study_plan | 学习计划 |
| diary_analysis | 日记分析 |
| paper_generation | 试卷生成 |

关系：

- `user_id` 外键关联 `users.id`。

### 10.2 ai_messages

AI 对话消息表，保存一次对话中的每条消息。

主要用途：

- 保存用户提问。
- 保存 AI 回复。
- 保存 system 提示词。
- 关联具体题目，支持错题讲解场景。
- 保存 token 用量。

关键字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 消息主键 |
| conversation_id | BIGINT UNSIGNED | 所属对话 |
| role | ENUM | 角色：user、assistant、system |
| content | LONGTEXT | 消息内容 |
| related_question_id | BIGINT UNSIGNED | 关联题目 |
| token_usage | JSON | token 使用情况 |
| created_at | DATETIME | 创建时间 |

关系：

- `conversation_id` 外键关联 `ai_conversations.id`。
- `related_question_id` 外键关联 `questions.id`。

## 11. 文档知识库相关表

### 11.1 knowledge_bases

知识库主表。每个用户可以按课程或专题创建多个知识库。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 知识库主键 |
| owner_user_id | BIGINT UNSIGNED | 所属用户 |
| name | VARCHAR(120) | 知识库名称 |
| description | VARCHAR(500) | 知识库描述 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

### 11.2 knowledge_base_documents

知识库与 `documents` 的关联表。一个知识库可以包含多份文档，一份文档也可以扩展为被多个知识库引用。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| knowledge_base_id | BIGINT UNSIGNED | 知识库 ID |
| document_id | BIGINT UNSIGNED | 文档 ID |
| created_at | DATETIME | 加入时间 |

### 11.3 document_chunks

文档片段表。上传的文档解析为文本后，会按长度和段落拆分，用于检索相关资料。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 片段主键 |
| document_id | BIGINT UNSIGNED | 来源文档 |
| chunk_index | INT UNSIGNED | 文档内片段序号 |
| content | TEXT | 片段原文 |
| char_start | INT UNSIGNED | 原文起始位置 |
| char_end | INT UNSIGNED | 原文结束位置 |
| metadata | JSON | 来源页码等扩展信息 |

### 11.4 knowledge_queries

知识库问答记录表，保存问题、AI 回答以及回答使用的资料来源。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT UNSIGNED | 问答记录主键 |
| knowledge_base_id | BIGINT UNSIGNED | 知识库 ID |
| user_id | BIGINT UNSIGNED | 提问用户 |
| question | TEXT | 用户问题 |
| answer | LONGTEXT | AI 回答 |
| sources | JSON | 命中文档和片段信息 |
| created_at | DATETIME | 提问时间 |

## 12. 初始数据说明

`schema.sql` 中包含一些演示数据，方便启动项目后立即测试。

### 12.1 初始用户

| 用户名 | 密码 | 昵称 | 角色 |
| --- | --- | --- | --- |
| student1 | 123456 | 演示学生 | student |
| teacher1 | 123456 | 演示老师 | teacher |

### 12.2 初始学科

| 学科 | 阶段 | 说明 |
| --- | --- | --- |
| 数学 | high_school | 高中数学基础与提升 |
| 英语 | high_school | 高中英语词汇、阅读与语法 |

### 12.3 初始题库

| 题库 | 学科 | 来源 |
| --- | --- | --- |
| 高中数学函数基础 | 数学 | manual |
| 英语语法选择题 | 英语 | manual |

### 12.4 初始题目

包含以下示例题：

- 一次函数求值单选题。
- 偶函数性质判断题。
- 英语一般现在时单选题。

### 12.5 初始统计和日记

包含一条演示学习日记，以及两条学习统计数据：

- `practice_count`
- `accuracy_rate`

## 13. 后续扩展建议

后续可以继续扩展：

- 增加班级表、班级成员表，支持教师给班级发题。
- 将知识库检索升级为 Embedding 向量检索。
- 增加错题本视图或接口，基于 `practice_answers` 查询即可。
- 增加文件上传记录的真实存储策略，例如本地文件、对象存储。
- 将用户密码从明文改为哈希存储。
- 增加 AI 调用日志表，保存模型名称、请求参数、耗时和费用。
- 增加题目图片、公式、音频等多媒体资源表。
