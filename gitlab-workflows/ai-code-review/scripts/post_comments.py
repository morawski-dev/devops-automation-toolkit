#!/usr/bin/env python3
"""
GitLab MR Comment Poster
Posts code review comments from Claude analysis to GitLab Merge Request
"""

import argparse
import json
import logging
import os
import sys
import time
from typing import List, Dict, Any, Optional
import re
import requests
from urllib.parse import quote

# Konfiguracja logowania
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class GitLabCommentPoster:
    """Klasa do publikowania komentarzy w GitLab MR"""

    def __init__(self, project_id: str = None, gitlab_token: str = None, gitlab_url: str = None):
        """
        Inicjalizacja z danymi dostępowymi do GitLab

        Args:
            project_id: ID projektu GitLab (domyślnie z CI_PROJECT_ID)
            gitlab_token: Token dostępowy (domyślnie z GITLAB_TOKEN)
            gitlab_url: URL GitLab API (domyślnie z CI_API_V4_URL)
        """
        self.project_id = project_id or os.environ.get('CI_PROJECT_ID')
        self.gitlab_token = gitlab_token or os.environ.get('GITLAB_TOKEN')
        self.gitlab_url = gitlab_url or os.environ.get('CI_API_V4_URL', 'https://gitlab.com/api/v4')

        if not all([self.project_id, self.gitlab_token]):
            raise ValueError("Brak wymaganych danych: PROJECT_ID i GITLAB_TOKEN")

        self.headers = {
            'PRIVATE-TOKEN': self.gitlab_token,
            'Content-Type': 'application/json'
        }

        # Rate limiting
        self.request_delay = 0.5  # Opóźnienie między requestami (w sekundach)

    def load_review_results(self, file_path: str = "review-results.json") -> Dict[str, Any]:
        """Wczytuje wyniki review z pliku"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"Nie znaleziono pliku z wynikami: {file_path}")
            return {}
        except json.JSONDecodeError as e:
            logger.error(f"Błąd parsowania JSON: {e}")
            return {}

    def post_summary_comment(self, mr_iid: str, summary: Dict[str, Any]) -> bool:
        """
        Publikuje komentarz z podsumowaniem review

        Args:
            mr_iid: Internal ID merge requesta
            summary: Słownik z podsumowaniem
        """
        # Przygotuj treść komentarza
        comment_body = self._format_summary_comment(summary)

        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}/notes"

        payload = {
            "body": comment_body
        }

        try:
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            logger.info(f"Opublikowano podsumowanie review dla MR !{mr_iid}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas publikowania podsumowania: {e}")
            if hasattr(e.response, 'text'):
                logger.debug(f"Odpowiedź serwera: {e.response.text}")
            return False

    def _format_summary_comment(self, summary: Dict[str, Any]) -> str:
        """Formatuje komentarz z podsumowaniem"""

        # Określ emoji na podstawie statusu
        status_emoji = {
            'approved': '✅',
            'needs_review': '⚠️',
            'needs_work': '🔴'
        }

        emoji = status_emoji.get(summary.get('status', 'approved'), '📝')

        # Nagłówek
        comment = f"## {emoji} Automatyczny Code Review (Claude AI)\n\n"

        # Status
        status_text = {
            'approved': 'Kod wygląda dobrze! Nie znaleziono krytycznych problemów.',
            'needs_review': 'Znaleziono problemy wymagające uwagi.',
            'needs_work': 'Znaleziono krytyczne problemy wymagające poprawy.'
        }

        comment += f"**Status:** {status_text.get(summary.get('status', 'approved'), 'Review zakończony')}\n\n"

        # Statystyki severity
        severity_counts = summary.get('severity_counts', {})
        if severity_counts:
            comment += "### 📊 Podsumowanie problemów\n\n"
            comment += "| Priorytet | Liczba |\n"
            comment += "|-----------|--------|\n"

            severity_labels = {
                'critical': '🔴 Krytyczne',
                'major': '🟠 Ważne',
                'minor': '🟡 Drobne',
                'info': 'ℹ️ Informacyjne'
            }

            for severity in ['critical', 'major', 'minor', 'info']:
                if severity in severity_counts:
                    label = severity_labels.get(severity, severity)
                    comment += f"| {label} | {severity_counts[severity]} |\n"

            comment += "\n"

        # Kategorie problemów
        category_counts = summary.get('category_counts', {})
        if category_counts:
            comment += "### 🏷️ Kategorie\n\n"

            category_labels = {
                'bug': '🐛 Błędy',
                'security': '🔒 Bezpieczeństwo',
                'performance': '⚡ Wydajność',
                'style': '🎨 Styl kodu',
                'best_practice': '📚 Best Practices'
            }

            categories_list = []
            for category, count in category_counts.items():
                label = category_labels.get(category, category)
                categories_list.append(f"**{label}:** {count}")

            comment += " • ".join(categories_list) + "\n\n"

        # Liczba przeanalizowanych plików
        files_reviewed = summary.get('files_reviewed', 0)
        if files_reviewed:
            comment += f"📁 **Przeanalizowane pliki:** {files_reviewed}\n\n"

        # Stopka
        comment += "---\n"
        comment += "*🤖 Ten review został wygenerowany automatycznie przez Claude AI. "
        comment += "Szczegółowe komentarze znajdują się przy konkretnych liniach kodu.*\n"

        return comment

    def post_inline_comments(self, mr_iid: str, comments: List[Dict[str, Any]]) -> int:
        """
        Publikuje komentarze inline przy konkretnych liniach kodu

        Args:
            mr_iid: Internal ID merge requesta
            comments: Lista komentarzy do opublikowania

        Returns:
            Liczba pomyślnie opublikowanych komentarzy
        """

        # Najpierw pobierz informacje o MR i zmianach
        mr_info = self._get_merge_request_info(mr_iid)
        if not mr_info:
            logger.error("Nie można pobrać informacji o MR")
            return 0

        # Pobierz diff MR
        diffs = self._get_merge_request_diffs(mr_iid)
        if not diffs:
            logger.warning("Nie znaleziono zmian w MR")
            return 0

        posted_count = 0

        for comment in comments:
            # Znajdź odpowiedni diff dla pliku
            file_diff = self._find_file_diff(diffs, comment['file_path'])
            if not file_diff:
                logger.warning(f"Nie znaleziono diffa dla pliku: {comment['file_path']}")
                continue

            # Publikuj komentarz jako discussion
            if self._post_inline_comment(mr_iid, mr_info, file_diff, comment):
                posted_count += 1
                time.sleep(self.request_delay)  # Rate limiting

        logger.info(f"Opublikowano {posted_count} z {len(comments)} komentarzy inline")
        return posted_count

    def _get_merge_request_info(self, mr_iid: str) -> Optional[Dict[str, Any]]:
        """Pobiera informacje o merge request"""
        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}"

        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas pobierania informacji o MR: {e}")
            return None

    def _get_merge_request_diffs(self, mr_iid: str) -> List[Dict[str, Any]]:
        """Pobiera diffy merge requesta"""
        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}/diffs"

        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            data = response.json()

            if isinstance(data, list):
                return data

            if isinstance(data, dict):
                return data.get('diffs', [])

            logger.error("Niezrozumiała odpowiedź API dla diffów MR")
            return []
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas pobierania diffów: {e}")
            return []

    def _find_file_diff(self, diffs: List[Dict[str, Any]], file_path: str) -> Optional[Dict[str, Any]]:
        """Znajduje diff dla konkretnego pliku"""
        for diff in diffs:
            if diff.get('new_path') == file_path or diff.get('old_path') == file_path:
                return diff
        return None

    def _map_line_to_diff_position(self, file_diff: Dict[str, Any], target_line: int) -> Optional[Dict[str, Any]]:
        """
        Mapuje numer linii do pozycji w diffie GitLab (new/old).

        Zwraca słownik z kluczami:
            - type: 'new' | 'old'
            - line: numer linii dla odpowiedniego typu
        """
        diff_text = file_diff.get('diff')
        if not diff_text or target_line < 1:
            return None

        old_line = 0
        new_line = 0

        # Parsuj diff linia po linii
        for line in diff_text.splitlines():
            if line.startswith('@@'):
                match = re.match(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@', line)
                if not match:
                    continue
                old_line = int(match.group(1))
                new_line = int(match.group(2))
                continue

            if line.startswith('+'):
                if new_line == target_line:
                    return {'type': 'new', 'line': new_line}
                new_line += 1
            elif line.startswith('-'):
                if old_line == target_line:
                    return {'type': 'old', 'line': old_line}
                old_line += 1
            elif line.startswith('\\'):
                # Linia informacyjna "\ No newline at end of file"
                continue
            else:
                # Linie kontekstowe zwiększają oba liczniki
                if new_line == target_line:
                    return {'type': 'new', 'line': new_line}
                old_line += 1
                new_line += 1

        return None

    def _post_inline_comment(self, mr_iid: str, mr_info: Dict[str, Any],
                             file_diff: Dict[str, Any], comment: Dict[str, Any]) -> bool:
        """
        Publikuje pojedynczy komentarz inline

        Args:
            mr_iid: ID merge requesta
            mr_info: Informacje o MR
            file_diff: Diff pliku
            comment: Dane komentarza
        """

        # Przygotuj treść komentarza
        comment_body = self._format_inline_comment(comment)

        # Utwórz discussion dla komentarza inline
        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}/discussions"

        # Znajdź SHA dla nowej wersji pliku
        head_sha = mr_info.get('diff_refs', {}).get('head_sha')
        base_sha = mr_info.get('diff_refs', {}).get('base_sha')
        start_sha = mr_info.get('diff_refs', {}).get('start_sha')

        try:
            target_line = int(comment.get('line_number', 0))
        except (TypeError, ValueError):
            target_line = 0

        if not all([head_sha, base_sha, start_sha]) or target_line < 1:
            logger.debug("Brak wymaganych danych do komentarza inline - publikuję jako zwykły komentarz")
            return self._post_as_regular_comment(mr_iid, comment)

        position_mapping = self._map_line_to_diff_position(file_diff, target_line)
        if not position_mapping:
            logger.debug(
                f"Nie udało się zmapować linii {target_line} na diff - publikuję jako zwykły komentarz"
            )
            return self._post_as_regular_comment(mr_iid, comment)

        new_path = file_diff.get('new_path') or comment['file_path']
        old_path = file_diff.get('old_path') or comment['file_path']

        payload = {
            "body": comment_body,
            "position": {
                "base_sha": base_sha,
                "start_sha": start_sha,
                "head_sha": head_sha,
                "position_type": "text",
                "new_path": new_path
            }
        }

        if position_mapping['type'] == 'old':
            payload["position"]["old_path"] = old_path
            payload["position"]["old_line"] = position_mapping['line']
        else:
            payload["position"]["new_line"] = position_mapping['line']

        try:
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            logger.debug(f"Opublikowano komentarz dla {comment['file_path']}:{comment.get('line_number')}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas publikowania komentarza inline: {e}")
            if hasattr(e.response, 'text'):
                logger.debug(f"Odpowiedź serwera: {e.response.text}")
            # Jeśli nie udało się jako inline, spróbuj jako zwykły komentarz
            return self._post_as_regular_comment(mr_iid, comment)

    def _post_as_regular_comment(self, mr_iid: str, comment: Dict[str, Any]) -> bool:
        """Publikuje jako zwykły komentarz jeśli inline się nie udał"""
        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}/notes"

        # Formatuj z informacją o pliku i linii
        body = f"**📍 {comment['file_path']}:{comment.get('line_number', '?')}**\n\n"
        body += self._format_inline_comment(comment)

        payload = {"body": body}

        try:
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            logger.debug(f"Opublikowano jako zwykły komentarz: {comment['file_path']}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas publikowania zwykłego komentarza: {e}")
            return False

    def _format_inline_comment(self, comment: Dict[str, Any]) -> str:
        """Formatuje komentarz inline"""

        # Ikony dla severity
        severity_icons = {
            'critical': '🔴',
            'major': '🟠',
            'minor': '🟡',
            'info': 'ℹ️'
        }

        # Ikony dla kategorii
        category_icons = {
            'bug': '🐛',
            'security': '🔒',
            'performance': '⚡',
            'style': '🎨',
            'best_practice': '📚'
        }

        severity = comment.get('severity', 'info')
        category = comment.get('category', 'best_practice')

        icon = severity_icons.get(severity, '📝')
        cat_icon = category_icons.get(category, '')

        # Buduj komentarz
        body = f"{icon} **[{severity.upper()}]** {cat_icon} {category.replace('_', ' ').title()}\n\n"
        body += comment.get('message', 'Brak opisu problemu')

        # Dodaj sugestię jeśli istnieje
        if comment.get('suggestion'):
            body += "\n\n💡 **Sugestia:**\n"
            body += f"```suggestion\n{comment['suggestion']}\n```"

        return body

    def update_merge_request_labels(self, mr_iid: str, summary: Dict[str, Any]) -> bool:
        """
        Aktualizuje etykiety MR na podstawie wyników review

        Args:
            mr_iid: ID merge requesta
            summary: Podsumowanie review
        """

        labels = []

        # Dodaj etykietę statusu
        status = summary.get('status', 'approved')
        if status == 'needs_work':
            labels.append('needs-work')
            labels.append('ai-review-failed')
        elif status == 'needs_review':
            labels.append('needs-review')
            labels.append('ai-review-warnings')
        else:
            labels.append('ai-review-passed')

        # Dodaj etykiety dla znalezionych problemów
        category_counts = summary.get('category_counts', {})
        if category_counts.get('security', 0) > 0:
            labels.append('security-issue')

        if category_counts.get('performance', 0) > 0:
            labels.append('performance-issue')

        # Aktualizuj etykiety
        url = f"{self.gitlab_url}/projects/{self.project_id}/merge_requests/{mr_iid}"
        payload = {"add_labels": ','.join(labels)}

        try:
            response = requests.put(url, headers=self.headers, json=payload)
            response.raise_for_status()
            logger.info(f"Zaktualizowano etykiety MR: {labels}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Błąd podczas aktualizacji etykiet: {e}")
            return False


def main():
    """Główna funkcja skryptu"""
    parser = argparse.ArgumentParser(description='Post Claude review comments to GitLab MR')
    parser.add_argument('--mr-iid', required=True, help='Merge Request IID')
    parser.add_argument('--input', default='review-results.json', help='Input file with review results')
    parser.add_argument('--skip-inline', action='store_true', help='Skip inline comments, post only summary')
    parser.add_argument('--skip-labels', action='store_true', help='Skip updating MR labels')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        # Inicjalizuj poster
        poster = GitLabCommentPoster()

        # Wczytaj wyniki review
        results = poster.load_review_results(args.input)
        if not results:
            logger.warning("Brak wyników review do opublikowania")
            sys.exit(0)

        summary = results.get('summary', {})
        comments = results.get('comments', [])

        logger.info(f"Znaleziono {len(comments)} komentarzy do opublikowania")

        # Publikuj podsumowanie
        if not poster.post_summary_comment(args.mr_iid, summary):
            logger.error("Nie udało się opublikować podsumowania")

        # Publikuj komentarze inline (jeśli nie pominięto)
        if not args.skip_inline and comments:
            posted = poster.post_inline_comments(args.mr_iid, comments)
            logger.info(f"Opublikowano {posted} komentarzy inline")

        # Aktualizuj etykiety (jeśli nie pominięto)
        if not args.skip_labels:
            poster.update_merge_request_labels(args.mr_iid, summary)

        logger.info("Publikowanie komentarzy zakończone pomyślnie")

        # Zwróć odpowiedni kod wyjścia
        if summary.get('status') == 'needs_work':
            logger.warning("Review wymaga poprawek - zwracam kod błędu")
            sys.exit(1)  # Opcjonalnie możesz zwrócić 0 aby nie blokować

    except Exception as e:
        logger.error(f"Błąd krytyczny: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
