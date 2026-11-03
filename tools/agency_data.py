import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
prefixes = 'Amber Aurora Bluebird Bright Cedar Cherry Coral Crescent Crystal Dawn Emerald Evergreen Golden Harbor Indigo Ivory Juniper Lunar Maple Meadow Meridian Moonstone Northstar Ocean Olive Orchid Phoenix Silver Skyline Willow'.split()
suffixes = ['Records', 'Media', 'Studios', 'Foods', 'Fashion', 'Games', 'Travel', 'Electronics', 'Beverages', 'Entertainment']
names = [f'{a} {b}' for a in prefixes for b in suffixes]
assert len(names) == len(set(names)) == 300
(root / 'data/company_list.json').write_text(json.dumps(names, indent=2) + '\n', encoding='utf-8')
copy = {
'en': {'agency_help': 'Buy a Consult package for $800. Keep it until you use Market Research with a client.\nResearch has an additional fee based on genre complexity, team size and urgency.', 'agency_stock': 'Consult packages: %d', 'agency_research': 'Market Research | %d packages | Service fee %s', 'agency_funds': 'Research requires an additional %s. Your package has not been used.'},
'th': {'agency_help': 'ซื้อแพ็กเกจ Consult ราคา $800 เก็บไว้จนกดทำ Market Research กับลูกค้า\nค่าทำวิจัยคิดเพิ่มตามจำนวนแนวเพลง ขนาดทีม และความเร่งด่วนของงาน', 'agency_stock': 'แพ็กเกจ Consult ที่มี: %d', 'agency_research': 'Market Research | แพ็กเกจ %d | ค่าบริการ %s', 'agency_funds': 'ต้องจ่ายค่าทำวิจัยเพิ่ม %s ยังไม่ได้ใช้แพ็กเกจของคุณ'}
}
for lang, values in copy.items():
    (root / f'data/{lang}/agency.json').write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
