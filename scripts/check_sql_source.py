#!/usr/bin/env python3
"""Static, dependency-free rejection of common PL/pgSQL fixture mistakes.

Not a PostgreSQL parser or a substitute for executing the migration suite.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

OPEN = re.compile(r"\b(?:DO|AS)\s+\$\$(?!\w)", re.IGNORECASE)
CLOSE = re.compile(r"\$\$\s*;")
BAD_SINGLE = re.compile(r"(?m)^\s*(?:DO|AS)\s+\$\s*$|^\s*\$\s*;\s*$|\bEND\s+\$\s*;")


def check_source(path: Path, content: str) -> list[str]:
    """Return descriptive source-level errors, never an executable verdict."""
    # Strip ordinary line comments; our shipped SQL has only anonymous $$
    # PL/pgSQL blocks (no tagged dollar quotes or dynamic SQL injection).
    lines = [line.split("--", 1)[0] for line in content.splitlines()]
    source = "\n".join(lines)
    errors: list[str] = []
    if BAD_SINGLE.search(source):
        errors.append(f"{path}: malformed single-dollar block delimiter")
    opened = len(OPEN.findall(source))
    closed = len(CLOSE.findall(source))
    if opened != closed:
        errors.append(f"{path}: PL/pgSQL dollar delimiters mismatched: {opened} open, {closed} close")
    if opened != source.count("$$") - closed:
        errors.append(f"{path}: unexpected anonymous $$ token; review SQL quoting")
    if path.name.startswith("postgres") and path.suffix == ".sql":
        if not re.search(r"(?m)^BEGIN;\s*$", source) or not re.search(r"(?m)^ROLLBACK;\s*$", source):
            errors.append(f"{path}: adversarial SQL fixture must BEGIN and ROLLBACK")
    return errors


def main(root: Path) -> int:
    migration_files = sorted((root / "migrations").glob("[0-9][0-9][0-9][0-9]_*.sql"))
    test_files = sorted((root / "tests").glob("postgres*.sql"))
    if len(migration_files) < 6 or len(test_files) < 4:
        print("Missing expected migration or PostgreSQL fixture inventory", file=sys.stderr)
        return 1
    problems = [problem for path in migration_files + test_files
                for problem in check_source(path, path.read_text(encoding="utf-8"))]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print(f"SQL source preflight passed: {len(migration_files)} migrations, {len(test_files)} fixtures (not execution)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(Path(__file__).resolve().parent.parent))
