import unittest

from app.services.markdown_utils import strip_markdown


class StripMarkdownTest(unittest.TestCase):
    def test_removes_heading_markers(self):
        self.assertEqual(strip_markdown("### 청년 정책 안내"), "청년 정책 안내")
        self.assertEqual(strip_markdown("# 제목\n본문"), "제목\n본문")

    def test_removes_bold_and_italic_markers(self):
        self.assertEqual(strip_markdown("이건 **중요**해요"), "이건 중요해요")
        self.assertEqual(strip_markdown("이건 __중요__해요"), "이건 중요해요")
        self.assertEqual(strip_markdown("이건 *강조*예요"), "이건 강조예요")

    def test_removes_inline_code_markers(self):
        self.assertEqual(strip_markdown("`plcyNm` 필드를 써"), "plcyNm 필드를 써")

    def test_leaves_plain_text_unchanged(self):
        self.assertEqual(strip_markdown("일반 텍스트입니다."), "일반 텍스트입니다.")

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(strip_markdown("  안녕하세요  \n"), "안녕하세요")


if __name__ == "__main__":
    unittest.main()
