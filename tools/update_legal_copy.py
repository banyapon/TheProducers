"""Sync reviewable legal text into the runtime translation catalogues."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for lang in ("th", "en"):
    path = root / "data" / lang / "ui.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    for kind in ("terms", "privacy"):
        data[f"{kind}_body"] = (root / "docs" / f"legal-{lang}-{kind}.txt").read_text(encoding="utf-8").strip()
    data["accept_privacy"] = "ฉันอ่านและรับทราบนโยบายความเป็นส่วนตัว" if lang == "th" else "I have read and acknowledge the Privacy Policy"
    data["consent_hint"] = "ยอมรับข้อกำหนดและรับทราบนโยบาย ไม่ใช่ความยินยอมใช้ข้อมูลทุกกรณี | 2026-10-31" if lang == "th" else "Accept the Terms and acknowledge the Policy, not blanket data consent | 2026-10-31"
    data["signup_legal_hint"] = "ขั้นตอนถัดไป: อ่านข้อกำหนดและนโยบายความเป็นส่วนตัว" if lang == "th" else "Next: review the Terms and Privacy Policy."
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
