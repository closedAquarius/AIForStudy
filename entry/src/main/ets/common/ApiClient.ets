import http from '@ohos.net.http';
import util from '@ohos.util';
import { fileIo } from '@kit.CoreFileKit';

export interface LoginUser {
  id: number;
  username: string;
  nickname: string;
  email?: string;
  role: string;
}

export interface ApiResult {
  success: boolean;
  message: string;
  data?: AuthData;
}

export interface AuthData {
  token?: string;
  user?: LoginUser;
}

export interface QuestionOption {
  option_key: string;
  content: string;
  is_correct: boolean;
  sort_order: number;
}

export interface QuestionAnswer {
  answer_text: string;
  answer_json?: string;
  is_primary: boolean;
}

export interface GeneratedQuestion {
  type: string;
  stem: string;
  analysis: string;
  difficulty: number;
  score: number;
  knowledge_point: string;
  tags: string[];
  options: QuestionOption[];
  answers: QuestionAnswer[];
  extra?: string;
}

export interface GeneratedQuestionBank {
  name: string;
  description: string;
  subject: string;
  source_type: string;
}

export interface GenerateQuestionsData {
  question_bank: GeneratedQuestionBank;
  questions: GeneratedQuestion[];
  saved?: SaveGeneratedData;
  document?: UploadedDocumentInfo;
}

export interface GenerateQuestionsApiResult {
  success: boolean;
  message: string;
  data?: GenerateQuestionsData;
}

export interface SaveGeneratedData {
  question_bank_id: number;
  subject_id: number;
  saved_count: number;
  question_ids: number[];
}

export interface UploadedDocumentInfo {
  file_name: string;
  text_length: number;
  used_text_length: number;
}

export interface UploadGenerateOptions {
  subject: string;
  questionCount: number;
  questionTypes: string[];
  difficulty: number;
  extraPrompt: string;
  saveToDb: boolean;
  ownerUserId: number;
}

interface LoginRequest {
  username: string;
  password: string;
}

interface RegisterRequest {
  username: string;
  password: string;
  nickname: string;
}

interface GenerateQuestionsRequest {
  document_text: string;
  subject: string;
  question_count: number;
  question_types: string[];
  difficulty: number;
  extra_prompt: string;
  save_to_db: boolean;
  owner_user_id: number;
}

interface HttpHeader {
  'Content-Type': string;
}

interface MultipartField {
  name: string;
  value: string;
}

function createHttpHeader(contentType: string): HttpHeader {
  return {
    'Content-Type': contentType
  };
}

type RequestBody = LoginRequest | RegisterRequest | GenerateQuestionsRequest;
type ResponseBody = ApiResult | GenerateQuestionsApiResult;

// const API_BASE_URL: string = 'http://192.168.253.1:5000/api';
const API_BASE_URL: string = 'http://127.0.0.1:5000/api';

function postJson(path: string, body: RequestBody): Promise<ResponseBody> {
  return new Promise((resolve: (value: ResponseBody) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();
    request.request(
      `${API_BASE_URL}${path}`,
      {
        method: http.RequestMethod.POST,
        header: createHttpHeader('application/json'),
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 6000
      },
      (error, response) => {
        request.destroy();
        if (error) {
          reject(new Error(error.message));
          return;
        }

        try {
          const raw = response.result as string;
          resolve(JSON.parse(raw) as ResponseBody);
        } catch (parseError) {
          reject(new Error('后端响应解析失败'));
        }
      }
    );
  });
}

export function login(username: string, password: string): Promise<ApiResult> {
  const body: LoginRequest = {
    username: username,
    password: password
  };
  return postJson('/auth/login', body) as Promise<ApiResult>;
}

export function register(username: string, password: string, nickname: string): Promise<ApiResult> {
  const body: RegisterRequest = {
    username: username,
    password: password,
    nickname: nickname
  };
  return postJson('/auth/register', body) as Promise<ApiResult>;
}

export function generateQuestions(
  documentText: string,
  subject: string,
  questionCount: number,
  questionTypes: string[],
  difficulty: number,
  extraPrompt: string,
  saveToDb: boolean = true,
  ownerUserId: number = 1
): Promise<GenerateQuestionsApiResult> {
  const body: GenerateQuestionsRequest = {
    document_text: documentText,
    subject: subject,
    question_count: questionCount,
    question_types: questionTypes,
    difficulty: difficulty,
    extra_prompt: extraPrompt,
    save_to_db: saveToDb,
    owner_user_id: ownerUserId
  };
  return postJson('/ai/generate-questions', body) as Promise<GenerateQuestionsApiResult>;
}

export function generateQuestionsFromFile(
  filePath: string,
  fileName: string,
  options: UploadGenerateOptions
): Promise<GenerateQuestionsApiResult> {
  return new Promise((resolve: (value: GenerateQuestionsApiResult) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();
    const boundary = `AIForStudyBoundary${new Date().getTime()}`;
    const formData: MultipartField[] = [
      { name: 'subject', value: options.subject },
      { name: 'question_count', value: `${options.questionCount}` },
      { name: 'question_types', value: options.questionTypes.join(',') },
      { name: 'difficulty', value: `${options.difficulty}` },
      { name: 'extra_prompt', value: options.extraPrompt },
      { name: 'save_to_db', value: options.saveToDb ? 'true' : 'false' },
      { name: 'owner_user_id', value: `${options.ownerUserId}` }
    ];

    let body: ArrayBuffer;
    try {
      body = buildMultipartBody(boundary, formData, filePath, fileName);
    } catch (error) {
      request.destroy();
      reject(new Error(`读取文件失败：${(error as Error).message}`));
      return;
    }

    request.request(
      `${API_BASE_URL}/documents/generate-questions-from-file`,
      {
        method: http.RequestMethod.POST,
        header: createHttpHeader(`multipart/form-data; boundary=${boundary}`),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 300000
      },
      (error, response) => {
        request.destroy();
        if (error) {
          reject(new Error(error.message));
          return;
        }

        const statusCode = response.responseCode as number;
        const raw = response.result as string;
        if (statusCode < 200 || statusCode >= 300) {
          reject(new Error(`后端返回 ${statusCode}：${raw}`));
          return;
        }

        try {
          resolve(JSON.parse(raw) as GenerateQuestionsApiResult);
        } catch (parseError) {
          reject(new Error(`后端响应解析失败：${raw}`));
        }
      }
    );
  });
}

function buildMultipartBody(
  boundary: string,
  fields: MultipartField[],
  filePath: string,
  fileName: string
): ArrayBuffer {
  let prefix = '';
  fields.forEach((field: MultipartField) => {
    prefix += `--${boundary}\r\n`;
    prefix += `Content-Disposition: form-data; name="${field.name}"\r\n\r\n`;
    prefix += `${field.value}\r\n`;
  });
  prefix += `--${boundary}\r\n`;
  prefix += `Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n`;
  prefix += `Content-Type: ${mimeTypeOf(fileName)}\r\n\r\n`;

  const suffix = `\r\n--${boundary}--\r\n`;
  const prefixBytes = encodeUtf8(prefix);
  const fileBytes = readFileBytes(filePath);
  const suffixBytes = encodeUtf8(suffix);
  return concatBytes([prefixBytes, fileBytes, suffixBytes]);
}

function readFileBytes(filePath: string): Uint8Array {
  const stat = fileIo.statSync(filePath);
  const buffer = new ArrayBuffer(stat.size);
  const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
  try {
    fileIo.readSync(file.fd, buffer);
  } finally {
    fileIo.closeSync(file);
  }
  return new Uint8Array(buffer);
}

function encodeUtf8(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value);
}

function concatBytes(parts: Uint8Array[]): ArrayBuffer {
  let total = 0;
  parts.forEach((part: Uint8Array) => {
    total += part.length;
  });

  const result = new Uint8Array(total);
  let offset = 0;
  parts.forEach((part: Uint8Array) => {
    result.set(part, offset);
    offset += part.length;
  });
  return result.buffer;
}

function mimeTypeOf(fileName: string): string {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lower.endsWith('.txt')) {
    return 'text/plain';
  }
  return 'application/octet-stream';
}

export interface CommonResult<T> {
  success: boolean;
  message: string;
  data?: T;
}

export interface QuestionBankSummary {
  id: number;
  name: string;
  description: string;
  subjectName: string;
  visibility: string;
  sourceType: string;
  totalCount: number;
  practicedCount: number;
  wrongCount: number;
  canManage: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface QuestionBankListData {
  banks: QuestionBankSummary[];
}

export interface QuestionBankResponse {
  bank: QuestionBankSummary;
}

export interface EmptyResponseData {
}

export interface QuestionBankStats {
  totalQuestions: number;
  practicedQuestions: number;
  unpracticedQuestions: number;
  wrongQuestions: number;
  needsReviewQuestions: number;
  answerCount: number;
  correctAnswerCount: number;
  accuracyRate: number;
}

export interface ChartItem {
  label: string;
  value: number;
  ratio: number;
}

export interface RecentQuestion {
  id: number;
  type: string;
  typeLabel: string;
  stem: string;
  difficulty: number;
  knowledgePoint: string;
  tags: string[];
}

export interface QuestionBankDetail {
  bank: QuestionBankSummary;
  stats: QuestionBankStats;
  typeDistribution: ChartItem[];
  difficultyDistribution: ChartItem[];
  tagDistribution: ChartItem[];
  recentQuestions: RecentQuestion[];
}

interface CreateQuestionBankRequest {
  name: string;
  description: string;
}

interface UpdateQuestionBankRequest {
  name: string;
}

interface RequestHeader {
  'Content-Type': string;
  Authorization: string;
}

function requestJson<T>(
  method: http.RequestMethod,
  path: string,
  token: string,
  bodyText: string = ''
): Promise<CommonResult<T>> {
  return new Promise((resolve: (value: CommonResult<T>) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();

    const header: RequestHeader = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`
    };

    request.request(
      `${API_BASE_URL}${path}`,
      {
        method: method,
        header: header,
        extraData: bodyText.length > 0 ? bodyText : undefined,
        connectTimeout: 8000,
        readTimeout: 8000
      },
      (error, response) => {
        request.destroy();

        if (error) {
          reject(new Error(error.message));
          return;
        }

        try {
          const raw = response.result as string;
          const result = JSON.parse(raw) as CommonResult<T>;
          resolve(result);
        } catch (parseError) {
          reject(new Error('后端响应解析失败'));
        }
      }
    );
  });
}

export function getQuestionBanks(token: string): Promise<CommonResult<QuestionBankListData>> {
  return requestJson<QuestionBankListData>(
    http.RequestMethod.GET,
    '/question-banks',
    token
  );
}

export function createQuestionBank(
  token: string,
  name: string,
  description: string
): Promise<CommonResult<QuestionBankResponse>> {
  const body: CreateQuestionBankRequest = {
    name: name,
    description: description
  };

  return requestJson<QuestionBankResponse>(
    http.RequestMethod.POST,
    '/question-banks',
    token,
    JSON.stringify(body)
  );
}

export function updateQuestionBank(
  token: string,
  bankId: number,
  name: string
): Promise<CommonResult<QuestionBankResponse>> {
  const body: UpdateQuestionBankRequest = {
    name: name
  };

  return requestJson<QuestionBankResponse>(
    http.RequestMethod.PUT,
    `/question-banks/${bankId}`,
    token,
    JSON.stringify(body)
  );
}

export function deleteQuestionBank(
  token: string,
  bankId: number
): Promise<CommonResult<EmptyResponseData>> {
  return requestJson<EmptyResponseData>(
    http.RequestMethod.DELETE,
    `/question-banks/${bankId}`,
    token
  );
}

export function getQuestionBankDetail(
  token: string,
  bankId: number
): Promise<CommonResult<QuestionBankDetail>> {
  return requestJson<QuestionBankDetail>(
    http.RequestMethod.GET,
    `/question-banks/${bankId}`,
    token
  );
}

export interface QuestionOptionItem {
  optionKey: string;
  content: string;
  isCorrect: number;
}

export interface QuestionListItem {
  id: number;
  seq: number;
  type: string;
  typeLabel: string;
  stem: string;
  analysis: string;
  difficulty: number;
  score: number;
  knowledgePoint: string;
  practiceStatus: string;
  latestIsCorrect: number;
  answerText: string;
  options: QuestionOptionItem[];
  tags: string[];
}

export interface QuestionFilterOptions {
  types: QuestionTypeOption[];
  difficulties: number[];
  knowledgePoints: string[];
}

export interface QuestionTypeOption {
  value: string;
  label: string;
}

export interface PaginationInfo {
  page: number;
  pageSize: number;
  total: number;
  pageCount: number;
}

export interface QuestionListData {
  bank: QuestionBankSummary;
  questions: QuestionListItem[];
  filters: QuestionFilterOptions;
  pagination: PaginationInfo;
}

export interface QuestionListQuery {
  bankId: number;
  page: number;
  pageSize: number;
  keyword: string;
  type: string;
  difficulty: number;
  knowledgePoint: string;
  practiceStatus: string;
  wrongOnly: boolean;
}

function appendQuery(path: string, key: string, value: string): string {
  if (value.length === 0) {
    return path;
  }

  const separator = path.includes('?') ? '&' : '?';
  return `${path}${separator}${key}=${encodeURIComponent(value)}`;
}

export function getQuestionList(
  token: string,
  query: QuestionListQuery
): Promise<CommonResult<QuestionListData>> {
  let path = `/question-banks/${query.bankId}/questions`;

  path = appendQuery(path, 'page', query.page.toString());
  path = appendQuery(path, 'pageSize', query.pageSize.toString());
  path = appendQuery(path, 'keyword', query.keyword);
  path = appendQuery(path, 'type', query.type);

  if (query.difficulty > 0) {
    path = appendQuery(path, 'difficulty', query.difficulty.toString());
  }

  path = appendQuery(path, 'knowledgePoint', query.knowledgePoint);
  path = appendQuery(path, 'practiceStatus', query.practiceStatus);
  path = appendQuery(path, 'wrongOnly', query.wrongOnly ? '1' : '0');

  return requestJson<QuestionListData>(
    http.RequestMethod.GET,
    path,
    token
  );
}

export interface QuestionImportResult {
  importId: number;
  totalRows: number;
  successRows: number;
  failedRows: number;
  errorMessage: string;
}

interface UploadExcelHeader {
  'Content-Type': string;
  Authorization: string;
}

export function importQuestionsFromExcel(
  token: string,
  bankId: number,
  filePath: string,
  fileName: string
): Promise<CommonResult<QuestionImportResult>> {
  return new Promise((resolve: (value: CommonResult<QuestionImportResult>) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();

    const header: UploadExcelHeader = {
      'Content-Type': 'multipart/form-data',
      Authorization: `Bearer ${token}`
    };

    const filePart: http.MultiFormData = {
      name: 'file',
      contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      filePath: filePath,
      remoteFileName: fileName
    };

    request.request(
      `${API_BASE_URL}/question-banks/${bankId}/import-excel`,
      {
        method: http.RequestMethod.POST,
        header: header,
        multiFormDataList: [filePart],
        connectTimeout: 15000,
        readTimeout: 60000
      },
      (error, response) => {
        request.destroy();

        if (error) {
          reject(new Error(error.message));
          return;
        }

        try {
          const raw = response.result as string;
          const result = JSON.parse(raw) as CommonResult<QuestionImportResult>;
          resolve(result);
        } catch (parseError) {
          reject(new Error('后端响应解析失败'));
        }
      }
    );
  });
}
