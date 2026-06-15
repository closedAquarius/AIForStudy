import os
import time
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parents[1]

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(BACKEND_DIR / ".env.example", override=False)


class AiProviderError(RuntimeError):
    status_code = 503


class AiProviderBusyError(AiProviderError):
    status_code = 429


class AiProviderTimeoutError(AiProviderError):
    status_code = 504


class AiProviderAuthError(AiProviderError):
    status_code = 502


class AiProviderRequestError(AiProviderError):
    status_code = 400


class ZhipuChatClient:
    """Shared Zhipu chat client with bounded retry and stable errors."""

    def __init__(self, api_key: str | None = None, model: str | None = None):
        self.api_key = api_key or os.getenv("ZHIPU_API_KEY", "")
        self.model = model or os.getenv("ZHIPU_MODEL", "glm-4.7-flash")
        self.max_retries = max(0, min(int(os.getenv("ZHIPU_MAX_RETRIES", "2")), 3))

    def complete(
        self,
        messages: list[dict[str, str]],
        max_tokens: int = 8192,
        temperature: float = 0.6,
        thinking: bool = False,
    ) -> str:
        if not self.api_key:
            raise AiProviderAuthError("AI服务尚未配置API Key，请联系管理员。")
        try:
            from zai import ZhipuAiClient
        except ImportError as exc:
            raise AiProviderError("AI服务依赖未安装，请先安装 zai。") from exc

        client = ZhipuAiClient(api_key=self.api_key)
        for attempt in range(self.max_retries + 1):
            try:
                options: dict[str, Any] = {
                    "model": self.model,
                    "messages": messages,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                }
                if thinking:
                    options["thinking"] = {"type": "enabled"}
                response = client.chat.completions.create(**options)
                message = response.choices[0].message
                content = getattr(message, "content", None)
                if content is None and isinstance(message, dict):
                    content = message.get("content")
                text = content if isinstance(content, str) else str(message)
                if not text.strip():
                    raise AiProviderError("AI返回了空内容，请重新尝试。")
                return text.strip()
            except AiProviderError:
                raise
            except Exception as exc:
                mapped = self._map_error(exc)
                if attempt >= self.max_retries or not self._retryable(mapped):
                    raise mapped from exc
                time.sleep(1.2 * (attempt + 1))
        raise AiProviderError("AI服务暂时不可用，请稍后再试。")

    def _map_error(self, exc: Exception) -> AiProviderError:
        name = exc.__class__.__name__.lower()
        text = str(exc).lower()
        if (
            "apireachlimit" in name
            or "ratelimit" in name
            or "429" in text
            or "1305" in text
            or "访问量过大" in text
        ):
            return AiProviderBusyError("AI当前访问量较大，已自动重试，请稍后再试。")
        if "timeout" in name or "timeout" in text or "timed out" in text:
            return AiProviderTimeoutError("AI响应超时，请稍后重试。")
        if "401" in text or "unauthorized" in text or "api key" in text:
            return AiProviderAuthError("AI服务鉴权失败，请检查API Key配置。")
        if "400" in text or "parameter" in text or "参数" in text:
            return AiProviderRequestError("AI请求参数不符合模型要求，请调整内容后重试。")
        if (
            "connection" in name
            or "connection" in text
            or "network" in text
            or "502" in text
            or "503" in text
            or "504" in text
        ):
            return AiProviderError("AI服务连接不稳定，已自动重试，请稍后再试。")
        return AiProviderError(f"AI服务调用失败：{exc}")

    def _retryable(self, error: AiProviderError) -> bool:
        return isinstance(error, (AiProviderBusyError, AiProviderTimeoutError)) or (
            type(error) is AiProviderError
        )
