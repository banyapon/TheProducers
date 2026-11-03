import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
en = {
'pt_title':'Local playtest & reports',
'pt_notice':'Optional playtest: starting creates a separate demo save and records action counts, preview variants, foreground time, progress, return visits and optional answers on this device only. No name, account, audio or song content is recorded in the report. Nothing is sent automatically. You can delete observations here; normal play is not tracked. Give a new player the controls without coaching them.',
'pt_start':'Agree & start a new playtest', 'pt_resume':'Resume selected playtest',
'pt_export':'Export local JSON', 'pt_delete':'Delete observations', 'pt_delete_confirm':'Confirm delete observations',
'pt_empty':'No observations yet. Start an optional playtest to create a separate demo.',
'pt_summary':'Sessions: %d | Foreground time: ~%d min (includes menus)\nRe-entries after completion: %d | Returned in a later app launch: %s',
'pt_job_missing':'Job %d: not started',
'pt_job':'Job %d (%s): accepted | Edits: %d | Different versions previewed: %d\nEdits after review: %d | Comparison clicks: %d | Released: %s',
'pt_yes':'Observed', 'pt_unobserved':'Not observed yet', 'pt_unanswered':'Skipped / unanswered',
'pt_choice_continue':'Ending choice: continue playing (not a later return)', 'pt_choice_title':'Ending choice: return to title', 'pt_choice_unobserved':'Ending choice: not observed',
'pt_question_explore':'I wanted to try changes beyond completing the brief.',
'pt_question_next':'I wanted to take another commission.',
'pt_question_return':'I would like to return and play again.',
'pt_scale':'Optional: 1 = strongly disagree, 5 = strongly agree. No answer changes your game.',
'pt_skip':'Skip',
'pt_caution':'Observations are proxies, not proof of enjoyment. Preview starts do not prove full listening; revisions may mean confusion. Self-reported intent is separate from actual return. This is one local test run, not a verified unique person; no return observed is not proof of rejection.',
}
th = {
'pt_title':'ทดสอบผู้เล่นและรายงานในเครื่อง',
'pt_notice':'โหมดสมัครใจ: เริ่มแล้วจะสร้างเซฟเดโมแยก เก็บจำนวนการกระทำ เวอร์ชันที่ลองฟัง เวลาที่เปิดเกมอยู่ด้านหน้า ความคืบหน้า การกลับมาเล่น และคำตอบที่เลือกไว้ในเครื่องนี้เท่านั้น รายงานไม่เก็บชื่อ บัญชี เสียง หรือเนื้อหาเพลง ไม่มีการส่งอัตโนมัติ ลบข้อมูลสังเกตได้ที่หน้านี้ การเล่นปกติไม่ถูกติดตาม ให้ผู้เล่นใหม่ลองควบคุมเองโดยไม่ช่วยบอกคำตอบ',
'pt_start':'ยอมรับและเริ่มรอบทดสอบใหม่', 'pt_resume':'เล่นต่อรอบทดสอบที่เลือก',
'pt_export':'ส่งออก JSON ลงเครื่อง', 'pt_delete':'ลบข้อมูลสังเกต', 'pt_delete_confirm':'ยืนยันลบข้อมูลสังเกต',
'pt_empty':'ยังไม่มีข้อมูล เริ่มโหมดทดสอบแบบสมัครใจเพื่อสร้างเดโมแยกได้',
'pt_summary':'จำนวนครั้งที่เข้าเล่น: %d | เวลาเปิดด้านหน้า: ประมาณ %d นาที (รวมหน้าเมนู)\nเข้าเซฟอีกครั้งหลังจบ: %d | กลับมาในการเปิดแอปครั้งใหม่: %s',
'pt_job_missing':'งาน %d: ยังไม่เริ่ม',
'pt_job':'งาน %d (%s): รับงานแล้ว | แก้ไข %d ครั้ง | ลองฟัง %d เวอร์ชัน\nแก้หลังตรวจเดโม %d ครั้ง | กดเทียบเสียง %d ครั้ง | ปล่อยเพลง: %s',
'pt_yes':'พบพฤติกรรม', 'pt_unobserved':'ยังไม่พบ', 'pt_unanswered':'ข้าม / ยังไม่ตอบ',
'pt_choice_continue':'ตัวเลือกตอนจบ: เล่นต่อทันที (ยังไม่นับเป็นการกลับมาเล่น)', 'pt_choice_title':'ตัวเลือกตอนจบ: กลับหน้าหลัก', 'pt_choice_unobserved':'ตัวเลือกตอนจบ: ยังไม่พบ',
'pt_question_explore':'ฉันอยากลองแก้เพลงเพิ่มเติม แม้จะทำตามบรีฟได้แล้ว',
'pt_question_next':'ฉันอยากรับงานเพลงถัดไป',
'pt_question_return':'ฉันอยากกลับมาเล่นเกมนี้อีก',
'pt_scale':'ตอบได้ตามสมัครใจ: 1 = ไม่เห็นด้วยเลย, 5 = เห็นด้วยมาก คำตอบไม่มีผลต่อเกม',
'pt_skip':'ข้าม',
'pt_caution':'ข้อมูลนี้เป็นเพียงสิ่งสังเกต ไม่ใช่หลักฐานยืนยันความสนุก การเปิดฟังไม่ได้ยืนยันว่าฟังจนจบ และการแก้อาจเกิดจากความสับสน ความตั้งใจจากคำตอบแยกจากการกลับมาจริง หนึ่งรอบไม่ใช่ผู้เล่นที่ยืนยันตัวตนแล้ว และยังไม่กลับมาไม่ได้แปลว่าไม่ชอบเกม',
}
assert en.keys() == th.keys()
for lang, values in [('en',en),('th',th)]:
    (root/'data'/lang/'playtest.json').write_text(json.dumps(values,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
