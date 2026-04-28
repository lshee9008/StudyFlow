import os
from langchain_community.tools.tavily_search import TavilySearchResults

# ⚠️ 실제 사용 시 .env 파일이나 환경 변수로 관리하세요.
os.environ["TAVILY_API_KEY"] = "tvly-YOUR_API_KEY_HERE"

def get_web_search_tool():
    # k=3: 검색 결과 상위 3개만 가져옴
    return TavilySearchResults(k=3)
