local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local Rooms=dofile(root..'source/side-room-art.lua');local Instruments=dofile(root..'source/instrument-art.lua');local C=L.C
local W,H=1024,576
local sky,city,ground,rooms,people,props,front,labels=L.image(W,H),L.image(W,H),L.image(W,H),L.image(W,H),L.image(W,H),L.image(W,H),L.image(W,H),L.image(W,H)
for y=0,H-1,16 do local t=y/(H-1);L.rect(sky,0,y,W,16,app.pixelColor.rgba(math.floor(116+91*t),math.floor(151+34*t),math.floor(190-20*t),255)) end
for i=0,28 do local x=i*39-12;local height=48+(i*37)%130
 L.rect(city,x,472-height,32,height,L.color('617d98',42));L.rect(city,x+5,466-height,23,7,L.color('617d98',42))
 for yy=480-height,464,11 do for xx=x+6,x+26,8 do L.rect(city,xx,yy,3,5,L.color('e2dfc8',30)) end end
end
L.rect(ground,0,472,W,104,C.greenDark);L.rect(ground,0,472,W,7,C.leaf);L.rect(ground,0,479,W,2,C.leafDark)
local baseX,baseY=104,184
L.rect(rooms,baseX,baseY,48,288,C.ink);L.rect(rooms,baseX+3,baseY+4,42,280,C.edge)
local types={'recording','office','meeting','lounge','cafeteria','storage'}
local actorSources={}
for _,name in ipairs({'producer-mini-6x4.png','secret-mini-6x4.png'}) do local s=Sprite{fromFile='D:/EP45/ndlp/Producers/'..name};actorSources[#actorSources+1]=L.fromSprite(s);s:close() end
for i,kind in ipairs(types) do
 local x=baseX+48+((i-1)%3)*256;local y=baseY+math.floor((i-1)/3)*144
 local layers=Rooms.render(kind,256,144)
 for k=1,4 do rooms:drawImage(layers[k].image,Point(x,y)) end
 front:drawImage(layers[5].image,Point(x,y))
 local who=(i%2)+1;local actor=L.image(32,48);actor:drawImage(actorSources[who],Point(0,kind=='recording' and -96 or 0))
 local ax=({85,94,82,101,122,95})[i];local ay=83
 people:drawImage(actor,Point(x+ax,y+ay))
 if kind=='recording' then local _,guitar=Instruments.render(Instruments.specs[1],1);props:drawImage(guitar,Point(x+ax,y+ay)) end
 if kind=='lounge' then
  local bubble=dofile(root..'source/effects-art.lua').bubble({text='555',emoji='laugh'},3);props:drawImage(bubble,Point(x+ax-25,y+ay-41))
 end
end
for row=0,1 do
 local top=baseY+row*144;local left=baseX+8;local right=baseX+41
 L.line(rooms,left,top+128,right,top+16,C.silver);L.line(rooms,left+2,top+128,right+2,top+16,C.wallDark)
 for step=0,8 do local yy=top+25+step*12;local xx=right-math.floor((yy-top-16)*33/112);L.line(rooms,xx-1,yy,xx+9,yy,C.cream) end
 L.text(labels,baseX+5,top+8,row==0 and '2F' or '1F',C.white)
end
L.rect(rooms,baseX-8,baseY-8,832,10,C.edge);L.rect(rooms,baseX-8,baseY-8,832,3,C.slate)
L.rect(rooms,baseX,baseY+141,816,4,C.ink);L.rect(rooms,baseX-3,472,822,5,C.ink)
L.text(labels,baseX+270,baseY-34,'THE PRODUCERS',C.goldHi,2)
L.rect(labels,24,18,465,41,C.ink);L.text(labels,36,30,'SIDE VIEW - 32X48 PEOPLE',C.white,2)
L.text(labels,25,529,'SIX ROOMS / TWO FLOORS / SAME PIXEL SCALE',C.white)
L.saveLayers(W,H,{{name='Sky - discrete pixel colour bands',image=sky},{name='Faint city behind building',image=city},{name='Ground',image=ground},{name='Six room backdrops and stairs',image=rooms},{name='32x48 cast - scale reference',image=people},{name='Instrument and speech overlays',image=props},{name='Room foreground furniture',image=front},{name='Building labels',image=labels}},root..'previews/building-cutaway-preview')
