import re

_HEADING_RE = re.compile(r"^#{1,6}\s*", re.MULTILINE)
_BOLD_ASTERISK_RE = re.compile(r"\*\*(.+?)\*\*")
_BOLD_UNDERSCORE_RE = re.compile(r"__(.+?)__")
_ITALIC_ASTERISK_RE = re.compile(r"\*(.+?)\*")
_ITALIC_UNDERSCORE_RE = re.compile(r"_(.+?)_")
_INLINE_CODE_RE = re.compile(r"`(.+?)`")


def strip_markdown(text: str) -> str:
    """Claude가 이따금 붙이는 마크다운 문법(#, **, __, ` 등)을 제거해서 순수
    텍스트로 만든다. 앱의 Text 위젯은 마크다운을 렌더링하지 않아서, 그대로
    보내면 기호가 그대로 화면에 노출된다. 굵게/기울임 표시는 그 안의 텍스트만
    남기고, 제목(#) 기호는 그냥 지운다.
    """
    text = _HEADING_RE.sub("", text)
    text = _BOLD_ASTERISK_RE.sub(r"\1", text)
    text = _BOLD_UNDERSCORE_RE.sub(r"\1", text)
    text = _ITALIC_ASTERISK_RE.sub(r"\1", text)
    text = _ITALIC_UNDERSCORE_RE.sub(r"\1", text)
    text = _INLINE_CODE_RE.sub(r"\1", text)
    return text.strip()


__all__ = ["strip_markdown"]
