import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
en={
'arr_save_back':'Save draft & back','arr_advice':'Ask Alice','arr_undo':'Undo','arr_redo':'Redo','arr_deselect':'Inspect clips','arr_copy':'Copy: click destination','arr_delete':'Delete','arr_pitch':'Pitch +2','arr_clip_volume':'Clip volume','arr_loop':'Click to loop this section; click again for full song','arr_energy':'Energy','arr_density':'Texture: %d%% occupied | Right-click removes a clip',
'arr_clip_0':'Steady pulse','arr_clip_1':'Bouncy groove','arr_clip_2':'Airy space',
'arr_brief_cafe':'CAFE | Calm, spacious and easy to loop.\nAim for 70–105 BPM and a light texture. Keep the hook gentle.',
'arr_brief_sport':'SPORT | Build energy for a short sports advert.\nAim for 120–160 BPM. Let the Hook feel stronger than the Verse.',
'arr_brief_debut':'DEBUT | Give the artist a memorable signature.\nAim for 95–140 BPM, a recurring melody and a stronger Hook.',
'arr_advice_empty':'Alice: Start with one sound you like. Click a palette clip to hear it.',
'arr_advice_tempo':'Alice: The speed is outside this brief’s range. Try adjusting tempo and listen again.',
'arr_advice_dense':'Alice: This brief needs more space. Try removing a layer instead of adding one.',
'arr_advice_rise':'Alice: The Verse and Hook have similar energy. Try saving a layer for the Hook.',
'arr_advice_hook':'Alice: Bring a melody back in the Hook so listeners have something to remember.',
'arr_advice_good':'Alice: The main shape fits. Listen through the transitions before submitting.',
'arr_report':'Brief fit: %d/40\nStructure: %d/25\nHook: %d/20\nArtist fit: %d/15\nCommission suitability: %d/100',
'demo_entry':'Demo: three commissions','demo_next':'Demo %d/3 | Your next brief is on the commissions board.',
'demo_end':'DEMO COMPLETE\nYou released three songs and shaped an artist’s first chapter.\n%s\nYou can keep playing this save or return to the title.',
'demo_continue':'Continue this studio','demo_title':'Return to title'}
th={
'arr_save_back':'บันทึกร่างและกลับ','arr_advice':'ถาม Alice','arr_undo':'ย้อนกลับ','arr_redo':'ทำซ้ำ','arr_deselect':'เลือกแก้คลิป','arr_copy':'คัดลอก: กดช่องปลายทาง','arr_delete':'ลบ','arr_pitch':'เสียงสูงขึ้น +2','arr_clip_volume':'ระดับเสียงคลิป','arr_loop':'กดเพื่อฟังวนท่อนนี้ กดอีกครั้งเพื่อฟังทั้งเพลง','arr_energy':'ระดับพลัง','arr_density':'ความแน่น: ใช้พื้นที่ %d%% | คลิกขวาเพื่อลบคลิป',
'arr_clip_0':'จังหวะมั่นคง','arr_clip_1':'จังหวะโยก','arr_clip_2':'โปร่งเบา',
'arr_brief_cafe':'ร้านกาแฟ | สงบ โปร่ง ฟังวนได้\nช่วงแนะนำ 70–105 BPM ใช้เสียงไม่แน่นเกินไป และรักษาความนุ่มใน Hook',
'arr_brief_sport':'โฆษณากีฬา | กระชับและมีพลังขึ้นช่วงท้าย\nช่วงแนะนำ 120–160 BPM ให้ Hook มีพลังมากกว่า Verse',
'arr_brief_debut':'เพลงเปิดตัว | สร้างท่อนจำให้ศิลปิน\nช่วงแนะนำ 95–140 BPM นำทำนองกลับมาใน Hook และเพิ่มพลังจาก Verse',
'arr_advice_empty':'Alice: เริ่มจากเสียงที่ชอบก่อนค่ะ กดคลิปในแถบเสียงเพื่อทดลองฟังได้เลย',
'arr_advice_tempo':'Alice: ความเร็วยังอยู่นอกช่วงที่บรีฟแนะนำค่ะ ลองปรับแล้วฟังอีกครั้งนะคะ',
'arr_advice_dense':'Alice: งานนี้ต้องการพื้นที่ว่างมากกว่านี้ค่ะ ลองลดเครื่องดนตรีบางช่วงดูนะคะ',
'arr_advice_rise':'Alice: Verse กับ Hook ยังมีพลังใกล้กันค่ะ ลองเก็บเครื่องดนตรีบางชิ้นไว้เข้าตอน Hook นะคะ',
'arr_advice_hook':'Alice: ลองนำทำนองเดิมกลับมาใน Hook ให้ผู้ฟังจดจำได้ค่ะ',
'arr_advice_good':'Alice: โครงหลักเข้ากับบรีฟแล้วค่ะ ลองฟังรอยต่อแต่ละท่อนก่อนส่งนะคะ',
'arr_report':'ตรงบรีฟ: %d/40\nโครงสร้าง: %d/25\nท่อนจำ: %d/20\nเข้ากับศิลปิน: %d/15\nความเหมาะกับงาน: %d/100',
'demo_entry':'เดโม: สามงานแรก','demo_next':'เดโม %d/3 | บรีฟถัดไปอยู่ที่กระดานรับงานค่ะ',
'demo_end':'จบเดโมแล้ว\nคุณปล่อยเพลงครบสามเพลง และสร้างบทแรกของศิลปินสำเร็จ\n%s\nเลือกเล่นค่ายนี้ต่อ หรือกลับหน้าแรกได้',
'demo_continue':'เล่นค่ายนี้ต่อ','demo_title':'กลับหน้าแรก'}
for lang,data in [('en',en),('th',th)]:
 data['arr_style'] = 'รูปแบบจังหวะ' if lang == 'th' else 'Style / Rhythm'
 data['arr_artist'] = 'แนวถนัดของศิลปิน: %s' if lang == 'th' else 'Artist signature: %s'
 (root/f'data/{lang}/arrangement.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
