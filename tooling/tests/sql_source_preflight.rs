//! Source-only preflight for our untagged PL/pgSQL fixtures.
//! Actual PostgreSQL execution remains mandatory.
use std::{fs, path::{Path, PathBuf}};

fn check_source(path: &Path, content: &str) -> Result<(), String> {
    let source = content.lines().map(|line| line.split("--").next().unwrap_or(""))
        .collect::<Vec<_>>().join("\n");
    let upper = source.to_ascii_uppercase();
    let tokens: Vec<&str> = upper.split_whitespace().collect();
    let opened = tokens.windows(2).filter(|pair|
        matches!(pair[0], "DO" | "AS") && pair[1] == "$$").count();
    let closed = upper.match_indices("$$").filter(|(pos, _)|
        upper[*pos + 2..].trim_start().starts_with(';')).count();
    let single = tokens.windows(2).any(|pair|
        matches!(pair[0], "DO" | "AS") && matches!(pair[1], "$" | "$;"))
        || source.lines().any(|line| line.trim() == "$;")
        || upper.contains("END $;");
    if single || opened != closed || opened + closed != upper.matches("$$").count() {
        return Err(format!("{}: malformed or unmatched dollar delimiters ({opened} open, {closed} closed)", path.display()));
    }
    if path.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with("postgres") && n.ends_with(".sql"))
        && (!upper.lines().any(|line| line.trim() == "BEGIN;")
            || !upper.lines().any(|line| line.trim() == "ROLLBACK;")) {
        return Err(format!("{}: fixture must BEGIN and ROLLBACK", path.display()));
    }
    Ok(())
}

#[test]
fn source_preflight_regressions() {
    let migration = Path::new("0006_scope.sql");
    assert!(check_source(migration, "CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $$\nBEGIN RETURN 1; END;\n$$;\nDO $$ BEGIN NULL; END $$;").is_ok());
    for invalid in ["DO $\nBEGIN NULL; END;\n$;", "DO $$\nBEGIN NULL;\nEND $;", "DO $$ BEGIN NULL; END;", "$$;"] {
        assert!(check_source(migration, invalid).is_err(), "{invalid}");
    }
    assert!(check_source(Path::new("postgres.sql"), "SELECT 1;").is_err());
    assert!(check_source(Path::new("postgres.sql"), "BEGIN;\nDO $$ BEGIN NULL; END $$;\nROLLBACK;").is_ok());
}

fn files(dir: &Path, predicate: impl Fn(&str) -> bool) -> Vec<PathBuf> {
    let mut out: Vec<_> = fs::read_dir(dir).unwrap().map(|e| e.unwrap().path())
        .filter(|p| p.is_file() && p.file_name().and_then(|n| n.to_str()).is_some_and(&predicate)).collect();
    out.sort();
    out
}

#[test]
fn shipped_sql_source_inventory() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let migrations = files(&root.join("migrations"), |n| n.ends_with(".sql") &&
        n.as_bytes().get(..5).is_some_and(|prefix| prefix[..4].iter().all(u8::is_ascii_digit) && prefix[4] == b'_'));
    let fixtures = files(&root.join("tests"), |n| n.starts_with("postgres") && n.ends_with(".sql"));
    assert!(migrations.len() >= 6 && fixtures.len() >= 4, "missing SQL fixture inventory");
    for path in migrations.iter().chain(fixtures.iter()) {
        let source = fs::read_to_string(path).unwrap();
        check_source(path, &source).unwrap();
    }
}
