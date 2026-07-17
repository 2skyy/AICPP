# ===========================
# 초기 세팅

# 가상 환경 설정 및 패키지 설치
# python -m venv venv
# .\venv\Scripts\activate
# pip install -r requirements.txt

# 로컬 테스트용
# uvicorn main:app --reload
# 외부 접속 허용
# uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# 스키마는 alembic를 사용하여 관리
# alembic init alembic

# ===========================

from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.endpoints.chat_endpoint import router as chat_router
from app.api.endpoints.news_endpoint import router as news_router
from app.api.endpoints.ontong_policy_endpoint import router as ontong_policy_router

load_dotenv(Path(__file__).resolve().parent / ".env")

app = FastAPI(
    title = "모아폴리 API",
    description = "모아폴리 API 문서입니다.",
    version = "1.0.0",
)

origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def health_check():
    return {"message": "모아폴리 API 서버 작동 확인"}

# 엔드 포인트 등록

app.include_router(ontong_policy_router)
app.include_router(chat_router)
app.include_router(news_router)
