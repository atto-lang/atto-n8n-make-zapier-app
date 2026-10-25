use sha2::{Digest, Sha256};
use std::{
    collections::BTreeMap,
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .to_path_buf()
}
fn sha(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
fn model_export(root: &Path) -> Result<String> {
    let out = Command::new(root.join("scripts/ores"))
        .arg(root.join("scripts/export-schema.ores"))
        .output()?;
    std::io::stderr().write_all(&out.stderr)?;
    if !out.status.success() {
        return Err("native schema export failed".into());
    }
    Ok(String::from_utf8(out.stdout)?)
}
fn tables(sql: &str) -> Result<BTreeMap<String, String>> {
    let mut result = BTreeMap::new();
    let mut current: Option<(String, String)> = None;
    for line in sql.lines() {
        if let Some(name) = line
            .strip_prefix("CREATE TABLE \"")
            .and_then(|s| s.strip_suffix("\" ("))
        {
            if current.is_some() {
                return Err("nested table export".into());
            }
            current = Some((name.to_owned(), format!("{line}\n")));
        } else if let Some((_, text)) = current.as_mut() {
            text.push_str(line);
            text.push('\n');
        }
        if line == ");" {
            let (name, text) = current.take().ok_or("unexpected table end")?;
            if result.insert(name, text).is_some() {
                return Err("duplicate table export".into());
            }
        }
    }
    if current.is_some() || result.is_empty() {
        return Err("incomplete schema export".into());
    }
    Ok(result)
}
fn plan(previous: &str, current: &str) -> Result<String> {
    let old = tables(previous)?;
    let new = tables(current)?;
    if old.keys().any(|key| !new.contains_key(key)) {
        return Err("table removal needs a reviewed expand/contract migration".into());
    }
    // Preserve source order because foreign keys depend on preceding tables.
    let mut statements = Vec::new();
    for (name, text) in &new {
        match old.get(name) {
            Some(before) if before != text => {
                return Err(format!(
                    "{name} changed: author explicit SQL and review the new snapshot"
                )
                .into());
            }
            None => statements.push((
                current.find(text).ok_or("missing table source")?,
                text.clone(),
            )),
            _ => {}
        }
    }
    statements.sort_by_key(|(position, _)| *position);
    Ok(statements.into_iter().map(|(_, text)| text).collect())
}
fn migration_name(name: &str) -> bool {
    let b = name.as_bytes();
    b.len() > 9
        && b[..4].iter().all(u8::is_ascii_digit)
        && b[4] == b'_'
        && name.ends_with(".sql")
        && b[5..b.len() - 4]
            .iter()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_')
}
fn migrations(root: &Path) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    for entry in fs::read_dir(root.join("migrations"))? {
        let path = entry?.path();
        let name = path
            .file_name()
            .unwrap()
            .to_str()
            .ok_or("non-UTF8 migration name")?;
        if name == "schema.snapshot.sql" {
            continue;
        }
        if !migration_name(name) {
            return Err(format!("invalid migration filename {name}").into());
        }
        files.push(path);
    }
    files.sort();
    if files.is_empty() {
        return Err("no migrations found".into());
    }
    for pair in files.windows(2) {
        if pair[0].file_name().unwrap().to_str().unwrap()[..4]
            == pair[1].file_name().unwrap().to_str().unwrap()[..4]
        {
            return Err("duplicate migration number".into());
        }
    }
    Ok(files)
}
fn apply_script(files: &[PathBuf]) -> Result<String> {
    let mut sql = String::from(
        "BEGIN;\nSET LOCAL lock_timeout = '5s';\nSELECT pg_advisory_xact_lock(730125091);\nCREATE TABLE IF NOT EXISTS _ores_migrations (name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());\n",
    );
    for file in files {
        let name = file
            .file_name()
            .unwrap()
            .to_str()
            .ok_or("migration filename")?;
        if !migration_name(name) {
            return Err("invalid migration name".into());
        }
        let data = fs::read(file)?;
        let digest = sha(&data);
        sql.push_str(&format!("DO $$ BEGIN IF EXISTS (SELECT 1 FROM _ores_migrations WHERE name = '{name}' AND sha256 <> '{digest}') THEN RAISE EXCEPTION 'Migration checksum mismatch: {name}'; END IF; END $$;\nSELECT NOT EXISTS (SELECT 1 FROM _ores_migrations WHERE name = '{name}') AS pending \\gset\n\\if :pending\n"));
        sql.push_str(std::str::from_utf8(&data)?);
        sql.push_str(&format!(
            "\nINSERT INTO _ores_migrations(name, sha256) VALUES ('{name}', '{digest}');\n\\endif\n"
        ));
    }
    sql.push_str("COMMIT;\n");
    Ok(sql)
}
fn run() -> Result<()> {
    let root = root();
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("check-wit") => {
            let mut resolve = wit_parser::Resolve::default();
            resolve.push_path(root.join("contracts/workflow.wit"))?;
            println!("WIT component interface parsed successfully");
        }
        Some("routes") => {
            let map: serde_json::Value = serde_json::from_str(&fs::read_to_string(
                root.join("contracts/live.route-map.json"),
            )?)?;
            let handlers: BTreeMap<String, String> =
                serde_json::from_str(&fs::read_to_string(root.join("contracts/handlers.json"))?)?;
            let operations = map["map"].as_object().ok_or("route map operations")?;
            if operations.len() != handlers.len() {
                return Err("route/handler inventory mismatch".into());
            }
            let contract: serde_json::Value = serde_json::from_str(&fs::read_to_string(
                root.join("generated/api/live/contract.json"),
            )?)?;
            let digest = contract["contractSha256"]
                .as_str()
                .ok_or("contract digest")?;
            let mut source = String::new();
            for (index, (key, operation)) in operations.iter().enumerate() {
                let actor = handlers.get(key).ok_or("missing actor binding")?;
                if !actor
                    .bytes()
                    .all(|c| c.is_ascii_alphanumeric() || c == b'_')
                {
                    return Err("invalid actor binding".into());
                }
                let path = operation["path"].as_str().ok_or("route path")?;
                if path.contains(['{', '}', '*']) {
                    return Err("dynamic routes need reviewed capture bindings".into());
                }
                let pattern = if path == "/" {
                    "http_routing.root()".to_owned()
                } else {
                    let segments: Vec<String> = path
                        .strip_prefix('/')
                        .ok_or("absolute route required")?
                        .split('/')
                        .map(|part| {
                            format!(
                                "http_routing.literal({})",
                                serde_json::to_string(part).unwrap()
                            )
                        })
                        .collect();
                    format!(
                        "http_routing.path({}, arr[{}])",
                        serde_json::to_string(path)?,
                        segments.join(", ")
                    )
                };
                source.push_str(&format!("    val path_{index} = {pattern};\n"));
                for method in operation["methods"].as_array().ok_or("route methods")? {
                    source.push_str(&format!("    builder.route({}, rt borrow path_{index}, http.handler({}), 0, 1, {}).unwrap();\n", serde_json::to_string(method)?, serde_json::to_string(actor)?, serde_json::to_string(key)?));
                }
            }
            let template = fs::read_to_string(root.join("src/server.ores.in"))?;
            let marker = "  // @generated-route-registration";
            if template.matches(marker).count() != 1 {
                return Err("server template must have exactly one route marker".into());
            }
            fs::write(
                root.join("src/main.ores"),
                template.replace(marker, &source),
            )?;
            fs::write(
                root.join("generated/routes.ores"),
                format!(
                    "define module routes as\n  pub fnc contract_sha256(): string {{ return {}; }}\nend\n",
                    serde_json::to_string(digest)?
                ),
            )?;
        }
        Some("embed-assets") => {
            let mut source = String::from("define module assets as\n");
            for (name, filename) in [("htmx_js", "htmx.min.js"), ("app_css", "app.css")] {
                let text = fs::read_to_string(root.join("static").join(filename))?;
                source.push_str(&format!(
                    "  pub fnc {name}(): string {{ return {}; }}\n",
                    serde_json::to_string(&text)?
                ));
            }
            source.push_str("end\n");
            fs::write(root.join("generated/assets.ores"), source)?;
        }
        Some("check-models") => {
            let exported = model_export(&root)?;
            if exported != fs::read_to_string(root.join("generated/schema.sql"))?
                || exported != fs::read_to_string(root.join("migrations/schema.snapshot.sql"))?
            {
                return Err("model/schema/snapshot drift; export and review a migration".into());
            }
            println!("Native model, generated schema and migration snapshot agree");
        }
        Some("plan") => {
            let name = args
                .get(2)
                .ok_or("plan requires a lowercase migration name")?;
            if name.is_empty()
                || name.len() > 48
                || !name.as_bytes()[0].is_ascii_lowercase()
                || !name
                    .bytes()
                    .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'_')
            {
                return Err("invalid migration name".into());
            }
            let exported = model_export(&root)?;
            let candidate = plan(
                &fs::read_to_string(root.join("migrations/schema.snapshot.sql"))?,
                &exported,
            )?;
            if candidate.is_empty() {
                println!("No model changes");
                return Ok(());
            }
            let files = migrations(&root)?;
            let last =
                files.last().unwrap().file_name().unwrap().to_str().unwrap()[..4].parse::<u32>()?;
            if last >= 9999 {
                return Err("migration sequence exhausted".into());
            }
            let file = root
                .join("migrations")
                .join(format!("{:04}_{name}.sql", last + 1));
            let mut target = fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&file)?;
            target.write_all(candidate.as_bytes())?;
            fs::write(root.join("generated/schema.sql"), &exported)?;
            fs::write(root.join("migrations/schema.snapshot.sql"), &exported)?;
            println!("Candidate written for review: {}", file.display());
        }
        Some("apply") => {
            if env::var("PGDATABASE").unwrap_or_default().is_empty() {
                return Err("Set PGDATABASE explicitly; PGHOST/PGPORT/PGUSER are supported".into());
            }
            let script = apply_script(&migrations(&root)?)?;
            let mut child = Command::new("psql")
                .args(["-X", "--set=ON_ERROR_STOP=1", "--quiet"])
                .stdin(Stdio::piped())
                .spawn()?;
            child.stdin.take().unwrap().write_all(script.as_bytes())?;
            if !child.wait()?.success() {
                return Err("migration failed; transaction rolled back".into());
            }
        }
        _ => {
            return Err(
                "usage: tool {check-wit|routes|embed-assets|check-models|plan NAME|apply}".into(),
            );
        }
    }
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    const BASE: &str = "CREATE TABLE \"base\" (\n  \"id\" uuid NOT NULL\n);\n";
    #[test]
    fn rejects_removal_and_redefinition() {
        let changed = BASE.replace("uuid", "text");
        assert!(plan(BASE, &changed).is_err());
        assert!(plan(BASE, &BASE.replace("base", "other")).is_err());
    }
    #[test]
    fn additive_plan_preserves_dependency_order() {
        let extra = "CREATE TABLE \"z_parent\" (\n  \"id\" uuid NOT NULL\n);\nCREATE TABLE \"a_child\" (\n  FOREIGN KEY (id) REFERENCES z_parent(id)\n);\n";
        assert_eq!(plan(BASE, &format!("{BASE}{extra}")).unwrap(), extra);
        assert_eq!(plan(BASE, BASE).unwrap(), "");
    }
    #[test]
    fn filename_admission() {
        assert!(migration_name("0001_initial.sql"));
        for name in ["0001_x';drop.sql", "0001_.sql", "../0001_initial.sql"] {
            assert!(!migration_name(name));
        }
    }
    #[test]
    fn rejects_incomplete_schema() {
        assert!(tables("CREATE TABLE \"x\" (\n").is_err());
    }
}
