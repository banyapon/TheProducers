local G=dofile('D:/GitHub/TheProducers/tools/props/tree-style.lua')
-- Native pixel drawing, executed inside Aseprite; no resampling of old artwork.
local root='D:/GitHub/TheProducers/'
local out='D:/EP45/ndlp/Producers/Native-lots/'
app.fs.makeAllDirectories(out)
local L=dofile(root..'assets/lots/source/pixel-lib.lua')
local C=L.C;local R,B,E,P,T=L.rect,L.line,L.ellipse,L.poly,L.text
-- Match the warm charcoal character outlines; interior seams remain one pixel.
C.ink=L.color('2e2635')
local pc=app.pixelColor
local function shade(col,k)
 return pc.rgba(math.floor(pc.rgbaR(col)*k),math.floor(pc.rgbaG(col)*k),math.floor(pc.rgbaB(col)*k),255)
end
local function box(im,x,y,w,h,col)
 R(im,x,y,w,h,C.ink)
 local edge=(w>=24 and h>=18)and 2 or 1
 R(im,x+edge,y+edge,w-edge*2,h-edge*2,col)
 if w>=24 and h>=18 then
  R(im,x+w-4,y+3,2,h-5,shade(col,.77))
  R(im,x+3,y+h-4,w-6,2,shade(col,.77))
  B(im,x+3,y+2,x+w-4,y+2,shade(col,1.12))
 end
end
local function save(im,path)im:saveAs(path)end
local function source(name,back,front)
 local s=Sprite(back.width,back.height);s.layers[1].name='Architecture and rear props';s:newCel(s.layers[1],1,back,Point(0,0))
 local l=s:newLayer();l.name='Front props';s:newCel(l,1,front,Point(0,0));s:saveAs(out..name..'.aseprite');s:close()
end
local function stand(im,x,y,h)R(im,x,y-h,2,h,C.steel);B(im,x,y-5,x-12,y,C.edge);B(im,x,y-5,x+12,y,C.edge);R(im,x-1,y-h,1,h-5,C.silver)end
local function keyboard(im,x,y,w,organ,f)
 if organ then box(im,x,y-33,w,34,C.woodDark);R(im,x+2,y-31,w-4,3,C.woodHi)end
 box(im,x,y,w,18,organ and C.wood or C.edge);R(im,x+2,y+2,w-4,4,C.slate)
 for k=0,5 do R(im,x+6+k*6,y+3,2,2,k==f%6 and C.cyan or C.silver)end
 R(im,x+3,y+8,w-6,8,C.white)
 for k=0,math.floor((w-8)/4)do B(im,x+4+k*4,y+8,x+4+k*4,y+15,C.steel);if k%7~=2 and k%7~=6 then R(im,x+5+k*4,y+8,2,5,C.ink)end end
 if organ then R(im,x+3,y+18,5,43,C.woodDark);R(im,x+w-8,y+18,5,43,C.woodDark);box(im,x+10,y+54,w-20,7,C.wood);for k=0,8 do R(im,x+13+k*6,y+54,2,5,C.cream)end
 else B(im,x+10,y+18,x+w-12,y+61,C.ink);B(im,x+w-12,y+18,x+10,y+61,C.ink);B(im,x+11,y+18,x+w-11,y+61,C.steel);B(im,x+w-11,y+18,x+11,y+61,C.steel)end
end
local function instrument(id,f)
 local im=L.image(160,160);local d=({0,0,1,1,0,-1})[f]
 if id=='guitar' or id=='bass' then
  local x,y=65+d,68;local bass=id=='bass'
  P(im,{{x,y+9},{x+7,y+4},{x+14,y+7},{x+20,y+3},{x+27,y+6},{x+29,y+15},{x+25,y+24},{x+16,y+28},{x+6,y+26},{x,y+19}},C.ink)
  P(im,{{x+2,y+10},{x+8,y+6},{x+14,y+10},{x+20,y+5},{x+25,y+7},{x+27,y+15},{x+23,y+22},{x+16,y+26},{x+7,y+24},{x+2,y+18}},bass and C.redDark or C.wood)
  E(im,x+4,y+10,20,14,bass and C.red or C.gold);B(im,x+5,y+21,x+13,y+24,bass and C.redHi or C.goldHi)
  P(im,{{x+19,y+10},{x+50,y-15},{x+54,y-10},{x+23,y+15}},C.ink)
  B(im,x+22,y+11,x+52,y-12,C.woodHi);B(im,x+23,y+12,x+53,y-11,C.woodDark)
  P(im,{{x+48,y-17},{x+53,y-21},{x+58,y-16},{x+54,y-10}},C.ink);B(im,x+51,y-17,x+55,y-14,C.woodHi)
  for k=0,2 do R(im,x+49+k*3,y-18+k*2,2,1,C.silver)end
  if not bass then E(im,x+13,y+11,8,8,C.woodDark);E(im,x+15,y+13,4,4,C.ink)else R(im,x+14,y+12,3,8,C.cream);R(im,x+21,y+9,2,7,C.cream)end
  B(im,x+10,y+23,x+54,y-14,C.cream);B(im,x+10,y+25,x+55,y-13,C.sand);B(im,x+8,y+21,x+13,y+26,C.ink)
 elseif id=='mic' then
  stand(im,104,137,77);B(im,104,62,92,49,C.ink);B(im,105,61,93,48,C.silver)
  E(im,86,44,12,8,C.ink);E(im,87,45,9,5,C.steel);B(im,89,45,94,45,C.silver)
  for y=47,110 do local x=99+math.floor((y-47)/20);R(im,x,y,1,1,C.edge)end
 elseif id=='saxophone' then
  P(im,{{86+d,48},{92+d,50},{99+d,83},{108+d,83},{109+d,72},{119+d,71},{117+d,88},{109+d,96},{101+d,96},{94+d,89},{88+d,58}},C.ink)
  P(im,{{88+d,51},{91+d,53},{101+d,87},{108+d,88},{112+d,83},{112+d,75},{116+d,75},{114+d,88},{108+d,93},{102+d,93},{97+d,87}},C.gold)
  B(im,91+d,57,100+d,87,C.goldHi);E(im,108+d,69,13,8,C.goldDark);E(im,110+d,70,9,4,C.ink)
  for k=0,5 do R(im,92+d+k,62+k*4,3,2,C.goldHi)end
 elseif id=='electone' or id=='organ' then keyboard(im,42,76,94,id=='organ',f)
 elseif id=='drums' then
  stand(im,32,136,67);stand(im,135,136,74)
  E(im,10,66,45,5,C.goldDark);E(im,12,65,41,3,C.goldHi);R(im,31,62,3,4,C.gold)
  E(im,113,58,43,5,C.goldDark);E(im,115,57,39,3,C.goldHi);R(im,134,54,3,4,C.gold)
  for _,v in ipairs({{51,80,27,24},{83,78,26,25},{114,96,26,30}})do local x,y,w,h=table.unpack(v);box(im,x,y,w,h,C.redDark);R(im,x+2,y+2,w-4,h-4,C.red);R(im,x+4,y+4,3,h-8,C.redHi);E(im,x,y-3,w,7,C.steel);E(im,x+2,y-2,w-4,4,C.white);R(im,x,y+h-3,w,2,C.silver);for k=3,w-2,10 do R(im,x+k,y+7,2,h-12,C.silver)end end
  E(im,55,96,59,43,C.ink);E(im,57,97,55,40,C.red);E(im,61,99,48,37,C.silver);E(im,63,101,44,33,C.cream);E(im,92,121,7,7,C.ink)
  B(im,58,129,52,138,C.steel);B(im,109,129,115,138,C.steel)
  B(im,59,73-f%3,75,84,C.woodHi);B(im,103,70+f%3,88,82,C.woodHi)
 end
 return im
end
local ids={'guitar','drums','electone','saxophone','organ','mic','bass'}
local gallery=L.image(7*200,400)
local actor=app.open(root..'assets/sprites/male/play.png');local all=L.image(480,480);all:drawSprite(actor,1);local person=Image(all,Rectangle(160,160,160,160));actor:close()
local partner=app.open(root..'assets/sprites/alice/play.png');local partnerSheet=L.image(480,480);partnerSheet:drawSprite(partner,1);local alice=Image(partnerSheet,Rectangle(160,160,160,160));partner:close()
for i,id in ipairs(ids)do
 local sheet=L.image(960,160);local s=Sprite(160,160);s.layers[1].name='Native instrument - front';local fl=s.layers[1];local rear=nil;if id=='organ' then rear=s:newLayer();rear.name='Console behind performer';rear.stackIndex=1 end
 for f=1,6 do if f>1 then s:newEmptyFrame()end;local im=instrument(id,f);if rear then s:newCel(rear,f,Image(im,Rectangle(0,0,160,76)),Point(0,0));s:newCel(fl,f,Image(im,Rectangle(0,76,160,84)),Point(0,76))else s:newCel(fl,f,im,Point(0,0))end;sheet:drawImage(im,Point((f-1)*160,0));s.frames[f].duration=1/9 end
 s:newTag(1,6).name='play';s:saveAs(out..id..'.aseprite');s:close();save(sheet,root..'assets/instruments/'..id..'-6frames.png')
 R(gallery,(i-1)*200,0,200,200,C.edge);local inst=instrument(id,3);local pos=Point((i-1)*200+20,15);if id=='organ' then gallery:drawImage(Image(inst,Rectangle(0,0,160,76)),pos)end;gallery:drawImage(person,pos);if id=='organ' then gallery:drawImage(Image(inst,Rectangle(0,76,160,84)),Point(pos.x,pos.y+76))else gallery:drawImage(inst,pos)end;T(gallery,(i-1)*200+10,177,id,C.white)
 R(gallery,(i-1)*200,200,200,200,C.edge);local ap=Point((i-1)*200+20,215)
 if id=='organ' then gallery:drawImage(Image(inst,Rectangle(0,0,160,76)),ap)end
 gallery:drawImage(alice,ap)
 if id=='organ' then gallery:drawImage(Image(inst,Rectangle(0,76,160,84)),Point(ap.x,ap.y+76))else gallery:drawImage(inst,ap)end
 T(gallery,(i-1)*200+10,377,id..' / ALICE',C.white)
end
save(gallery,out..'instruments-with-producer.png')
local function desk(im,x,f,w,computer)
 box(im,x,f-59,w,9,C.wood);R(im,x+2,f-58,w-4,2,C.woodHi);R(im,x+5,f-50,5,50,C.woodDark);R(im,x+w-10,f-50,5,50,C.woodDark)
 box(im,x+w-37,f-49,29,32,C.wood);for i=0,1 do B(im,x+w-36,f-34+i*15,x+w-10,f-34+i*15,C.woodDark);R(im,x+w-25,f-42+i*15,7,1,C.ink)end
 if computer then box(im,x+19,f-102,49,34,C.edge);box(im,x+21,f-100,45,29,C.screen);R(im,x+23,f-98,41,1,C.screenHi);R(im,x+40,f-68,5,7,C.steel);R(im,x+31,f-62,24,3,C.ink);R(im,x+17,f-59,57,3,C.silver);for i=0,4 do R(im,x+25,f-94+i*4,26-i*4,1,C.cyan)end end
 box(im,x+4,f-64,10,5,C.paper);R(im,x+w-14,f-68,6,9,C.white)
end
local function chair(im,x,f)
 box(im,x,f-72,34,39,C.blueDark);R(im,x+2,f-70,30,2,C.blueHi);box(im,x-3,f-36,40,7,C.blue);R(im,x+3,f-29,3,29,C.edge);R(im,x+28,f-29,3,29,C.edge)
end
local function shelf(im,x,f,w,crates)
 box(im,x,f-147,w,147,C.woodDark);R(im,x+2,f-145,w-4,3,C.woodHi)
 for row=0,2 do local y=f-135+row*44;R(im,x+3,y+36,w-6,4,C.wood);R(im,x+3,y+36,w-6,1,C.woodHi)
  if crates then for j=0,1 do local xx=x+6+j*math.floor((w-10)/2);local ww=math.floor((w-16)/2);box(im,xx,y+7,ww,29,C.sand);R(im,xx+ww//2,y+8,3,27,C.cream);box(im,xx+4,y+14,9,6,C.paper)end
  else for j=0,math.floor((w-14)/7)do local yy=y+4+j%4;box(im,x+6+j*7,yy,6,32-j%4,({C.red,C.blue,C.green,C.gold,C.purple})[(row+j)%5+1]);R(im,x+8+j*7,yy+5,2,1,C.cream)end end
 end
end
local function plant(im,x,f)
 im:drawImage(G.draw(58,85,math.floor(x)%6,true),Point(x-17,f-82))
end
local roomGallery=L.image(1280,1080)
local kinds={'recording','lounge','office','meeting','cafeteria','storage'}
for index,kind in ipairs(kinds)do
 local im=L.image(640,360);local front=L.image(640,360);local wall=({recording='55333f',lounge='514657',office='445b6b',meeting='56636a',cafeteria='526b60',storage='535a60'})[kind]
 R(im,0,0,640,360,C.ink);R(im,4,5,632,315,L.color(wall));R(im,7,9,626,3,C.steel);R(im,7,14,626,1,C.edge)
 R(im,7,178,626,142,L.color(kind=='recording' and '392a36' or '39434b'));B(im,7,177,632,177,C.steel)
 for x=14,632,39 do R(im,x,181,1,135,C.edge)end
 R(im,7,313,626,7,C.edge);R(im,0,320,640,40,C.ink);R(im,4,320,632,2,C.steel)
 box(im,553,174,61,146,C.woodDark);box(im,557,178,53,138,C.wood);box(im,561,183,45,46,C.screen);R(im,563,185,41,1,C.screenHi);R(im,599,253,3,7,C.goldHi)
 box(im,22,37,#kind*6+14,17,C.edge);T(im,29,42,kind,C.white)
 if kind~='storage' then
  box(im,224,82,146,89,C.edge);box(im,227,85,140,83,kind=='recording' and C.screen or C.sky)
  for j=0,7 do local h=20+(j*13)%45;R(im,232+j*16,164-h,12,h,kind=='recording' and C.slate or C.cityMid);for y=167-h,159,7 do R(im,235+j*16,y,2,2,C.cityFar)end end
  R(im,294,86,3,81,C.steel);B(im,230,88,363,88,C.white)
 end
 if kind=='office' then
  desk(im,35,320,120,true);shelf(im,183,320,76,false);desk(im,371,320,135,true);plant(im,297,320)
  E(im,460,78,29,29,C.ink);E(im,462,80,25,25,C.paper);B(im,474,92,474,84,C.edge);B(im,474,92,481,96,C.edge)
 elseif kind=='storage' then
  shelf(im,30,320,95,true);shelf(im,145,320,95,true);shelf(im,428,320,90,true)
  for _,v in ipairs({{275,278,45,42},{281,245,34,33},{326,291,37,29}})do local x,y,w,h=table.unpack(v);box(im,x,y,w,h,C.wood);B(im,x+3,y+3,x+w-4,y+h-4,C.woodHi);B(im,x+w-4,y+3,x+3,y+h-4,C.woodHi);L.frame(im,x+2,y+2,w-4,h-4,C.sand)end
  box(im,35,110,84,20,C.goldDark);T(im,41,117,'KEEP DRY',C.cream)
 elseif kind=='meeting' then
  box(im,30,96,155,100,C.steel);box(im,33,99,149,94,C.paper);B(im,44,177,68,152,C.blue);B(im,68,152,98,166,C.blue);B(im,98,166,163,119,C.blue)
  for j=0,2 do R(im,48+j*28,120,18,3,C.coral)end
  for j=0,3 do chair(im,186+j*66,320)end
  desk(front,166,320,274,false);box(front,278,238,36,23,C.edge);box(front,280,240,32,18,C.screen);R(front,274,261,44,2,C.silver);plant(im,491,320)
 elseif kind=='cafeteria' then
  box(im,25,240,200,80,C.greenDark);R(im,27,242,196,4,C.silver)
  for j=0,3 do box(im,29+j*48,251,45,65,C.green);R(im,61+j*48,263,3,10,C.silver)end
  box(im,37,199,38,41,C.edge);box(im,41,204,30,20,C.screen);R(im,44,211,24,2,C.cyan);R(im,44,231,22,3,C.ink)
  for j=0,2 do E(im,99+j*35,234,26,6,C.steel);E(im,101+j*35,233,22,4,C.cream)end
  chair(im,285,320);chair(im,374,320);desk(front,269,320,145,false)
  box(im,465,183,62,137,C.redDark);box(im,470,190,43,83,C.screen);for j=0,2 do for k=0,2 do box(im,475+k*12,198+j*23,8,16,k%2==0 and C.gold or C.cyan)end end;box(im,473,287,40,18,C.ink);R(im,517,222,4,22,C.gold)
 elseif kind=='recording' then
  for x=24,521,24 do for y=69,215,27 do if x<214 or x>371 or y>175 then box(im,x,y,18,21,C.redDark);R(im,x+2,y+2,14,2,C.red);R(im,x+2,y+5,2,13,C.red);R(im,x+5,y+18,11,1,C.ink)end end end
  desk(im,28,320,183,false);box(im,31,252,177,24,C.edge)
  for j=0,19 do local x=36+j*8;B(im,x,256,x,269,C.slate);R(im,x-1,258+j%4*2,3,2,C.silver);R(im,x,254,1,1,j%3==0 and C.cyan or C.redHi)end
  box(im,84,218,62,32,C.edge);box(im,87,221,56,26,C.screen);for j=0,8 do R(im,91+j*5,227+j%4,2,16-j%4,C.greenHi)end
  for _,x in ipairs({34,174})do box(im,x,215,28,35,C.ink);E(im,x+5,221,18,18,C.slate);E(im,x+9,225,10,10,C.ink);E(im,x+10,242,7,5,C.steel)end
  im:drawImage(instrument('mic',1),Point(158,183));im:drawImage(instrument('drums',1),Point(348,181))
  box(im,438,118,68,19,C.redDark);T(im,445,124,'ON AIR',C.redHi)
 elseif kind=='lounge' then
  -- Retain the approved native lounge furniture and notice-board composition.
  local s=app.open(root..'assets/lots/rooms/lounge-16x9-back.png');im=L.image(640,360);im:drawSprite(s,1);s:close();box(im,22,37,50,17,C.edge);T(im,29,42,'LOUNGE',C.white)
 end
 -- Small fixture details use the same 1px highlights / 2px outlines as the cast.
 R(im,8,17,624,3,C.ink)
 for _,lx in ipairs({180,420})do
  R(im,lx,20,2,19,C.ink);box(im,lx-26,39,55,9,C.edge)
  R(im,lx-23,46,49,2,C.cream);R(im,lx-19,48,41,1,C.sand)
 end
 -- Recessed lower door panel and physical hinge plates.
 box(im,562,241,43,66,C.woodDark);box(im,565,244,37,60,C.wood)
 R(im,599,253,3,7,C.goldHi);R(im,556,204,3,9,C.steel);R(im,556,286,3,9,C.steel)
 -- Wall socket at hand height; tiny floor contact shadows anchor the set.
 box(im,533,265,9,13,C.silver);R(im,535,269,1,3,C.ink);R(im,539,269,1,3,C.ink)
 if kind=='office' then
  box(im,36,199,27,11,C.paper);R(im,38,202,17,1,C.steel);R(im,38,205,20,1,C.steel)
  B(im,91,283,94,314,C.edge);B(im,94,314,129,314,C.edge)
 elseif kind=='meeting' then
  R(im,38,195,142,3,C.edge);R(im,46,194,11,2,C.blue);R(im,65,194,11,2,C.red)
  for j=0,2 do box(front,190+j*71,255,19,5,C.paper)end
 elseif kind=='cafeteria' then
  box(im,126,193,88,25,C.edge);T(im,134,201,'COFFEE',C.cream)
  for j=0,2 do box(front,290+j*37,254,7,7,C.white);R(front,297+j*37,256,2,3,C.silver)end
 elseif kind=='lounge' then
  -- Upholstery seams and cushion corner shadows, no bed silhouette.
  for j=0,2 do local x=62+j*48;B(im,x+3,257,x+3,277,C.blueDark);B(im,x+5,279,x+39,279,C.blueDark);R(im,x+7,259,2,2,C.silver)end
 elseif kind=='storage' then
  for _,x in ipairs({30,145,428})do for y=190,308,16 do R(im,x+3,y,1,2,C.silver)end end
 end
 source(kind,im,front);save(im,root..'assets/lots/rooms/'..kind..'-16x9-back.png');save(front,root..'assets/lots/rooms/'..kind..'-16x9-front.png')
 local comparison=Image(im)
 for j,id in ipairs({'male','alice'})do local s=app.open(root..'assets/sprites/'..id..'/idle.png');local a=L.image(480,480);a:drawSprite(s,1);s:close();comparison:drawImage(Image(a,Rectangle(0,0,160,160)),Point(240+(j-1)*100,183))end
 comparison:drawImage(front);roomGallery:drawImage(comparison,Point((index-1)%2*640,(index-1)//2*360))
 local metadata={name=kind,view='side_cutaway',ratio='16x9',width=640,height=360,floor_baseline=320,pixel_scale={character_frame={160,160},character_visible_height=114,door_height=146,outline_pixels={1,2}},walkable_floor={4,320,632,3},actor_y=183,exit_anchor={584,320}}
 local file=assert(io.open(root..'assets/lots/rooms/'..kind..'-16x9.json','w'));file:write(json.encode(metadata));file:close()
end
save(roomGallery,out..'all-rooms-with-cast.png')
local manifest={version=3,cell={160,160},frames=6,anchor={80,137},outline_pixels={1,2},instruments=ids}
local file=assert(io.open(root..'assets/instruments/manifest.json','w'));file:write(json.encode(manifest));file:close()
print('Native pixel redraw: 6 rooms, 7 instruments / 42 frames. Sources: '..out)
