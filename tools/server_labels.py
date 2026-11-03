"""Use player-facing Server terminology; retain provider disclosures in Legal."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
overrides = {
    "en": {
        "legacy_000": "Sign in before uploading to the Server",
        "legacy_088": "This sign-in method is unavailable on the Server.",
        "legacy_089": "Guest sign-in is unavailable on the Server.",
        "legacy_091": "Account services are unavailable on the Server.",
        "legacy_094": "The Server connection has not been configured.",
        "legacy_096": "The Server denied access. Please contact support.",
        "legacy_129": "Saved locally (Server storage is unavailable)",
        "legacy_132": "Saved on the Server",
        "scene_028": "Play as Guest",
        "ranking_setup": "The ranking Server is not configured.",
    },
    "th": {
        "legacy_000": "เข้าสู่ระบบก่อนอัปโหลดไปยัง Server",
        "legacy_088": "Server ยังไม่รองรับวิธีเข้าสู่ระบบนี้",
        "legacy_089": "Server ยังไม่เปิดให้เข้าสู่ระบบแบบ Guest",
        "legacy_091": "ระบบบัญชีบน Server ยังไม่พร้อมใช้งาน",
        "legacy_094": "ยังไม่ได้ตั้งค่าการเชื่อมต่อ Server",
        "legacy_096": "Server ปฏิเสธการเข้าถึง กรุณาติดต่อผู้ดูแล",
        "legacy_129": "เก็บไว้ในเครื่อง (พื้นที่เก็บบน Server ยังไม่พร้อม)",
        "legacy_132": "เก็บบน Server แล้ว",
        "scene_028": "เล่นแบบ Guest",
        "ranking_setup": "ยังไม่ได้ตั้งค่า Server สำหรับอันดับ",
    },
}
for lang in ("en", "th"):
    for path in (root / "data" / lang).glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for key, value in list(data.items()):
            if key in ("terms_body", "privacy_body") or not isinstance(value, str):
                continue
            revised = overrides[lang].get(key, value.replace("Firebase", "Server").replace("Cloudinary", "Server"))
            if revised != value:
                data[key] = revised
                changed = True
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
