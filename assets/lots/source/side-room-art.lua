-- Side-on cutaway rooms: one horizontal walking/foot baseline, matching the game view.
local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local I=dofile(root..'source/instrument-art.lua');local C=L.C
local R,F,B,E,P,T=L.rect,L.frame,L.line,L.ellipse,L.poly,L.text
local A={}
local function plant(im,x,f)
 R(im,x+6,f-24,2,15,C.bark);P(im,{{x+1,f-11},{x+14,f-11},{x+12,f},{x+3,f}},C.ink);P(im,{{x+3,f-10},{x+12,f-10},{x+11,f-1},{x+4,f-1}},C.wood)
 E(im,x-2,f-38,21,22,C.leafDark);E(im,x,f-39,17,17,C.leaf);E(im,x+2,f-37,10,8,C.leafHi)
end
local function chair(im,x,f,color)
 R(im,x+2,f-12,2,12,C.ink);R(im,x+12,f-12,2,12,C.ink)
 R(im,x,f-27,16,17,C.ink);R(im,x+2,f-25,12,12,color or C.blue)
 B(im,x+3,f-24,x+12,f-24,C.blueHi);R(im,x-1,f-13,18,5,C.ink);R(im,x+1,f-12,14,2,color or C.blue)
end
local function desk(im,x,f,w,pc)
 R(im,x+3,f-19,4,19,C.woodDark);R(im,x+w-7,f-19,4,19,C.woodDark)
 R(im,x,f-23,w,7,C.ink);R(im,x+1,f-22,w-2,3,C.woodHi);B(im,x+2,f-22,x+w-3,f-22,C.cream)
 R(im,x+w-20,f-16,16,11,C.wood);B(im,x+w-19,f-11,x+w-5,f-11,C.woodDark);R(im,x+w-13,f-14,4,1,C.ink);R(im,x+w-13,f-8,4,1,C.ink)
 if pc then
  local mx=x+math.floor(w/2)-10
  R(im,mx+8,f-29,4,7,C.ink);R(im,mx+3,f-24,15,2,C.edge)
  R(im,mx,f-41,22,15,C.ink);R(im,mx+2,f-39,18,11,C.screen);R(im,mx+4,f-37,7,2,C.screenHi);R(im,mx+4,f-33,13,1,C.cyan)
  R(im,mx-1,f-23,25,2,C.silver)
 end
 R(im,x+3,f-26,5,4,C.paper);R(im,x+w-9,f-28,5,5,C.white)
end
local function shelf(im,x,f,w,boxes)
 R(im,x,f-57,w,57,C.ink);R(im,x+2,f-55,w-4,53,C.woodDark)
 for row=0,2 do local yy=f-51+row*17
  R(im,x+2,yy+12,w-4,3,C.woodHi)
  if boxes then
   for col=0,1 do local xx=x+4+col*math.floor((w-7)/2);local ww=math.floor((w-9)/2);R(im,xx,yy,ww,12,C.wood);F(im,xx,yy,ww,12,C.sand);R(im,xx+math.floor(ww/2),yy+1,2,8,C.cream) end
  else
   for col=0,math.floor((w-8)/4) do local xx=x+4+col*4;R(im,xx,yy+1+col%3,3,11-col%3,({C.blue,C.redDark,C.gold,C.green,C.purple})[(col+row)%5+1]);R(im,xx+1,yy+4,1,1,C.paper) end
  end
 end
 R(im,x+1,f-56,2,55,C.woodHi)
end
local function sofa(im,x,f,w)
 R(im,x+5,f-4,4,4,C.woodDark);R(im,x+w-9,f-4,4,4,C.woodDark)
 R(im,x,f-33,w,29,C.ink);R(im,x+2,f-31,w-4,15,C.purple);R(im,x+4,f-30,w-8,4,C.pink)
 R(im,x+5,f-16,w-10,9,C.pink);B(im,x+5,f-8,x+w-6,f-8,C.purple)
 R(im,x+1,f-23,5,19,C.purple);R(im,x+w-6,f-23,5,19,C.purple)
 B(im,x+math.floor(w/2),f-30,x+math.floor(w/2),f-17,C.ink)
 R(im,x+10,f-26,11,10,C.cream);R(im,x+11,f-25,8,2,C.paper)
end
local function bed(im,x,f,w)
 R(im,x,f-36,6,36,C.woodDark);R(im,x+w-5,f-25,5,25,C.woodDark)
 R(im,x+4,f-25,w-7,19,C.ink);R(im,x+5,f-24,w-9,5,C.white)
 R(im,x+6,f-19,w-10,11,C.blue);R(im,x+7,f-18,w-12,3,C.blueHi)
 R(im,x+5,f-7,w-8,4,C.wood);R(im,x+7,f-3,3,3,C.woodDark);R(im,x+w-11,f-3,3,3,C.woodDark)
 E(im,x+8,f-31,18,8,C.paper);B(im,x+28,f-23,x+28,f-9,C.blueDark)
end
local function cabinet(im,x,f,w,h)
 R(im,x,f-h,w,h,C.ink);R(im,x+1,f-h+1,w-2,h-2,C.slate);R(im,x+1,f-h+1,w-2,3,C.silver)
 for y=f-h+10,f-4,11 do B(im,x+2,y,x+w-3,y,C.edge);R(im,x+math.floor(w/2)-3,y+3,6,1,C.ink) end
end
local function crate(im,x,f,w,h)
 R(im,x,f-h,w,h,C.ink);R(im,x+1,f-h+1,w-2,h-2,C.wood);F(im,x+2,f-h+2,w-4,h-4,C.sand)
 B(im,x+3,f-h+3,x+w-4,f-4,C.cream);B(im,x+w-4,f-h+3,x+3,f-4,C.woodDark)
end
local function instrument(im,name,x,f)
 for _,spec in ipairs(I.specs) do if spec.id==name then local _,_,flat=I.render(spec,1);im:drawImage(flat,Point(x,f-spec.anchor[2]));return end end
end
function A.render(kind,w,h)
 local baseline=h-16
 local wall=L.image(w,h);local fixtures=L.image(w,h);local back=L.image(w,h);local structure=L.image(w,h);local fore=L.image(w,h)
 local fill=({recording=C.redDark,lounge=L.color('70617d'),office=L.color('47647e'),meeting=C.wallLight,cafeteria=L.color('8ca498'),storage=C.wallDark})[kind]
 R(wall,4,10,w-8,baseline-10,fill);R(wall,4,20,w-8,2,kind=='recording' and C.red or C.wallDark)
 if kind=='recording' then
  for x=7,w-12,10 do for y=25,baseline-9,12 do R(wall,x,y,7,9,C.red);B(wall,x+1,y+1,x+5,y+1,C.redMid);B(wall,x+1,y+1,x+1,y+7,C.redMid);B(wall,x+2,y+7,x+5,y+7,C.redDark) end end
 else
  B(wall,5,baseline-9,w-6,baseline-9,kind=='office' and C.blueDark or C.wallDark)
 end
 -- Ground is one horizontal line, not a top-down floor plane.
 R(structure,0,0,w,10,C.edge);R(structure,0,1,w,3,C.slate);R(structure,0,9,w,2,C.ink)
 R(structure,0,10,4,h-10,C.ink);R(structure,w-4,10,4,h-10,C.ink)
 R(structure,4,baseline,w-8,3,C.ink);R(structure,4,baseline+3,w-8,9,C.woodDark);B(structure,5,baseline+3,w-6,baseline+3,C.woodHi)
 R(structure,0,h-4,w,4,C.ink)
 local doorX=w-31;R(fixtures,doorX,baseline-57,25,57,C.ink);R(fixtures,doorX+2,baseline-55,21,54,C.woodDark);R(fixtures,doorX+4,baseline-53,17,50,C.wood)
 R(fixtures,doorX+5,baseline-51,15,11,C.screen);R(fixtures,doorX+6,baseline-50,13,1,C.screenHi);R(fixtures,doorX+18,baseline-27,2,2,C.gold)
 R(fixtures,doorX-1,baseline-1,27,2,C.silver)
 local labels={recording='REC STUDIO',lounge='LOUNGE',office='OFFICE',meeting='MEETING',cafeteria='CAFE',storage='STORAGE'}
 local title=labels[kind];R(fixtures,8,25,#title*6+7,13,C.edge);T(fixtures,12,28,title,C.white)
 if kind~='storage' then
  local wx=w>=240 and 94 or 73;local wy=43;local ww=math.min(46,w-40-wx)
  if ww>=30 then
   R(fixtures,wx,wy,ww,29,C.ink);R(fixtures,wx+2,wy+2,ww-4,25,kind=='recording' and C.screen or C.sky)
   for k=0,3 do local bh=7+k*4%17;R(fixtures,wx+4+k*9,wy+26-bh,6,bh,kind=='recording' and C.slate or C.cityFar) end
   B(fixtures,wx+math.floor(ww/2),wy+2,wx+math.floor(ww/2),wy+26,C.steel);B(fixtures,wx+3,wy+3,wx+ww-4,wy+3,C.white)
  end
 end
 local footprints={}
 local function footprint(x,width,height) footprints[#footprints+1]={x,baseline-height,width,height} end
 if kind=='recording' then
  local cw=w>=240 and 75 or 55
  desk(back,10,baseline,cw,false);R(back,13,baseline-25,cw-6,12,C.ink)
  for k=0,math.floor((cw-12)/5) do local xx=16+k*5;B(back,xx,baseline-23,xx,baseline-15,C.slate);R(back,xx-1,baseline-21+k%3,3,2,C.silver);R(back,xx,baseline-24,1,1,k%3==0 and C.redHi or C.cyan) end
  R(back,15,baseline-38,18,11,C.ink);R(back,17,baseline-36,14,7,C.screen);for k=0,3 do R(back,19+k*3,baseline-34+k%2,1,4,C.lime) end
  R(back,10,baseline-52,12,15,C.ink);E(back,12,baseline-50,8,8,C.slate);E(back,14,baseline-48,4,4,C.ink)
  instrument(back,'mic',w>=240 and 91 or 65,baseline)
  if w>=240 then instrument(back,'drums',w-105,baseline-5) else instrument(back,'guitar',w-75,baseline);B(back,w-60,baseline-12,w-68,baseline,C.edge);B(back,w-60,baseline-12,w-53,baseline,C.edge) end
  R(fixtures,w-78,baseline-77,41,13,C.purple);T(fixtures,w-74,baseline-74,'ON AIR',C.pink)
  footprint(10,cw,30)
 elseif kind=='lounge' then
  sofa(back,10,baseline,64);R(fixtures,15,47,45,28,C.ink);R(fixtures,17,49,41,23,C.blueDark);B(fixtures,19,69,53,52,C.blue)
  desk(back,82,baseline,27,false)
  if w>=240 then bed(back,w-112,baseline,70);footprint(w-112,70,36) elseif w>=192 then cabinet(back,w-63,baseline,23,49) end
  R(back,85,baseline-33,12,2,C.paper);E(back,96,baseline-36,5,5,C.white)
  footprint(10,64,33)
 elseif kind=='office' then
  desk(back,10,baseline,44,true);desk(back,w-92,baseline,43,true)
  if w>=240 then shelf(back,70,baseline,31,false) end
  E(fixtures,w-55,30,15,15,C.ink);E(fixtures,w-53,32,11,11,C.paper);B(fixtures,w-48,37,w-48,33,C.edge);B(fixtures,w-48,37,w-45,39,C.edge)
  footprint(10,44,30);footprint(w-92,43,30)
 elseif kind=='meeting' then
  local tx=math.floor((w-40)/2)-32;local tw=w>=240 and 94 or 72
  R(fixtures,11,46,62,35,C.ink);R(fixtures,13,48,58,31,C.paper);B(fixtures,17,71,30,58,C.blue);B(fixtures,30,58,43,66,C.blue);B(fixtures,43,66,65,53,C.blue)
  chair(back,tx+7,baseline,C.blueDark);chair(back,tx+tw-23,baseline,C.blueDark)
  desk(fore,tx,baseline,tw,false);R(fore,tx+math.floor(tw/2)-10,baseline-36,22,13,C.ink);R(fore,tx+math.floor(tw/2)-8,baseline-34,18,8,C.screen);R(fore,tx+math.floor(tw/2)-11,baseline-23,26,2,C.silver)
  if w>=240 then plant(back,w-59,baseline) end
  footprint(tx,tw,30)
 elseif kind=='cafeteria' then
  local cw=w>=240 and 79 or 55
  R(back,10,baseline-33,cw,33,C.ink);R(back,12,baseline-31,cw-4,5,C.silver);R(back,12,baseline-25,cw-4,24,C.greenDark);R(back,12,baseline-24,cw-4,2,C.green)
  for k=0,math.floor((cw-13)/15) do E(back,16+k*15,baseline-38,12,5,C.ink);E(back,17+k*15,baseline-38,10,3,C.cream);R(back,20+k*15,baseline-39,3,2,C.gold) end
  R(back,15,baseline-51,15,14,C.edge);R(back,17,baseline-49,11,8,C.screen);R(back,17,baseline-39,11,2,C.black)
  local tx=w>=240 and 110 or 78;chair(back,tx+6,baseline,C.redDark);desk(fore,tx,baseline,36,false)
  if w>=192 then
   local vx=w-61;R(back,vx,baseline-53,24,53,C.ink);R(back,vx+1,baseline-52,22,51,C.redDark);R(back,vx+4,baseline-48,12,30,C.screen)
   for y=0,2 do for x=0,1 do R(back,vx+5+x*5,baseline-45+y*8,3,6,x==0 and C.gold or C.cyan) end end
   R(back,vx+4,baseline-11,15,6,C.ink);R(back,vx+18,baseline-35,3,12,C.gold)
  end
  footprint(10,cw,33)
 elseif kind=='storage' then
  shelf(back,10,baseline,31,true);shelf(back,49,baseline,31,true)
  if w>=240 then shelf(back,w-76,baseline,33,true) end
  local x=w>=240 and 101 or 87;crate(back,x,baseline,23,22);crate(back,x+3,baseline-22,18,18)
  if w>=192 then crate(back,x+24,baseline,17,17) end
  R(fixtures,12,46,59,12,C.goldDark);T(fixtures,16,49,'KEEP DRY',C.cream)
  footprint(10,70,57);footprint(x,23,40)
 end
 return {{name='Back wall - side cutaway',image=wall},{name='Windows signs and door',image=fixtures},{name='Furniture BEHIND actors',image=back},{name='Floor and building structure',image=structure},{name='Furniture IN FRONT of actors',image=fore}},footprints
end
return A
