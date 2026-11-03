local A={}
local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local C=L.C
A.specs={
 {id='guitar',w=32,h=48,anchor={16,45},held=true},
 {id='drums',w=64,h=64,anchor={32,58},held=false},
 {id='electone',w=64,h=48,anchor={32,45},held=false},
 {id='saxophone',w=32,h=48,anchor={16,45},held=true},
 {id='organ',w=64,h=64,anchor={32,60},held=false},
 {id='mic',w=32,h=48,anchor={16,45},held=false},
 {id='bass',w=32,h=48,anchor={16,45},held=true}
}
function A.render(spec,frame)
 frame=frame or 1;local back=L.image(spec.w,spec.h);local front=L.image(spec.w,spec.h)
 local dx=spec.held and ({0,1,1,0,-1,-1})[frame] or 0;local dy=spec.held and ({0,0,1,0,0,1})[frame] or 0
 local function R(x,y,w,h,c) L.rect(front,x+dx,y+dy,w,h,c) end
 local function E(x,y,w,h,c) L.ellipse(front,x+dx,y+dy,w,h,c) end
 local function B(x,y,a,b,c) L.line(front,x+dx,y+dy,a+dx,b+dy,c) end
 local function P(p,c) local t={};for _,q in ipairs(p) do t[#t+1]={q[1]+dx,q[2]+dy} end;L.poly(front,t,c) end
 if spec.id=='guitar' then
  P({{9,26},{11,24},{14,25},{17,23},{20,25},{21,29},{19,34},{16,37},{10,37},{7,34},{7,30}},C.ink)
  P({{10,27},{12,26},{14,27},{18,25},{19,28},{18,32},{16,35},{10,35},{8,33},{9,29}},C.wood)
  E(9,28,8,7,C.gold);B(10,34,15,34,C.goldHi)
  P({{15,27},{27,16},{29,18},{18,30}},C.ink);P({{16,27},{27,17},{28,18},{17,29}},C.woodHi)
  E(12,28,5,5,C.woodDark);E(13,29,3,3,C.ink)
  P({{25,15},{28,13},{31,16},{28,19}},C.ink);B(27,15,29,17,C.woodHi)
  B(12,34,28,17,C.cream);B(14,34,29,18,C.sand);B(10,33,15,33,C.ink)
  R(25,13,2,1,C.silver);R(29,18,2,1,C.silver)
 elseif spec.id=='bass' then
  P({{9,27},{12,25},{14,27},{17,25},{20,26},{20,31},{18,36},{14,38},{9,36},{8,32}},C.ink)
  P({{10,28},{12,27},{14,29},{18,26},{19,29},{17,34},{14,36},{10,34}},C.red)
  E(10,30,7,5,C.redMid);B(15,28,28,12,C.ink);B(16,29,29,13,C.woodHi)
  B(17,29,30,13,C.cream);R(27,10,3,5,C.woodDark);R(28,10,2,3,C.woodHi)
  R(26,10,1,2,C.silver);R(30,12,1,2,C.silver);B(12,35,29,12,C.silver)
  R(12,30,5,2,C.ink);R(11,34,5,1,C.silver);R(17,34,1,1,C.gold)
 elseif spec.id=='saxophone' then
  P({{14,19},{18,20},{20,23},{20,31},{23,34},{25,30},{29,32},{28,37},{25,40},{20,38},{17,34},{17,25},{15,23}},C.ink)
  B(15,21,18,23,C.goldHi);R(18,23,2,10,C.gold);B(18,33,21,36,C.gold)
  B(21,36,25,37,C.goldHi);E(23,29,8,6,C.goldDark);E(24,29,6,4,C.goldHi);E(25,30,4,2,C.woodDark)
  R(17,25,2,1,C.white);R(17,28,2,1,C.white);R(18,31,2,1,C.cream);R(13,18,3,2,C.ink)
 elseif spec.id=='mic' then
  B(23,21,23,43,C.ink);B(24,22,24,43,C.silver);B(23,43,16,46,C.ink);B(23,43,30,46,C.ink);B(23,43,23,47,C.edge)
  B(23,22,27,18,C.ink);B(27,18,19,14,C.ink);B(27,19,19,15,C.slate)
  P({{15,12},{18,12},{22,15},{21,18},{18,18},{14,15}},C.ink);B(16,13,20,16,C.silver);B(15,14,19,17,C.steel)
  B(29,46,31,42,C.edge)
 elseif spec.id=='drums' then
  L.shadow(front,4,55,56,8)
  -- Rear stool is behind the performer; stands and shells are foreground.
  L.ellipse(back,26,29,13,5,C.ink);L.rect(back,31,32,3,21,C.edge)
  local function stand(x,y,foot)
   L.line(front,x,y,x,foot,C.ink);L.line(front,x+1,y,x+1,foot,C.silver)
   L.line(front,x,foot,x-6,foot+4,C.edge);L.line(front,x,foot,x+6,foot+4,C.edge)
  end
  stand(11,24,51);stand(52,22,49);stand(20,35,54)
  local cy=({0,0,1,0,0,-1})[frame]
  L.ellipse(front,2,22+cy,19,6,C.goldDark);L.ellipse(front,3,21+cy,17,4,C.gold);L.line(front,6,22+cy,17,22+cy,C.goldHi);L.rect(front,10,20+cy,3,2,C.ink)
  L.ellipse(front,43,20-cy,18,6,C.goldDark);L.ellipse(front,44,19-cy,16,4,C.gold);L.rect(front,51,18-cy,3,2,C.ink)
  for _,v in ipairs({{20,27,12,14},{34,28,12,13},{7,38,13,13},{46,37,13,17}}) do
   L.box(front,v[1],v[2],v[3],v[4],C.whiteShade or C.silver,C.red,C.ink)
   L.ellipse(front,v[1],v[2]-1,v[3],5,C.ink);L.ellipse(front,v[1]+1,v[2],v[3]-2,3,C.silver)
   L.line(front,v[1]+2,v[2]+7,v[1]+2,v[2]+v[4]-2,C.redHi);L.rect(front,v[1]+v[3]-3,v[2]+5,1,4,C.steel)
  end
  L.ellipse(front,22,36,24,26,C.ink);L.ellipse(front,24,38,20,22,C.redDark);L.ellipse(front,26,40,16,18,C.cream);L.ellipse(front,28,42,12,14,C.white)
  L.ellipse(front,35,51,4,4,C.ink);L.line(front,24,60,20,63,C.silver);L.line(front,43,59,48,62,C.silver)
  L.line(front,19,32,30,38,C.woodHi);L.line(front,44,31,35,38,C.woodHi)
 elseif spec.id=='electone' or spec.id=='organ' then
  local organ=spec.id=='organ';local top=organ and 31 or 17
  if organ then
   L.box(back,5,6,54,32,C.woodHi,C.woodDark)
   for k=0,8 do local height=({20,25,30,34,37,34,30,25,20})[k+1];local x=9+k*5
    L.rect(back,x,38-height,4,height,C.ink);L.rect(back,x+1,39-height,2,height-2,C.steel);L.line(back,x+1,41-height,x+1,35,C.silver);L.rect(back,x+1,37-height,2,2,C.silver)
   end
  end
  L.shadow(front,3,organ and 57 or 42,58,6)
  L.box(front,4,top,56,organ and 20 or 15,organ and C.woodHi or C.edge,organ and C.woodDark or C.blueDark)
  for manual=0,1 do local ky=top+5+manual*5
   L.rect(front,8,ky,48,4,C.white)
   for k=0,15 do L.rect(front,8+k*3,ky,1,4,C.steel);if k%7~=2 and k%7~=6 then L.rect(front,10+k*3,ky,2,2,C.ink) end end
  end
  L.rect(front,8,top+1,18,2,C.ink);L.rect(front,9,top+1,6,1,C.cyan);L.rect(front,30,top+1,4,1,frame%2==0 and C.greenHi or C.redMid)
  for k=0,4 do L.rect(front,37+k*3,top+1,1,1,C.goldHi) end
  local bottom=organ and 60 or 45
  L.rect(front,7,top+15,4,bottom-top-15,C.woodDark);L.rect(front,53,top+15,4,bottom-top-15,C.woodDark)
  L.line(front,9,bottom,55,bottom,C.ink);L.rect(front,22,bottom-3,21,3,C.ink)
  for k=0,6 do L.rect(front,23+k*3,bottom-3,2,2,C.woodHi) end
 end
 local flat=L.image(spec.w,spec.h);flat:drawImage(back,Point(0,0));flat:drawImage(front,Point(0,0))
 return back,front,flat
end
return A
