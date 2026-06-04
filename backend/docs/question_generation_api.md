# 文档出题 API 说明

本文档说明后端中智谱 AI 出题接口的用法和返回格式。

## 1. 功能定位

当前后端支持两种方式：

- 文本出题：把已经解析好的课程文本传给智谱 AI。
- 文件出题：上传 PPTX、DOCX、TXT、PDF，后端自动解析文本，再传给智谱 AI。

当前文件出题流程：

1. 前端通过系统文件选择器选择 Word/PPT/PDF/TXT。
2. 前端上传文件到 Flask。
3. 后端解析文档文本。
4. 后端调用智谱 AI 生成结构化题目。
5. 后端校验 AI 返回结果。
6. 后端写入 `question_banks`、`questions`、`question_options`、`question_answers`、`tags`、`question_tags`。
7. 后端返回题目预览和保存结果。

## 2. 环境变量

在 `backend/.env` 中配置：

```env
ZHIPU_API_KEY=your-api-key
ZHIPU_MODEL=glm-4.7-flash
```

依赖安装：

```bash
pip install -r backend/requirements.txt
```

## 3. 接口地址

### 3.1 文本出题

```http
POST /api/ai/generate-questions
```

### 3.2 文件出题

```http
POST /api/documents/generate-questions-from-file
Content-Type: multipart/form-data
```

文件出题表单字段：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| file | 是 | 课程文档，支持 pptx、docx、txt、pdf |
| subject | 否 | 学科名称 |
| question_count | 否 | 生成题目数量，后端限制在 1 到 30 |
| question_types | 否 | 英文逗号分隔，例如 `single_choice,short_answer` |
| difficulty | 否 | 难度，1 到 5 |
| extra_prompt | 否 | 额外出题要求 |
| save_to_db | 否 | 是否生成后直接保存到数据库，默认 true |
| owner_user_id | 否 | 题库创建者用户 ID |
| question_bank_id | 否 | 保存到已有题库；不传则自动创建新题库 |

## 4. 请求体

```json
{
  "document_text": "这里放从 Word、PPT 或 PDF 中解析出来的课程资料文本。",
  "subject": "数学",
  "question_count": 5,
  "question_types": ["single_choice", "true_false", "blank", "short_answer"],
  "difficulty": 3,
  "extra_prompt": "题目偏基础，适合课堂随堂练习。",
  "save_to_db": true,
  "owner_user_id": 1,
  "question_bank_id": null
}
```

字段说明：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| document_text | 是 | 文档解析后的文本内容 |
| subject | 否 | 学科名称 |
| question_count | 否 | 生成题目数量，后端限制在 1 到 30 |
| question_types | 否 | 题型数组 |
| difficulty | 否 | 难度，1 到 5 |
| extra_prompt | 否 | 额外出题要求 |
| save_to_db | 否 | 是否生成后直接保存到数据库 |
| owner_user_id | 否 | 题库创建者用户 ID，不传则使用数据库中的第一个用户 |
| question_bank_id | 否 | 保存到已有题库；不传则自动创建新题库 |

可用题型：

| type | 说明 |
| --- | --- |
| single_choice | 单选题 |
| multiple_choice | 多选题 |
| true_false | 判断题 |
| blank | 填空题 |
| short_answer | 简答题 |
| essay | 作文或论述题 |

## 5. 成功返回

```json
{
  "success": true,
  "message": "AI 出题成功",
  "data": {
    "question_bank": {
      "name": "AI 生成题库",
      "description": "根据课程资料生成",
      "subject": "数学",
      "source_type": "document_ai"
    },
    "questions": [
      {
        "type": "single_choice",
        "stem": "函数 f(x)=2x+1，当 x=3 时，f(x) 的值是？",
        "analysis": "把 x=3 代入 2x+1，得到 7。",
        "difficulty": 1,
        "score": 2.0,
        "knowledge_point": "一次函数求值",
        "tags": ["函数", "一次函数"],
        "options": [
          {
            "option_key": "A",
            "content": "5",
            "is_correct": false,
            "sort_order": 1
          },
          {
            "option_key": "B",
            "content": "7",
            "is_correct": true,
            "sort_order": 2
          }
        ],
        "answers": [
          {
            "answer_text": "B",
            "answer_json": {
              "option_keys": ["B"]
            },
            "is_primary": true
          }
        ],
        "extra": {
          "source_excerpt": "原文片段"
        }
      }
    ],
    "saved": {
      "question_bank_id": 3,
      "subject_id": 1,
      "saved_count": 5,
      "question_ids": [10, 11, 12, 13, 14]
    }
  }
}
```

如果请求中 `save_to_db` 为 `false` 或不传，则不会返回 `saved` 字段。

## 6. 返回结果和数据库表的对应关系

| 返回字段 | 对应表 | 对应字段 |
| --- | --- | --- |
| question_bank.name | question_banks | name |
| question_bank.description | question_banks | description |
| question_bank.source_type | question_banks | source_type |
| questions[].type | questions | type |
| questions[].stem | questions | stem |
| questions[].analysis | questions | analysis |
| questions[].difficulty | questions | difficulty |
| questions[].score | questions | score |
| questions[].knowledge_point | questions | knowledge_point |
| questions[].extra | questions | extra |
| questions[].options[] | question_options | option_key、content、is_correct、sort_order |
| questions[].answers[] | question_answers | answer_text、answer_json、is_primary |
| questions[].tags[] | tags、question_tags | name、关联关系 |

## 7. 单独保存已生成题目

如果前端希望先预览，再由用户点击“保存题库”，可以调用：

```http
POST /api/questions/save-generated
```

请求体：

```json
{
  "generated": {
    "question_bank": {
      "name": "AI 生成题库",
      "description": "根据课程资料生成",
      "subject": "数学",
      "source_type": "document_ai"
    },
    "questions": []
  },
  "owner_user_id": 1,
  "question_bank_id": null
}
```

返回：

```json
{
  "success": true,
  "message": "题目保存成功",
  "data": {
    "question_bank_id": 3,
    "subject_id": 1,
    "saved_count": 5,
    "question_ids": [10, 11, 12, 13, 14]
  }
}
```

## 8. 是否需要视觉能力

如果 Word/PPT 里主要是可复制文本，暂时不需要视觉模型，先用文档解析库提取文本即可。

如果资料里有以下内容，则后续可能需要视觉或 OCR：

- PPT 截图里包含大量文字。
- 图片形式的公式。
- 图表、流程图、实验装置图。
- 扫描版 PDF。
- 题目需要根据图片内容生成。

建议第一阶段先做文本解析加出题；第二阶段再补 OCR/视觉理解。
