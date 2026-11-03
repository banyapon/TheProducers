import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
en={
'shift_strategy':'SHIFT: market & artist', 'shift_no_vocal':'Sign a vocalist to choose an artist direction.',
'shift_outlook':'Market now: %s | Next 28-day cycle: %s\nArtist: %s | Signature: %s\nAudience loyalty: %d/100 | Artist trust: %d/100\nOpportunity for this song: %s\nChoose a direction, then express it in the arrangement. The named singer must record it. Market demand is evaluated at release; quality still matters.',
'shift_hold':'Keep the signature', 'shift_blend':'Blend into a new sound', 'shift_pivot':'Reinvent the artist',
'shift_desc_hold':'At least 60% signature genre: loyalty +6, trust +3, reach up to +5%.',
'shift_desc_blend':'At least 25% signature and 25% opportunity genre: loyalty -3, trust +2, reach up to +12%.',
'shift_desc_pivot':'At least 60% opportunity genre: loyalty -12, trust -6, reach up to +25%. At 24/40 or higher it becomes the new signature.',
'shift_result':'%s | %s | Sales %+d%% | Loyalty %+d | Trust %+d',
'shift_rules':'Genre percentages use placed clips in Manual. Missing the promise costs loyalty 5 and trust 4. Market share adds up to 10% reach; existing audience loyalty also changes sales. These are sales modifiers, not guaranteed income.',
'risk_title':'Studio protection', 'risk_active':'This protection is already active.', 'risk_bought':'Protection is active for 28 days.',
'risk_help':'Insurance: %d days left | Inspection: %d days left\nInsurance pays 60%% of the lost studio construction cost after a covered fire. Inspection halves the daily fire chance while active; it does not guarantee safety.\nFire still takes four days and leaves an empty lot. After extinguishing, decide whether to fund deadline coordination. You must rebuild a room yourself.',
'risk_insurance':'Insurance | $800 / 28 days', 'risk_inspection':'Electrical inspection | $1,200 / 28 days',
'risk_recovery':'The fire is out. The room is now an empty lot. Insurance paid %s.\nHow should we recover? You will still need to build a replacement room.',
'risk_rebuild':'Handle it ourselves | $0 | Keep current deadlines',
'risk_coordinate':'Emergency client coordination | $1,200 | Active deadlines +3 days, reputation -2',
'risk_done':'Recovery plan recorded. Rebuild the room from an empty lot. Each commission can receive this three-day extension once.',
'news_brand_pause':'The artist is taking a three-day break from new brand bookings.',
'news_action_0':'Investigate and compensate | New brand bookings paused for 3 days',
'news_action_1':'Issue an apology and arrange a remedy',
'news_action_2':'Wait for evidence before a public statement',
'news_evidence_0':'Evidence: witnesses confirm the public confrontation. Silence will hurt trust.',
'news_evidence_1':'Evidence: the fan relationship allegation is unverified. Waiting for facts has a smaller penalty.',
'news_evidence_2':'Evidence: the organizer confirms the missed booking. An apology with a remedy is effective.',
'news_outcome':'Cost $%d | Fame %+d | Trust %+d | Company reputation %+d'
}
th={
'shift_strategy':'SHIFT: ตลาดและศิลปิน', 'shift_no_vocal':'ต้องมีนักร้องในทีมก่อนเลือกทิศทางศิลปิน',
'shift_outlook':'ตลาดตอนนี้: %s | รอบ 28 วันถัดไป: %s\nศิลปิน: %s | แนวประจำตัว: %s\nความภักดีแฟนเพลง: %d/100 | ความไว้ใจศิลปิน: %d/100\nโอกาสของเพลงนี้: %s\nเลือกทิศทางแล้วเรียงเพลงให้ตรงคำสัญญา ต้องใช้นักร้องคนนี้อัดเพลงด้วย กระแสตลาดคิด ณ วันปล่อยเพลง และคุณภาพเพลงยังมีผล',
'shift_hold':'รักษาตัวตนเดิม', 'shift_blend':'ค่อย ๆ ผสมแนวใหม่', 'shift_pivot':'เปลี่ยนตัวตนศิลปิน',
'shift_desc_hold':'แนวประจำตัวอย่างน้อย 60%: ความภักดี +6 ความไว้ใจ +3 โอกาสเข้าถึงผู้ฟังเพิ่มสูงสุด 5%',
'shift_desc_blend':'แนวเดิมอย่างน้อย 25% และแนวใหม่ 25%: ความภักดี -3 ความไว้ใจ +2 โอกาสเข้าถึงผู้ฟังเพิ่มสูงสุด 12%',
'shift_desc_pivot':'แนวใหม่อย่างน้อย 60%: ความภักดี -12 ความไว้ใจ -6 โอกาสเข้าถึงผู้ฟังเพิ่มสูงสุด 25% หากเพลงได้ 24/40 ขึ้นไป จะเป็นแนวประจำตัวใหม่',
'shift_result':'%s | %s | ยอดขาย %+d%% | ความภักดี %+d | ความไว้ใจ %+d',
'shift_rules':'Manual คิดสัดส่วนจากคลิปที่วาง หากไม่ตรงคำสัญญา ความภักดี -5 และความไว้ใจ -4 ส่วนแบ่งแนวที่กำลังนิยมช่วยการเข้าถึงสูงสุด 10% ฐานแฟนเดิมมีผลต่อยอดขายด้วย ตัวเลขนี้เป็นตัวปรับยอดขาย ไม่ใช่รายได้ที่รับประกัน',
'risk_title':'ดูแลความเสี่ยง', 'risk_active':'ความคุ้มครองนี้ยังมีผลอยู่', 'risk_bought':'เริ่มความคุ้มครอง 28 วันแล้ว',
'risk_help':'ประกันเหลือ %d วัน | การตรวจระบบเหลือ %d วัน\nประกันจ่าย 60%% ของราคาสร้างห้องอัดที่เสียหายเมื่อเกิดไฟในช่วงคุ้มครอง การตรวจไฟฟ้าลดโอกาสเกิดไฟรายวันลงครึ่งหนึ่ง แต่ไม่ได้ป้องกันทั้งหมด\nไฟยังใช้เวลา 4 วันและห้องจะเป็นพื้นที่โล่ง หลังไฟดับเลือกจัดการกำหนดส่งงานได้ และต้องสร้างห้องทดแทนเอง',
'risk_insurance':'ประกัน | $800 / 28 วัน', 'risk_inspection':'ตรวจระบบไฟฟ้า | $1,200 / 28 วัน',
'risk_recovery':'ไฟดับแล้วค่ะ ห้องกลายเป็นพื้นที่โล่ง ได้เงินประกัน %s\nเราจะฟื้นตัวแบบไหนดีคะ? ยังต้องสร้างห้องใหม่ในพื้นที่ว่างค่ะ',
'risk_rebuild':'จัดการเอง | $0 | ใช้กำหนดส่งเดิม',
'risk_coordinate':'ประสานงานฉุกเฉิน | $1,200 | งานที่รับอยู่เพิ่ม 3 วัน ความน่าเชื่อถือ -2',
'risk_done':'บันทึกแผนฟื้นตัวแล้วค่ะ สร้างห้องใหม่จากพื้นที่ว่างได้เลย งานหนึ่งรับการขยายเวลาจากเหตุไฟไหม้ได้ครั้งเดียว',
'news_brand_pause':'ศิลปินพักรับงานแบรนด์ใหม่เป็นเวลา 3 วัน',
'news_action_0':'ตรวจสอบและชดเชย | พักรับงานแบรนด์ใหม่ 3 วัน',
'news_action_1':'ออกคำขอโทษและจัดการเยียวยา',
'news_action_2':'รอหลักฐานก่อนแถลงต่อสาธารณะ',
'news_evidence_0':'หลักฐาน: พยานยืนยันการทะเลาะในที่สาธารณะ การเงียบจะกระทบความไว้ใจ',
'news_evidence_1':'หลักฐาน: ข่าวความสัมพันธ์กับแฟนคลับยังไม่ยืนยัน การรอข้อเท็จจริงเสียหายน้อยกว่า',
'news_evidence_2':'หลักฐาน: ผู้จัดยืนยันการขาดงาน การขอโทษพร้อมเยียวยาช่วยได้',
'news_outcome':'ค่าใช้จ่าย $%d | ชื่อเสียง %+d | ความไว้ใจ %+d | ความน่าเชื่อถือบริษัท %+d'
}
for lang,data in [('en',en),('th',th)]:
 (root/f'data/{lang}/shift-quality.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
