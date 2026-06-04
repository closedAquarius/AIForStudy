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

const API_BASE_URL: string = 'http://192.168.253.1:5000/api';

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
