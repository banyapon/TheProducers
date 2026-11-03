local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local I=dofile(root..'source/instrument-art.lua');local C=L.C
local A={}
local R,F,B,E,P,T=L.rect,L.frame,L.line,L.ellipse,L.poly,L.text
local function plant(im,x,y)
 L.shadow(im,x-6,y+23,23,5);L.box(im,x,y+15,13,12,C.sand,C.woodDark);R(im,x+2,y+17,9,2,C.woodHi)
 B(im,x+6,y+17,x+7,y-6,C.bark);P(im,{{x+6,y+8},{x-4,y+2},{x-3,y-2},{x+5,y+2}},C.leafDark)
 P(im,{{x+6,y+9},{x+16,y+2},{x+17,y-2},{x+8,y+2}},C.leaf)
 E(im,x-1,y-9,16,13,C.leafDark);E(im,x+1,y-11,13,10,C.leaf);E(im,x+2,y-10,7,5,C.leafHi)
end
local function chair(im,x,y,color)
 L.shadow(im,x-2,y+21,21,5);R(im,x+2,y+10,2,14,C.ink);R(im,x+12,y+10,2,14,C.ink)
 R(im,x,y,16,12,C.ink);R(im,x+2,y+1,12,9,color or C.blue);B(im,x+3,y+2,x+12,y+2,C.blueHi)
 R(im,x-1,y+11,18,7,C.ink);R(im,x+1,y+11,14,4,color or C.blue);B(im,x+1,y+15,x+14,y+15,C.blueDark)
end
local function desk(im,x,y,w,computer)
 L.shadow(im,x-3,y+28,w+7,7);R(im,x+3,y+13,4,20,C.woodDark);R(im,x+w-7,y+13,4,20,C.woodDark)
 L.box(im,x,y,w,18,C.woodHi,C.woodDark);B(im,x+1,y+1,x+w-2,y+1,C.cream)
 if computer then
  local mx=x+math.floor(w/2)-11
  R(im,mx+8,y-5,5,10,C.edge);R(im,mx+2,y+4,19,3,C.ink)
  R(im,mx,y-16,24,17,C.ink);R(im,mx+2,y-14,20,12,C.screen);R(im,mx+4,y-12,9,2,C.screenHi);R(im,mx+4,y-8,15,1,C.cyan)
  R(im,mx-3,y+9,29,5,C.ink);R(im,mx-2,y+9,27,3,C.silver)
  for k=0,7 do R(im,mx+k*3,y+10,1,1,C.edge) end
  E(im,mx+29,y+8,4,5,C.white)
 end
 R(im,x+5,y+7,9,5,C.paper);B(im,x+6,y+9,x+11,y+9,C.slate)
 R(im,x+w-11,y+3,5,7,C.ink);R(im,x+w-10,y+3,3,5,C.white);B(im,x+w-6,y+4,x+w-5,y+6,C.silver)
end
local function console(im,x,y)
 L.shadow(im,x-2,y+28,100,6);L.box(im,x,y,96,28,C.slate,C.edge)
 R(im,x+3,y+3,90,17,C.ink);R(im,x+6,y+5,20,12,C.screen)
 for k=0,3 do R(im,x+8+k*4,y+7+(k%2),2,7-k%3,C.lime) end
 for k=0,10 do local xx=x+31+k*5;B(im,xx,y+5,xx,y+17,C.slate);R(im,xx-1,y+8+(k%3)*2,3,2,C.silver);R(im,xx,y+4,1,1,k%3==0 and C.redMid or C.cyan) end
 B(im,x+3,y+23,x+92,y+23,C.steel);R(im,x+6,y+24,7,2,C.black)
end
local function speaker(im,x,y)
 L.shadow(im,x-2,y+30,20,5);L.box(im,x,y,16,32,C.edge,C.ink)
 E(im,x+2,y+6,12,12,C.slate);E(im,x+4,y+8,8,8,C.ink);E(im,x+6,y+10,4,4,C.steel)
 E(im,x+5,y+23,6,6,C.slate);R(im,x+12,y+29,1,1,C.greenHi)
end
local function shelf(im,x,y,w,boxes)
 L.shadow(im,x-2,y+52,w+5,5);R(im,x,y,w,54,C.ink);R(im,x+2,y+2,w-4,50,C.woodDark)
 for level=0,2 do local yy=y+5+level*16
  R(im,x+2,yy+12,w-4,3,C.woodHi);B(im,x+2,yy+12,x+w-3,yy+12,C.sand)
  if boxes then
   for k=0,1 do local xx=x+5+k*math.floor((w-8)/2);L.box(im,xx,yy,math.floor((w-11)/2),12,C.woodHi,C.wood);R(im,xx+4,yy+3,3,5,C.cream) end
  else
   for k=0,math.floor((w-7)/5) do local xx=x+4+k*5;R(im,xx,yy+2+k%2,4,10-k%2,({C.redDark,C.blue,C.greenDark,C.goldDark,C.purple})[(k+level)%5+1]);R(im,xx+1,yy+4,2,1,C.paper) end
  end
 end
 R(im,x+1,y+1,2,52,C.woodHi);R(im,x+w-3,y+1,2,52,C.woodHi)
end
local function cabinet(im,x,y,w,h)
 L.shadow(im,x-2,y+h-2,w+5,5);L.box(im,x,y,w,h,C.silver,C.slate)
 for yy=y+12,y+h-5,12 do B(im,x+2,yy,x+w-3,yy,C.edge);R(im,x+math.floor(w/2)-3,yy+3,7,2,C.ink) end
 R(im,x+2,y+h-1,3,3,C.ink);R(im,x+w-5,y+h-1,3,3,C.ink)
end
local function rug(im,x,y,w,h,theme)
 R(im,x,y,w,h,C.ink);R(im,x+1,y+1,w-2,h-2,theme or C.blueDark);F(im,x+4,y+4,w-8,h-8,C.slate)
 for xx=x+8,x+w-9,12 do R(im,xx,y+7,3,2,C.steel);R(im,xx,y+h-9,3,2,C.steel) end
end
local function sofa(im,x,y,w)
 L.shadow(im,x-3,y+31,w+6,7);R(im,x+6,y+28,4,7,C.woodDark);R(im,x+w-10,y+28,4,7,C.woodDark)
 L.box(im,x,y,w,29,C.green,C.greenDark);R(im,x+5,y+3,w-10,12,C.leaf)
 for xx=x+8,x+w-12,24 do B(im,xx,y+4,xx,y+13,C.greenDark) end
 R(im,x+7,y+17,w-14,8,C.greenHi);B(im,x+8,y+18,x+w-9,y+18,C.lime)
 R(im,x+2,y+11,5,19,C.green);R(im,x+w-7,y+11,5,19,C.green)
 R(im,x+12,y+6,13,9,C.cream);R(im,x+13,y+7,11,2,C.paper)
end
local function bed(im,x,y)
 L.shadow(im,x-3,y+63,48,7);L.box(im,x,y,44,66,C.woodHi,C.woodDark)
 R(im,x+3,y+3,38,58,C.white);R(im,x+5,y+5,34,13,C.cream);R(im,x+8,y+7,28,8,C.paper)
 R(im,x+3,y+22,38,38,C.blue);R(im,x+5,y+24,34,5,C.blueHi)
 B(im,x+24,y+29,x+24,y+58,C.blueDark);R(im,x+3,y+57,38,4,C.blueDark)
 R(im,x+2,y-3,40,7,C.woodDark);B(im,x+3,y-2,x+40,y-2,C.woodHi)
end
local function tableTop(im,x,y,w,h)
 L.shadow(im,x-3,y+h+10,w+7,7);R(im,x+5,y+h-4,4,18,C.woodDark);R(im,x+w-9,y+h-4,4,18,C.woodDark)
 L.box(im,x,y,w,h,C.woodHi,C.woodDark);B(im,x+2,y+1,x+w-3,y+1,C.cream)
end
local function vending(im,x,y)
 L.shadow(im,x-2,y+53,29,5);L.box(im,x,y,26,56,C.redMid,C.redDark)
 R(im,x+3,y+5,15,32,C.ink);R(im,x+4,y+6,13,28,C.screen)
 for row=0,2 do for k=0,2 do R(im,x+5+k*4,y+8+row*8,3,5,({C.gold,C.redHi,C.cyan})[k+1]) end end
 R(im,x+20,y+14,3,13,C.gold);R(im,x+20,y+16,2,2,C.white)
 R(im,x+4,y+43,17,7,C.ink);B(im,x+3,y+3,x+22,y+3,C.redHi)
end
local function crate(im,x,y,size)
 L.box(im,x,y,size,size,C.woodHi,C.wood);F(im,x+2,y+2,size-4,size-4,C.woodDark)
 B(im,x+2,y+2,x+size-3,y+size-3,C.cream);B(im,x+size-3,y+2,x+2,y+size-3,C.woodDark)
 R(im,x+math.floor(size/2)-1,y+2,2,size-4,C.sand)
end
local function instrument(im,id,x,y)
 for _,s in ipairs(I.specs) do if s.id==id then local _,_,flat=I.render(s,1);im:drawImage(flat,Point(x,y));return end end
end
function A.render(kind,w,h)
 local floor=L.image(w,h);local walls=L.image(w,h);local back=L.image(w,h);local front=L.image(w,h);local detail=L.image(w,h)
 local collisions={};local objects={}
 local function add(y,fn,bounds) objects[#objects+1]={y=y,fn=fn};if bounds then collisions[#collisions+1]=bounds end end
 local wood=kind=='recording' or kind=='lounge' or kind=='meeting'
 R(floor,8,8,w-16,h-16,C.ink);R(floor,12,76,w-24,h-88,wood and C.floorWood or(kind=='cafeteria' and C.tile or(kind=='storage' and C.concrete or C.carpet)))
 for yy=80,h-14,wood and 8 or 16 do
  if wood then
   B(floor,12,yy,w-13,yy,C.floorWoodDark)
   for xx=12+((math.floor(yy/8)%2)*12),w-14,24 do
    B(floor,xx,yy,xx,yy+7,C.floorWoodDark);B(floor,xx+3,yy+2,math.min(xx+18,w-14),yy+2,C.floorWoodHi)
   end
  else
   B(floor,12,yy,w-13,yy,kind=='cafeteria' and C.tileLine or C.wallDark)
   for xx=12,w-14,16 do B(floor,xx,yy,xx,yy+15,kind=='cafeteria' and C.tileLine or C.wallDark);R(floor,xx+2,yy+2,13,1,kind=='cafeteria' and C.tileHi or(kind=='storage' and C.concreteHi or C.carpetHi)) end
  end
 end
 local wc=kind=='recording' and C.redDark or(kind=='lounge' and C.cream or(kind=='office' and C.wall or(kind=='meeting' and C.wallLight or(kind=='cafeteria' and C.sand or C.wallDark))))
 R(walls,12,12,w-24,65,wc);R(walls,12,12,w-24,3,C.wallLight);R(walls,12,73,w-24,8,kind=='recording' and C.red or C.edge);B(walls,12,79,w-13,79,C.ink)
 R(walls,8,12,4,h-24,C.edge);R(walls,w-12,12,4,h-24,C.edge);R(walls,12,h-12,w-24,4,C.edge)
 if kind=='recording' then
  for xx=17,w-20,12 do for yy=19,67,12 do R(walls,xx,yy,9,9,C.red);B(walls,xx+1,yy+1,xx+7,yy+1,C.redMid);B(walls,xx+1,yy+1,xx+1,yy+7,C.redMid);B(walls,xx+2,yy+7,xx+7,yy+7,C.redDark) end end
 else
  B(walls,13,60,w-14,60,C.wallDark)
  for xx=28,w-20,96 do R(walls,xx,21,24,4,C.edge);R(walls,xx+2,22,20,2,C.white);R(walls,xx+4,25,16,1,C.cream) end
 end
 -- Door is 54 pixels high against a 42-pixel-tall person.
 local doorX=w-53;R(walls,doorX,25,29,54,C.ink);R(walls,doorX+2,27,25,50,C.woodDark);R(walls,doorX+4,29,21,44,C.wood);R(walls,doorX+5,30,19,1,C.woodHi);R(walls,doorX+21,54,2,2,C.gold)
 R(walls,doorX+7,34,14,9,C.screen);R(walls,doorX+8,35,12,1,C.screenHi);R(walls,doorX-2,77,33,4,C.silver)
 local titles={recording='REC STUDIO',lounge='REST',office='OFFICE',meeting='MEETING',cafeteria='CAFE',storage='STORAGE'}
 local title=titles[kind];R(walls,17,30,#title*6+9,15,C.edge);T(walls,22,34,title,C.white)
 -- Windows or recording-booth glazing.
 if kind~='storage' then local wx=math.floor(w/2)-39
  R(walls,wx,27,78,37,C.ink);R(walls,wx+3,30,72,31,kind=='recording' and C.screen or C.sky)
  for k=0,5 do local bx=wx+7+k*11;local bh=8+(k*7)%18;R(walls,bx,61-bh,8,bh,kind=='recording' and C.slate or C.cityFar) end
  B(walls,wx+4,31,wx+70,31,C.white);B(walls,wx+39,29,wx+39,62,C.steel);B(walls,wx+3,61,wx+74,61,C.steel)
 end
 if kind=='recording' then
  add(119,function(im) console(im,29,96);speaker(im,11,83);speaker(im,129,83) end,{29,105,96,19})
  add(149,function(im) chair(im,68,132,C.red) end,{68,143,16,14})
  rug(back,math.floor(w/2)-32,math.floor(h*.54),76,58,C.redDark)
  add(math.floor(h*.54)+44,function(im) instrument(im,'mic',math.floor(w/2)-8,math.floor(h*.54)-1) end)
  add(h-24,function(im) instrument(im,'drums',w-101,h-87) end,{w-95,h-48,55,24})
  add(142,function(im) instrument(im,'electone',w-138,95) end,{w-133,115,56,28})
  add(h-33,function(im) instrument(im,'guitar',28,h-80);B(im,42,h-44,36,h-30,C.edge);B(im,42,h-44,49,h-30,C.edge) end)
  B(back,math.floor(w/2)+16,math.floor(h*.54)+40,math.floor(w/2)+22,h-34,C.ink);B(back,math.floor(w/2)+22,h-34,70,h-34,C.ink);B(back,70,h-34,70,128,C.ink)
  add(108,function(im) R(im,180,88,26,18,C.ink);R(im,182,90,22,12,C.screen);for k=0,8 do R(im,184+k*2,95-(k%3),1,6,C.lime) end end)
 elseif kind=='lounge' then
  rug(back,28,118,142,90,C.greenDark)
  add(146,function(im) sofa(im,30,111,104) end,{30,127,104,21})
  add(205,function(im) tableTop(im,61,177,65,18);R(im,68,181,20,6,C.paper);R(im,103,179,6,6,C.white);E(im,105,180,3,2,C.woodDark) end,{61,182,65,23})
  add(174,function(im) bed(im,w-100,96) end,{w-100,112,44,54})
  add(191,function(im) L.box(im,w-126,163,21,23,C.woodHi,C.woodDark);R(im,w-121,153,4,12,C.goldDark);E(im,w-128,148,19,10,C.cream) end,{w-126,171,21,23})
  add(113,function(im) cabinet(im,20,85,26,30) end)
  R(walls,34,48,49,26,C.ink);R(walls,37,51,43,18,C.blueDark);B(walls,39,67,74,54,C.blue)
  add(h-26,function(im) plant(im,w-41,h-53) end,{w-41,h-36,13,12})
  add(h-22,function(im) L.ellipse(im,30,h-51,26,26,C.goldDark);L.ellipse(im,32,h-53,22,23,C.gold);L.ellipse(im,36,h-51,14,10,C.goldHi) end)
 elseif kind=='office' then
  add(142,function(im) desk(im,74,103,70,true);chair(im,97,139,C.blue) end,{74,110,70,45})
  add(142,function(im) desk(im,w-130,103,70,true);chair(im,w-108,139,C.blue) end,{w-130,110,70,45})
  if w>=384 then add(h-35,function(im) desk(im,math.floor(w/2)-34,h-85,70,true);chair(im,math.floor(w/2)-12,h-49,C.blue) end,{math.floor(w/2)-34,h-78,70,45}) end
  add(139,function(im) shelf(im,20,86,35,false) end,{20,121,35,21})
  add(152,function(im) cabinet(im,w-48,101,25,50) end,{w-48,132,25,22})
  add(h-24,function(im) plant(im,33,h-51) end)
  E(walls,w-87,29,18,18,C.ink);E(walls,w-85,31,14,14,C.paper);B(walls,w-78,38,w-78,33,C.edge);B(walls,w-78,38,w-73,40,C.edge)
 elseif kind=='meeting' then
  R(walls,math.floor(w/2)-50,28,100,40,C.ink);R(walls,math.floor(w/2)-47,31,94,34,C.paper)
  B(walls,math.floor(w/2)-37,56,math.floor(w/2)-15,40,C.blue);B(walls,math.floor(w/2)-15,40,math.floor(w/2)+8,49,C.blue);B(walls,math.floor(w/2)+8,49,math.floor(w/2)+35,36,C.blue)
  local tx=math.floor(w/2)-60;local ty=math.floor(h*.49)
  for k=0,2 do local cx=tx+12+k*37;add(ty-5,function(im) chair(im,cx,ty-28,C.blueDark) end,{cx,ty-17,16,14}) end
  add(ty+43,function(im) tableTop(im,tx,ty,120,37);R(im,tx+48,ty+9,25,14,C.ink);R(im,tx+50,ty+10,21,9,C.screen);R(im,tx+51,ty+22,24,4,C.silver);R(im,tx+8,ty+9,18,8,C.paper);R(im,tx+94,ty+12,6,6,C.white) end,{tx,ty+4,120,43})
  for k=0,2 do local cx=tx+12+k*37;add(ty+68,function(im) chair(im,cx,ty+46,C.blueDark) end,{cx,ty+57,16,14}) end
  add(126,function(im) L.box(im,26,101,40,28,C.woodHi,C.woodDark);R(im,32,93,11,10,C.edge);R(im,34,95,7,5,C.silver);R(im,49,98,5,6,C.white) end,{26,109,40,20})
  add(h-25,function(im) plant(im,w-42,h-52) end)
 elseif kind=='cafeteria' then
  add(132,function(im)
   L.box(im,27,98,w-111,31,C.silver,C.greenDark)
   for x=38,w-100,37 do E(im,x,101,24,9,C.ink);E(im,x+2,102,20,6,C.cream);R(im,x+5,103,5,3,C.gold);R(im,x+13,104,4,2,C.green) end
   R(im,37,87,20,13,C.edge);R(im,40,89,14,7,C.screen);R(im,40,96,14,2,C.black)
  end,{27,110,w-111,23})
  add(147,function(im) vending(im,w-57,91) end,{w-57,125,26,24})
  local ty=166
  for k=0,1 do local tx=k==0 and 42 or w-112
   add(ty+39,function(im) tableTop(im,tx,ty,66,21);E(im,tx+9,ty+4,15,8,C.white);E(im,tx+43,ty+4,15,8,C.white);R(im,tx+31,ty+3,4,8,C.red) end,{tx,ty+5,66,33})
   add(ty-1,function(im) chair(im,tx+24,ty-27,C.redDark) end)
   add(ty+56,function(im) chair(im,tx+24,ty+34,C.redDark) end)
  end
  if w>=384 then add(h-29,function(im) tableTop(im,math.floor(w/2)-27,h-65,54,19);E(im,math.floor(w/2)-7,h-61,14,7,C.white) end,{math.floor(w/2)-27,h-60,54,27}) end
  add(h-25,function(im) L.box(im,18,h-51,15,26,C.steel,C.edge);E(im,18,h-53,15,6,C.ink);E(im,20,h-52,11,3,C.slate) end)
 elseif kind=='storage' then
  add(144,function(im) shelf(im,23,87,40,true);shelf(im,83,87,40,true);shelf(im,w-75,87,40,true) end,{23,122,100,22})
  local cx=math.floor(w/2)-30
  add(193,function(im) crate(im,cx,168,26);crate(im,cx+28,168,22);crate(im,cx+11,148,22) end,{cx,175,50,21})
  add(h-28,function(im) crate(im,29,h-57,24);crate(im,55,h-53,20);crate(im,41,h-76,20) end,{29,h-48,46,22})
  add(h-26,function(im) L.box(im,w-91,h-64,48,27,C.slate,C.edge);R(im,w-90,h-73,2,15,C.silver);B(im,w-90,h-73,w-56,h-73,C.silver);E(im,w-87,h-36,8,8,C.ink);E(im,w-53,h-36,8,8,C.ink);crate(im,w-87,h-84,23) end,{w-91,h-50,48,24})
  add(157,function(im) instrument(im,'bass',w-116,113) end)
  R(walls,math.floor(w/2)-25,28,50,43,C.ink);R(walls,math.floor(w/2)-23,30,46,39,C.slate)
  for yy=33,66,6 do B(walls,math.floor(w/2)-22,yy,math.floor(w/2)+22,yy,C.steel) end
  R(walls,math.floor(w/2)-5,64,10,2,C.ink)
 end
 table.sort(objects,function(a,b) return a.y<b.y end)
 for _,object in ipairs(objects) do object.fn(front) end
 -- Exit threshold stays free; it is a useful consistent placement reference.
 R(detail,math.floor(w/2)-17,h-13,34,2,C.silver);R(detail,math.floor(w/2)-15,h-11,30,1,C.white)
 return {{name='Floor - 16px grid',image=floor},{name='Walls doors windows',image=walls},{name='Rugs and floor cables',image=back},{name='Furniture and equipment',image=front},{name='Details and doorway',image=detail}},collisions
end
return A
