"""Copy only public client settings into the Web export; never copy secrets."""
from pathlib import Path
import configparser
import json

root = Path(__file__).resolve().parents[1]
source = configparser.ConfigParser()
source.read(root / "config/secrets.cfg", encoding="utf-8-sig")
allowed = {"firebase": ["api_key", "project_id", "auth_domain"], "google": ["web_client_id"], "cloudinary": ["signing_url", "root_folder"]}
lines = []
for section, keys in allowed.items():
    lines.append(f"[{section}]")
    for key in keys:
        value = source.get(section, key, fallback="").strip('"')
        lines.append(f"{key}={json.dumps(value)}")
    if section == "cloudinary":
        lines.append('signing_mode="server"')
    lines.append("")
(root / "config/public.cfg").write_text("\n".join(lines), encoding="utf-8")
print("Public Web config generated (no private credentials).")
