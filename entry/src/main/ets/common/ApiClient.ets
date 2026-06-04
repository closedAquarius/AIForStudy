import http from '@ohos.net.http';

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

interface LoginRequest {
  username: string;
  password: string;
}

interface RegisterRequest {
  username: string;
  password: string;
  nickname: string;
}

const API_BASE_URL: string = 'http://127.0.0.1:5000/api';

function postJson(path: string, body: LoginRequest | RegisterRequest): Promise<ApiResult> {
  return new Promise((resolve: (value: ApiResult) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();
    request.request(
      `${API_BASE_URL}${path}`,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
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
          resolve(JSON.parse(raw) as ApiResult);
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
  return postJson('/auth/login', body);
}

export function register(username: string, password: string, nickname: string): Promise<ApiResult> {
  const body: RegisterRequest = {
    username: username,
    password: password,
    nickname: nickname
  };
  return postJson('/auth/register', body);
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
