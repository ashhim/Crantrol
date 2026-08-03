Import("env")

from pathlib import Path
from typing import Dict


def parse_env_file(path: Path) -> Dict[str, str]:
    values: Dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if (
            (value.startswith('"') and value.endswith('"'))
            or (value.startswith("'") and value.endswith("'"))
        ):
            value = value[1:-1]
        values[key] = value
    return values


project_dir = Path(env.get("PROJECT_DIR", ".")).resolve()
repo_root = project_dir.parent
env_values = parse_env_file(repo_root / ".env")

define_map = {
    "FIREBASE_API_KEY": "FB_API_KEY",
    "FIREBASE_AUTH_DOMAIN": "FB_AUTH_DOMAIN",
    "FIREBASE_DATABASE_URL": "FB_DATABASE_URL",
    "FIREBASE_PROJECT_ID": "FB_PROJECT_ID",
    "FIREBASE_STORAGE_BUCKET": "FB_STORAGE_BUCKET",
    "FIREBASE_MESSAGING_SENDER_ID": "FB_MESSAGING_SENDER_ID",
    "FIREBASE_APP_ID": "FB_APP_ID",
    "FIREBASE_EMAIL": "FB_EMAIL",
    "FIREBASE_PASSWORD": "FB_PASSWORD",
}


def escape_c_string(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


generated_header = project_dir / ".pio" / "generated_env.h"
generated_header.parent.mkdir(parents=True, exist_ok=True)

lines = ["#pragma once"]
for env_key, cpp_key in define_map.items():
    value = env_values.get(env_key)
    if value:
        lines.append(f'#define {cpp_key} "{escape_c_string(value)}"')

generated_header.write_text("\n".join(lines) + "\n", encoding="utf-8")

env.Prepend(CPPPATH=[str(generated_header.parent)])
