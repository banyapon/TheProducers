local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local C=L.C;local A={}
A.notes={'cyan-eighth','pink-double','gold-beamed','lime-quarter','purple-spark','coral-pair','blue-chord','white-rest'}
A.bubbles={{id='555-laugh',text='555',emoji='laugh'},{id='bruh-smirk',text='BRUH',emoji='smirk'},{id='gg-ez-troll',text='GG EZ',emoji='troll'},{id='sus-eyes',text='SUS',emoji='eyes'},{id='nope-angry',text='NOPE!',emoji='angry'},{id='ok-sweat',text='OK...',emoji='sweat'},{id='what-skull',text='???',emoji='skull'},{id='wow-fire',text='WOW!',emoji='fire'},{id='afk-sleep',text='AFK',emoji='sleep'},{id='ez-cry',text='EZ?',emoji='cry'}}
local function note(im,x,y,color,double)
 L.ellipse(im,x,y+9,7,5,C.ink);L.ellipse(im,x+1,y+10,5,3,color)
 L.rect(im,x+5,y,2,12,C.ink);L.rect(im,x+6,y+1,1,10,color)
 if double then
  L.ellipse(im,x+8,y+6,7,5,C.ink);L.ellipse(im,x+9,y+7,5,3,color);L.rect(im,x+13,y-3,2,12,C.ink);L.rect(im,x+14,y-2,1,10,color)
  L.poly(im,{{x+5,y},{x+15,y-3},{x+15,y},{x+5,y+3}},C.ink);L.line(im,x+7,y+1,x+13,y-1,color)
 else L.poly(im,{{x+5,y},{x+12,y+2},{x+12,y+6},{x+7,y+4}},C.ink);L.line(im,x+7,y+1,x+10,y+3,color) end
end
function A.note(id,frame)
 local im=L.image(24,24);local colors={C.cyan,C.pink,C.goldHi,C.lime,C.purple,C.coral,C.blueHi,C.white};local color=colors[id]
 local y=8-math.floor((frame-1)*1.2);local x=4+({0,1,1,0,-1,0})[frame]
 if id==8 then
  L.poly(im,{{11,y-1},{16,y+3},{12,y+7},{15,y+10},{10,y+15},{11,y+10},{8,y+7},{12,y+3}},C.ink)
  L.line(im,12,y+1,14,y+3,color);L.line(im,14,y+3,10,y+7,color);L.line(im,10,y+7,13,y+10,color);L.line(im,13,y+10,11,y+13,color)
 else note(im,x,y,color,id==2 or id==3 or id==6 or id==7) end
 if id==5 or id==7 then
  L.px(im,19,y+5,color);L.line(im,18,y+3,18,y+5,color);L.line(im,17,y+4,19,y+4,color)
 end
 if frame==2 or frame==5 then L.px(im,3,y+1,C.white);L.px(im,20,y+10,color) end
 return im
end
local function face(im,x,y,kind,phase)
 if kind=='eyes' then
  L.ellipse(im,x+1,y+3,7,10,C.ink);L.ellipse(im,x+8,y+3,7,10,C.ink)
  L.ellipse(im,x+2,y+4,5,8,C.white);L.ellipse(im,x+9,y+4,5,8,C.white)
  L.rect(im,x+5,y+7,2,4,C.ink);L.rect(im,x+12,y+7,2,4,C.ink);return
 elseif kind=='skull' then
  L.ellipse(im,x+1,y+1,14,12,C.ink);L.ellipse(im,x+2,y+2,12,10,C.white);L.rect(im,x+5,y+11,6,4,C.white)
  L.rect(im,x+4,y+5,3,4,C.ink);L.rect(im,x+10,y+5,3,4,C.ink);L.px(im,x+8,y+10,C.ink);L.line(im,x+7,y+12,x+7,y+14,C.slate);L.line(im,x+10,y+12,x+10,y+14,C.slate);return
 elseif kind=='fire' then
  L.poly(im,{{x+8,y},{x+13,y+6},{x+14,y+3},{x+16,y+10},{x+12,y+15},{x+4,y+15},{x+1,y+11},{x+3,y+5},{x+5,y+8}},C.red)
  L.poly(im,{{x+8,y+4},{x+12,y+10},{x+11,y+14},{x+5,y+14},{x+4,y+10}},C.gold);L.poly(im,{{x+8,y+8},{x+10,y+13},{x+6,y+13}},C.goldHi);return
 end
 L.ellipse(im,x,y,16,16,C.ink);L.ellipse(im,x+1,y+1,14,14,C.gold);L.ellipse(im,x+2,y+2,10,5,C.goldHi)
 if kind=='laugh' then
  L.line(im,x+3,y+6,x+5,y+5,C.ink);L.line(im,x+5,y+5,x+6,y+6,C.ink);L.line(im,x+10,y+6,x+11,y+5,C.ink);L.line(im,x+11,y+5,x+13,y+6,C.ink)
  L.ellipse(im,x+4,y+8,9,6,C.ink);L.rect(im,x+5,y+8,7,2,C.white);L.rect(im,x+7,y+12,4,1,C.pink)
 elseif kind=='smirk' or kind=='troll' then
  L.line(im,x+3,y+5,x+6,y+6,C.ink);L.line(im,x+10,y+6,x+13,y+5,C.ink)
  L.px(im,x+5,y+7,C.ink);L.px(im,x+11,y+7,C.ink)
  L.line(im,x+4,y+11,x+11,y+12,C.ink);L.line(im,x+11,y+12,x+13,y+9,C.ink)
  if kind=='troll' then L.rect(im,x+5,y+11,6,1,C.white);L.px(im,x+6,y+13,C.ink) end
 elseif kind=='angry' then
  L.line(im,x+3,y+4,x+6,y+6,C.ink);L.line(im,x+10,y+6,x+13,y+4,C.ink)
  L.rect(im,x+5,y+7,1,2,C.ink);L.rect(im,x+10,y+7,1,2,C.ink);L.line(im,x+5,y+12,x+11,y+12,C.ink);L.px(im,x+8,y+11,C.ink)
 elseif kind=='sleep' then
  L.line(im,x+3,y+7,x+6,y+7,C.ink);L.line(im,x+10,y+7,x+13,y+7,C.ink);L.ellipse(im,x+7,y+10,3,3,C.ink)
 elseif kind=='cry' then
  L.line(im,x+3,y+6,x+6,y+5,C.ink);L.line(im,x+10,y+5,x+13,y+6,C.ink);L.rect(im,x+4,y+7,2,6,C.blueHi);L.rect(im,x+11,y+7,2,6,C.blueHi);L.ellipse(im,x+7,y+10,3,4,C.ink)
 elseif kind=='sweat' then
  L.rect(im,x+4,y+6,1,2,C.ink);L.rect(im,x+10,y+6,1,2,C.ink);L.line(im,x+5,y+11,x+10,y+11,C.ink)
  L.poly(im,{{x+13,y+1},{x+16,y+6},{x+13,y+8},{x+11,y+6}},C.blueHi)
 end
end
function A.bubble(spec,frame)
 local im=L.image(80,36);local dy=({3,1,0,0,1,2})[frame]
 L.poly(im,{{3,dy+1},{75,dy+1},{78,dy+4},{78,dy+24},{75,dy+27},{22,dy+27},{16,dy+31},{16,dy+27},{4,dy+27},{1,dy+24},{1,dy+4}},C.ink)
 L.poly(im,{{4,dy+3},{74,dy+3},{76,dy+5},{76,dy+23},{74,dy+25},{21,dy+25},{18,dy+29},{18,dy+25},{4,dy+25},{3,dy+23},{3,dy+5}},C.white)
 L.line(im,5,dy+4,73,dy+4,C.paper);L.text(im,8,dy+10,spec.text,C.ink);face(im,58,dy+6,spec.emoji,frame)
 return im
end
function A.build()
 local noteSheet=L.image(144,24*#A.notes);local bubbleSheet=L.image(480,36*#A.bubbles)
 local index=assert(io.open(root..'effects/index.csv','w'));index:write('effect,type,width,height,frames,frame_ms\n')
 local function saveAnimation(id,kind,w,h,render,row,sheet,ms)
  local s=Sprite(w,h,ColorMode.RGB);s:setPalette(L.palette);s.layers[1].name=kind=='note' and 'Floating music note - crisp pixels' or 'Pixel speech bubble + emoji'
  local strip=L.image(w*6,h)
  for f=1,6 do if f>1 then s:newEmptyFrame() end;local im=render(f);s:newCel(s.layers[1],f,im,Point(0,0));s.frames[f].duration=ms/1000;strip:drawImage(im,Point((f-1)*w,0));sheet:drawImage(im,Point((f-1)*w,row*h)) end
  local t=s:newTag(1,6);t.name=kind=='note' and 'Float' or 'Pop and chat'
  s:saveAs(root..'effects/'..id..'.aseprite');s:saveAs(root..'effects/'..id..'.gif');s:close()
  L.saveImage(strip,root..'effects/'..id..'-6frames')
  index:write(string.format('%s,%s,%d,%d,6,%d\n',id,kind,w,h,ms))
 end
 for i,id in ipairs(A.notes) do saveAnimation('note-'..id,'note',24,24,function(f) return A.note(i,f) end,i-1,noteSheet,100) end
 for i,spec in ipairs(A.bubbles) do saveAnimation('chat-'..spec.id,'chat',80,36,function(f) return A.bubble(spec,f) end,i-1,bubbleSheet,130) end
 L.saveImage(noteSheet,root..'effects/music-notes-atlas');L.saveImage(bubbleSheet,root..'effects/chat-emoji-atlas');index:close()
end
return A
