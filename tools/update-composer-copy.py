import json
from pathlib import Path
updates = {
 'th': {
 'research_intro': 'วิจัยตลาดใช้เวลา 3 วัน ส่วน Manual เปิดห้องแต่งเพลงกับ Alice ลากบล็อกแนวดนตรีและปรับความเร็วได้อย่างอิสระค่ะ',
 'mode_prompt': 'พี่จะทำเพลงแบบไหนคะ? Manual ลากบล็อกแนวดนตรีและปรับความเร็วกับ Alice ส่วน Auto ให้ทีมเรียงเอง ได้โบนัสไอเดียน้อยกว่า พี่ยังเลือกทีมและเวลาอัดได้ค่ะ',
 'tutorial_gather': 'รอทีมเดินมาที่ Lounge แล้วเราจะเริ่มแต่งเพลงกันค่ะ',
 'tutorial_arrange': 'เลือกแนวแล้วลากบล็อกลงช่อง ผสมแนวและใช้บล็อกซ้ำได้ ลองจัดให้ครบทั้ง 4 เครื่องดนตรี ฟังแล้วกดใช้เพลงนี้ค่ะ',
 'jam_guide_1': 'ใช้บล็อกซ้ำ ย้ายข้ามแถว หรือวางทับได้อิสระ คลิกขวาเพื่อลบ ไม่มีเวลานับถอยหลังค่ะ',
 'jam_start': 'เริ่มแต่งเพลง', 'jam_ready_hint': 'เลือกแนวดนตรีแล้วลากลงตาราง หรือคลิกบล็อกแล้วคลิกช่อง ปรับ BPM แล้วลองฟังได้เลยค่ะ',
 'jam_guide_paused': 'ใช้เวลาแต่งเพลงได้ตามต้องการ'
 },
 'en': {
 'research_intro': 'Market research takes 3 game days. Manual opens composition with Alice: drag musical styles freely and adjust tempo.',
 'mode_prompt': 'How shall we compose? Manual lets you arrange genre blocks and tempo with Alice. Auto gives a smaller idea bonus. You still choose the team and recording schedule.',
 'tutorial_gather': 'Wait for the team to reach the Lounge, then start composing.',
 'tutorial_arrange': 'Pick a genre and drag blocks onto the grid. Reuse and mix styles across all four instruments. Listen, then use your song.',
 'jam_guide_1': 'Reuse blocks, move between lanes or replace clips. Right-click to remove. There is no countdown.',
 'jam_start': 'Start composing', 'jam_ready_hint': 'Drag genre blocks onto the grid, or click a block then a cell. Set BPM and listen.',
 'jam_guide_paused': 'Take your time composing.'
 }
}
for lang, values in updates.items():
 for path in Path('data', lang).glob('*.json'):
  data=json.loads(path.read_text(encoding='utf-8-sig'))
  found=data.keys() & values.keys()
  if found:
   data.update({k:values[k] for k in found})
   path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
