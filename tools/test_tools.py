"""도구와 버전 관리 자동 테스트.

실행: python3 -m unittest discover -s tools -p "test_*.py" -v
"""
import io
import re
import unittest
from pathlib import Path

import changelog
import versions_page

ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def version_key(v):
    return tuple(int(x) for x in v.split("."))


class ChangelogParseTest(unittest.TestCase):
    SAMPLE = "\n".join([
        "# 기록", "", "머리말", "",
        "## [2.0.0] - 2026-01-02", "", "### 추가", "- 새 것", "",
        "## [1.0.0] - 2026-01-01", "- 첫 것", "",
        "## 링크", "- 버전이 아닌 부분",
    ])

    def test_버전별_릴리스_설명을_정확히_잘라냄(self):
        self.assertEqual(changelog.release_notes(self.SAMPLE, "2.0.0"), "### 추가\n- 새 것")
        # 앞의 v는 무시하고, 버전이 아닌 제목 아래 내용은 넣지 않는다.
        self.assertEqual(changelog.release_notes(self.SAMPLE, "v1.0.0"), "- 첫 것")
        self.assertIsNone(changelog.release_notes(self.SAMPLE, "3.0.0"))
        self.assertEqual([e["date"] for e in changelog.parse_changelog(self.SAMPLE)], ["2026-01-02", "2026-01-01"])

    def test_Windows_줄바꿈도_처리(self):
        self.assertEqual(changelog.release_notes("## [1.0.0] - 2026-01-01\r\n- 첫 것\r\n", "1.0.0"), "- 첫 것")

    def test_project_godot에서_버전을_읽음(self):
        self.assertEqual(changelog.godot_version('[application]\nconfig/name="x"\nconfig/version="1.2.3"\n'), "1.2.3")
        self.assertIsNone(changelog.godot_version("[application]\n"))

    def test_버전이_같으면_문제_없음(self):
        text = "## [1.3.0] - 2026-01-03\n- 새 것\n\n## [1.2.0] - 2026-01-02\n- 예전 것\n"
        self.assertEqual(changelog.version_mismatches(text, "1.3.0"), [])

    def test_버전이_다르면_이유와_함께_알려_줌(self):
        text = "## [1.3.0] - 2026-01-03\n- 새 것\n"
        problems = changelog.version_mismatches(text, "1.2.0")
        self.assertEqual(len(problems), 1)
        self.assertIn("config/version(1.2.0)", problems[0])
        self.assertEqual(len(changelog.version_mismatches("# 기록만 있고 버전 없음", "1.0.0")), 1)
        self.assertEqual(len(changelog.version_mismatches(text, None)), 1)

    def test_명령줄_사용법이_틀리면_실패(self):
        err = io.StringIO()
        self.assertEqual(changelog.main([], out=io.StringIO(), err=err), 2)
        self.assertIn("사용법", err.getvalue())


class RepositoryVersionTest(unittest.TestCase):
    """저장소의 실제 파일이 버전 관리 규칙을 지키는지 확인한다."""

    def test_latest_명령은_현재_버전을_출력하고_성공(self):
        out = io.StringIO()
        self.assertEqual(changelog.main(["latest"], out=out, err=io.StringIO()), 0)
        self.assertEqual(out.getvalue().strip(), changelog.godot_version(read("project.godot")))

    def test_게임_버전과_CHANGELOG_최신_버전이_같음(self):
        version = changelog.godot_version(read("project.godot"))
        self.assertRegex(version or "", SEMVER)
        self.assertEqual(changelog.parse_changelog(read("CHANGELOG.md"))[0]["version"], version)

    def test_변경_기록_항목이_형식에_맞고_최신순이며_내용이_있음(self):
        entries = changelog.parse_changelog(read("CHANGELOG.md"))
        self.assertGreaterEqual(len(entries), 1)
        seen = set()
        for i, e in enumerate(entries):
            self.assertRegex(e["version"], SEMVER)
            self.assertRegex(e["date"] or "", r"^\d{4}-\d{2}-\d{2}$", f"{e['version']} 날짜")
            self.assertGreater(len(e["body"]), 20, f"{e['version']} 내용")
            self.assertNotIn(e["version"], seen, f"{e['version']} 중복")
            seen.add(e["version"])
            if i > 0:
                self.assertGreater(version_key(entries[i - 1]["version"]), version_key(e["version"]), f"{e['version']} 순서")


class VersionsPageTest(unittest.TestCase):
    def test_이전_버전_링크와_최신_버전_링크(self):
        page = versions_page.render("0.0.3", ["0.0.2", "0.0.1"])
        self.assertIn('href="v0.0.2/"', page)
        self.assertIn('href="v0.0.1/"', page)
        self.assertIn('href="../"', page)
        self.assertIn("v0.0.3", page)
        self.assertLess(page.index("v0.0.2/"), page.index("v0.0.1/"), "최신순")

    def test_이전_버전이_없을_때_안내(self):
        page = versions_page.render("0.0.1", [])
        self.assertIn("아직 이전 버전이 없습니다", page)
        self.assertNotIn("<ul>", page)

    def test_버전_문자열은_HTML로_이스케이프(self):
        self.assertNotIn("<b>", versions_page.render("<b>", ["<b>"]))


class WorkflowTest(unittest.TestCase):
    """배포 워크플로가 규칙대로 설정되어 있는지 확인한다."""

    def setUp(self):
        self.yml = read(".github/workflows/deploy.yml")

    def test_main_푸시_때만_태그_릴리스_배포(self):
        self.assertIn("github.ref == 'refs/heads/main'", self.yml)
        self.assertIn("needs: test", self.yml)
        self.assertIn("python3 tools/changelog.py latest", self.yml)
        self.assertIn('git tag -a "$tag"', self.yml)
        self.assertIn('gh release create "$tag"', self.yml)
        self.assertIn("actions/deploy-pages", self.yml)

    def test_경로_필터_없이_모든_푸시에서_테스트(self):
        # 경로 필터가 있으면 CHANGELOG를 안 바꾼 푸시에서 실행되지 않는다.
        self.assertNotIn("paths:", self.yml)
        self.assertIn("bash tests/run_tests.sh", self.yml)
        self.assertIn('python3 -m unittest discover -s tools -p "test_*.py"', self.yml)

    def test_테스트_실행기는_깨져도_실패로_끝남(self):
        # Godot는 -s 스크립트가 파싱에 실패해도 종료 코드 0이라, 래퍼가 "결과:" 줄을 확인해야 한다.
        self.assertIn("결과: 통과", read("tests/run_tests.sh"))
        self.assertIn("exit 1", read("tests/run_tests.sh"))
        # 실행기가 전역 클래스 이름을 쓰면 클래스 캐시 없이 파싱이 깨져 오류를 알릴 수 없다.
        self.assertNotRegex(read("tests/run_tests.gd"), r":\s*TestCase\b")

    def test_워크플로와_프로젝트의_Godot_버전이_맞음(self):
        engine = re.search(r'GODOT_VERSION: "(\d+\.\d+)(?:\.\d+)?"', self.yml)
        self.assertIsNotNone(engine)
        self.assertIn(f'PackedStringArray("{engine.group(1)}"', read("project.godot"))


class CreditsTest(unittest.TestCase):
    def test_에셋_폴더의_라이선스_파일이_CREDITS에_기록됨(self):
        credits = read("CREDITS.md")
        for license_file in (ROOT / "assets").rglob("LICENSE*"):
            folder = license_file.parent.relative_to(ROOT).as_posix()
            self.assertIn(folder, credits, f"{folder} 출처가 CREDITS.md에 없음")


if __name__ == "__main__":
    unittest.main()
