#!/usr/bin/env python3
"""
Claude Code Review Script for GitLab CI/CD
Analyzes code changes and generates review suggestions using Claude API
"""

import argparse
import hashlib
import json
import logging
import os
import re
import subprocess
import sys
from typing import List, Dict, Any
from dataclasses import dataclass, asdict
from anthropic import Anthropic

# Konfiguracja logowania
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class ReviewComment:
    """Struktura komentarza review"""
    file_path: str
    line_number: int
    severity: str  # 'critical', 'major', 'minor', 'info'
    category: str  # 'bug', 'security', 'performance', 'style', 'best_practice'
    message: str
    suggestion: str = ""


class CodeReviewer:
    """Główna klasa do przeprowadzania review kodu z Claude"""

    def __init__(self, api_key: str = None):
        """Inicjalizacja z kluczem API"""
        self.api_key = api_key or os.environ.get('ANTHROPIC_API_KEY')
        if not self.api_key:
            raise ValueError("Brak klucza API. Ustaw ANTHROPIC_API_KEY w zmiennych środowiskowych")

        self.client = Anthropic(api_key=self.api_key)
        self.comments: List[ReviewComment] = []

    def get_diff(self, base_sha: str) -> Dict[str, str]:
        """Pobiera diff między base SHA a HEAD"""
        diff_range = f"{base_sha}..HEAD"

        try:
            # Pobierz listę zmienionych plików
            result = subprocess.run(
                ["git", "diff", diff_range, "--name-only"],
                check=True,
                stdout=subprocess.PIPE,
                text=True
            )
            changed_files = result.stdout.strip().splitlines()

            diffs = {}
            for file_path in changed_files:
                if not file_path:
                    continue

                # Pomijaj pliki binarne i niektóre rozszerzenia
                if self._should_skip_file(file_path):
                    logger.info(f"Pomijam plik: {file_path}")
                    continue

                # Pobierz diff dla konkretnego pliku
                file_diff = subprocess.run(
                    ["git", "diff", diff_range, "--", file_path],
                    check=True,
                    stdout=subprocess.PIPE,
                    text=True
                )
                diff_content = file_diff.stdout

                if diff_content:
                    diffs[file_path] = diff_content

            return diffs

        except subprocess.CalledProcessError as e:
            logger.error(f"Błąd podczas pobierania diff: {e}")
            return {}

    def _should_skip_file(self, file_path: str) -> bool:
        """Sprawdza czy plik powinien być pominięty w review"""
        skip_extensions = {'.min.js', '.min.css', '.lock', '.sum', '.svg', '.png', '.jpg', '.gif'}
        skip_dirs = {'node_modules/', 'vendor/', 'dist/', 'build/'}

        # Sprawdź rozszerzenia
        for ext in skip_extensions:
            if file_path.endswith(ext):
                return True

        # Sprawdź katalogi
        for dir_name in skip_dirs:
            if dir_name in file_path:
                return True

        return False

    def analyze_with_claude(self, file_path: str, diff: str) -> List[ReviewComment]:
        """Analizuje pojedynczy plik używając Claude API"""

        # Przygotuj prompt dla Claude
        prompt = self._prepare_prompt(file_path, diff)

        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=4000,
                temperature=0.3,
                system="""Jesteś ekspertem code review. Analizuj kod pod kątem:
                - Potencjalnych błędów i bugów
                - Problemów bezpieczeństwa
                - Wydajności
                - Czytelności i maintainability
                - Zgodności z best practices
                
                Zwracaj odpowiedź TYLKO w formacie JSON. Każdy komentarz powinien mieć:
                - line_number: numer linii (z diffa)
                - severity: 'critical'|'major'|'minor'|'info'
                - category: 'bug'|'security'|'performance'|'style'|'best_practice'
                - message: opis problemu
                - suggestion: sugestia poprawy (opcjonalne)
                
                Zwróć tablicę JSON z komentarzami lub pustą tablicę jeśli kod jest OK.""",
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            )

            # Parsuj odpowiedź
            return self._parse_claude_response(response.content[0].text, file_path)

        except Exception as e:
            logger.error(f"Błąd podczas analizy {file_path} z Claude: {e}")
            return []

    def _prepare_prompt(self, file_path: str, diff: str) -> str:
        """Przygotowuje prompt dla Claude"""
        file_extension = os.path.splitext(file_path)[1]

        return f"""Przeanalizuj następujący diff kodu z pliku {file_path} (typ: {file_extension}).
        
Diff git:
```diff
{diff}
```

Zidentyfikuj problemy i zasugeruj ulepszenia. Skup się na:
1. Nowych liniach kodu (zaczynających się od '+')
2. Kontekście zmian
3. Potencjalnych problemach wprowadzonych przez zmiany

Zwróć wynik w formacie JSON jako tablicę obiektów z polami: line_number, severity, category, message, suggestion."""

    def _parse_claude_response(self, response_text: str, file_path: str) -> List[ReviewComment]:
        """Parsuje odpowiedź Claude do obiektów ReviewComment"""
        comments = []

        try:
            # Wyciągnij JSON z odpowiedzi (Claude może dodać dodatkowy tekst)
            json_match = re.search(r'\[.*\]', response_text, re.DOTALL)
            if not json_match:
                logger.warning(f"Brak JSON w odpowiedzi dla {file_path}")
                return []

            json_data = json.loads(json_match.group())

            for item in json_data:
                comment = ReviewComment(
                    file_path=file_path,
                    line_number=item.get('line_number', 0),
                    severity=item.get('severity', 'info'),
                    category=item.get('category', 'best_practice'),
                    message=item.get('message', ''),
                    suggestion=item.get('suggestion', '')
                )
                comments.append(comment)

        except json.JSONDecodeError as e:
            logger.error(f"Błąd parsowania JSON dla {file_path}: {e}")
            logger.debug(f"Odpowiedź: {response_text}")
        except Exception as e:
            logger.error(f"Nieoczekiwany błąd podczas parsowania: {e}")

        return comments

    def review_all_changes(self, base_sha: str) -> None:
        """Przeprowadza review wszystkich zmian"""
        logger.info(f"Rozpoczynam review zmian od {base_sha}")

        diffs = self.get_diff(base_sha)

        if not diffs:
            logger.info("Brak zmian do review")
            return

        logger.info(f"Znaleziono {len(diffs)} plików do analizy")

        for file_path, diff in diffs.items():
            logger.info(f"Analizuję: {file_path}")
            file_comments = self.analyze_with_claude(file_path, diff)
            self.comments.extend(file_comments)
            logger.info(f"Znaleziono {len(file_comments)} komentarzy dla {file_path}")

    def save_results(self, output_file: str = "review-results.json") -> None:
        """Zapisuje wyniki review do pliku"""
        results = {
            "total_comments": len(self.comments),
            "summary": self._generate_summary(),
            "comments": [asdict(comment) for comment in self.comments]
        }

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)

        logger.info(f"Zapisano {len(self.comments)} komentarzy do {output_file}")

        # Zapisz też w formacie GitLab Code Quality
        self._save_gitlab_format()

    def _generate_summary(self) -> Dict[str, Any]:
        """Generuje podsumowanie review"""
        if not self.comments:
            return {"status": "approved", "critical_issues": 0}

        severity_counts = {}
        category_counts = {}

        for comment in self.comments:
            severity_counts[comment.severity] = severity_counts.get(comment.severity, 0) + 1
            category_counts[comment.category] = category_counts.get(comment.category, 0) + 1

        # Określ status na podstawie severity
        status = "approved"
        if severity_counts.get('critical', 0) > 0:
            status = "needs_work"
        elif severity_counts.get('major', 0) > 2:
            status = "needs_review"

        return {
            "status": status,
            "severity_counts": severity_counts,
            "category_counts": category_counts,
            "files_reviewed": len(set(c.file_path for c in self.comments))
        }

    def _save_gitlab_format(self) -> None:
        """Zapisuje wyniki w formacie GitLab Code Quality"""
        gitlab_issues = []

        for comment in self.comments:
            issue = {
                "description": comment.message,
                "check_name": f"claude-review/{comment.category}",
                "fingerprint": hashlib.sha256(
                    f"{comment.file_path}:{comment.line_number}:{comment.message}".encode("utf-8")
                ).hexdigest(),
                "severity": self._map_severity_to_gitlab(comment.severity),
                "location": {
                    "path": comment.file_path,
                    "lines": {
                        "begin": comment.line_number
                    }
                }
            }

            if comment.suggestion:
                issue["remediation_points"] = 100000  # GitLab format
                issue["content"] = {"body": comment.suggestion}

            gitlab_issues.append(issue)

        with open("review-report.json", 'w') as f:
            json.dump(gitlab_issues, f, indent=2)

    def _map_severity_to_gitlab(self, severity: str) -> str:
        """Mapuje severity na format GitLab"""
        mapping = {
            'critical': 'blocker',
            'major': 'major',
            'minor': 'minor',
            'info': 'info'
        }
        return mapping.get(severity, 'info')


def main():
    """Główna funkcja skryptu"""
    parser = argparse.ArgumentParser(description='Claude Code Review for GitLab CI/CD')
    parser.add_argument('--diff', required=True, help='Base SHA for diff comparison')
    parser.add_argument('--output', default='review-results.json', help='Output file path')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    parser.add_argument(
        '--fail-on-needs-work',
        action='store_true',
        help='Zwróć kod wyjścia 1, jeśli status review to needs_work'
    )

    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        reviewer = CodeReviewer()
        reviewer.review_all_changes(args.diff)
        reviewer.save_results(args.output)

        # Zwróć kod wyjścia na podstawie wyników
        summary = reviewer._generate_summary()
        if summary.get('status') == 'needs_work':
            logger.warning("Review znalazł krytyczne problemy")
            if args.fail_on_needs_work:
                sys.exit(1)

        logger.info("Review zakończony pomyślnie")

    except Exception as e:
        logger.error(f"Błąd krytyczny: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
