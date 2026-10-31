"""Dependency-free regressions for the source-level SQL preflight."""
import importlib.util
import pathlib
import unittest

P = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "check_sql_source.py"
spec = importlib.util.spec_from_file_location("sqlcheck", P)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SqlPreflightTests(unittest.TestCase):
    def check(self, text, filename="0006_scope.sql"):
        return module.check_source(pathlib.Path(filename), text)

    def test_valid_blocks(self):
        self.assertEqual([], self.check(
            "CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $$\n"
            "BEGIN RETURN 1; END;\n$$;\nDO $$ BEGIN NULL; END $$;"
        ))

    def test_malformed_open(self):
        self.assertTrue(self.check("DO $\nBEGIN NULL; END;\n$;"))

    def test_malformed_end(self):
        self.assertTrue(self.check("DO $$\nBEGIN NULL;\nEND $;"))

    def test_missing_close(self):
        self.assertTrue(self.check("DO $$ BEGIN NULL; END;"))

    def test_orphan_close(self):
        self.assertTrue(self.check("$$;"))

    def test_fixture_transaction(self):
        self.assertTrue(self.check("SELECT 1;", "postgres.sql"))
        self.assertEqual([], self.check(
            "BEGIN;\nDO $$ BEGIN NULL; END $$;\nROLLBACK;", "postgres.sql"
        ))


if __name__ == "__main__":
    unittest.main()
