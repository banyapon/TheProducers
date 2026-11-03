local root='D:/EP45/ndlp/Producers/lots/'
local L=dofile(root..'source/pixel-lib.lua');local C=L.C;local A={}
A.trees={{id='broadleaf',w=56,h=72,anchor={28,69}},{id='pine',w=48,h=80,anchor={24,77}},{id='palm',w=72,h=88,anchor={37,85}}}
function A.tree(spec)
 local im=L.image(spec.w,spec.h)
 if spec.id=='broadleaf' then
  L.poly(im,{{25,30},{32,29},{32,60},{36,69},{28,70},{21,69},{25,61}},C.ink)
  L.poly(im,{{27,32},{30,32},{30,62},{33,68},{25,68},{27,60}},C.bark);L.line(im,28,42,28,65,C.barkHi)
  L.line(im,27,47,15,32,C.bark);L.line(im,29,43,40,30,C.bark)
  local clusters={{7,12,28,29},{23,8,27,30},{1,24,27,24},{18,23,33,26},{10,3,28,28},{36,22,18,21}}
  for _,p in ipairs(clusters) do L.ellipse(im,p[1],p[2],p[3],p[4],C.ink);L.ellipse(im,p[1]+1,p[2]+1,p[3]-2,p[4]-3,C.leafDark) end
  L.ellipse(im,6,14,26,23,C.leaf);L.ellipse(im,19,7,26,26,C.leaf);L.ellipse(im,21,26,29,18,C.leafMid)
  L.ellipse(im,12,5,24,17,C.leafMid);L.ellipse(im,10,14,13,8,C.leafHi);L.ellipse(im,25,9,13,7,C.leafHi);L.ellipse(im,33,27,10,6,C.leafHi)
  for _,p in ipairs({{8,34},{16,27},{25,35},{41,36},{11,22},{29,20}}) do L.rect(im,p[1],p[2],3,2,C.leafDark) end
 elseif spec.id=='pine' then
  L.rect(im,21,49,7,29,C.ink);L.rect(im,23,51,3,25,C.bark);L.line(im,23,58,23,74,C.barkHi)
  for _,v in ipairs({{4,39,41,31},{8,24,33,29},{13,10,24,30},{18,2,14,24}}) do
   L.poly(im,{{24,v[2]},{v[1]+v[3],v[2]+v[4]},{v[1],v[2]+v[4]}},C.ink)
   L.poly(im,{{24,v[2]+3},{v[1]+v[3]-3,v[2]+v[4]-2},{v[1]+3,v[2]+v[4]-2}},C.leafDark)
   L.poly(im,{{24,v[2]+4},{24,v[2]+v[4]-3},{v[1]+5,v[2]+v[4]-3}},C.leaf)
   L.line(im,24,v[2]+7,v[1]+7,v[2]+v[4]-4,C.leafMid)
  end
  L.rect(im,17,57,4,2,C.leafHi);L.rect(im,19,39,3,2,C.leafHi);L.rect(im,21,23,2,2,C.leafHi)
 elseif spec.id=='palm' then
  L.poly(im,{{31,25},{38,25},{36,50},{38,70},{43,85},{34,85},{31,68},{30,50}},C.ink)
  L.poly(im,{{33,27},{36,27},{34,50},{35,68},{40,84},{36,84},{33,68},{32,50}},C.bark)
  for y=36,77,7 do L.line(im,32,y,36,y+2,C.barkHi) end
  local fronds={{{34,28},{19,14},{7,15},{2,25},{12,20},{20,22}},{{34,26},{23,6},{13,4},{11,12},{22,13}},{{34,27},{39,5},{49,1},{57,4},{45,9},{39,21}},{{35,29},{54,13},{65,15},{71,25},{58,20},{45,25}},{{35,29},{56,29},{66,39},{66,51},{58,40},{48,36}},{{33,29},{17,31},{7,44},{5,54},{3,42},{11,32},{24,25}}}
  for _,p in ipairs(fronds) do L.poly(im,p,C.ink);local q={};for _,v in ipairs(p) do q[#q+1]={v[1],v[2]+1} end;L.poly(im,q,C.leafDark) end
  L.line(im,33,27,16,12,C.leafMid);L.line(im,16,12,13,7,C.leafHi);L.line(im,34,27,45,7,C.leafMid);L.line(im,45,7,53,4,C.leafHi)
  L.line(im,34,29,56,17,C.leafMid);L.line(im,56,17,65,20,C.leafHi);L.line(im,34,30,53,33,C.leafMid);L.line(im,53,33,63,44,C.leafHi)
  L.line(im,32,29,16,34,C.leafMid);L.line(im,16,34,8,46,C.leafHi)
  L.ellipse(im,30,26,7,7,C.woodDark);L.ellipse(im,36,29,5,6,C.bark)
 end
 return im
end
local function png(im,path) local s=Sprite(im.width,im.height,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(path..'.png');s:close() end
function A.build()
 local comparison=L.image(320,128);L.rect(comparison,0,0,320,128,C.sky)
 local source=Sprite{fromFile='D:/EP45/ndlp/Producers/producer-mini-6x4.png'};local full=L.fromSprite(source);local actor=L.image(32,48);actor:drawImage(full,Point(0,0));source:close()
 for i,spec in ipairs(A.trees) do
  local im=A.tree(spec);L.saveImage(im,root..'trees/'..spec.id)
  local shadow=L.image(spec.w,16);L.ellipse(shadow,2,2,spec.w-4,12,L.color('182731',55));L.saveImage(shadow,root..'trees/'..spec.id..'-shadow')
  local x=(i-1)*104+9;local y=104-spec.anchor[2];comparison:drawImage(im,Point(x,y));comparison:drawImage(actor,Point(x+spec.w-11,104-45))
  L.line(comparison,x-1,105,x+spec.w+17,105,C.ink);L.text(comparison,x,115,spec.id,C.ink)
  local f=assert(io.open(root..'trees/'..spec.id..'.json','w'));f:write(string.format('{"id":"%s","canvas":[%d,%d],"base_anchor":[%d,%d],"collision":[%d,%d,10,8],"actor_reference":[32,48]}',spec.id,spec.w,spec.h,spec.anchor[1],spec.anchor[2],spec.anchor[1]-5,spec.anchor[2]-8));f:close()
 end
 L.saveImage(comparison,root..'previews/tree-scale-guide')
 for _,size in ipairs({{id='4x3',w=384,h=288},{id='2x2',w=320,h=320},{id='16x9',w=512,h=288}}) do
  local w,h=size.w,size.h;local sky=L.image(w,h);L.rect(sky,0,0,w,h,L.color('e4ece7'))
  L.rect(sky,0,h-45,w,45,L.color('dbe5de'))
  local far,mid,near=L.image(w,h),L.image(w,h),L.image(w,h);local horizon=h-40
  for k=0,math.ceil(w/31) do
   local x=k*31-6;local height=44+(k*29)%81;local color=L.color('8fa7b1',48)
   L.rect(far,x,horizon-height,26,height,color);L.rect(far,x+4,horizon-height-7,17,7,color)
   if k%3==0 then L.rect(far,x+12,horizon-height-20,2,15,color) end
   for yy=horizon-height+8,horizon-4,9 do for xx=x+5,x+22,7 do L.rect(far,xx,yy,3,4,L.color('dae7e7',50)) end end
  end
  for k=0,math.ceil(w/49) do
   local x=k*49-11;local height=30+(k*13)%39;local color=L.color('7f9ba6',50)
   L.rect(mid,x,horizon-height+13,42,height,color);L.poly(mid,{{x-3,horizon-height+13},{x+21,horizon-height-3},{x+45,horizon-height+13}},color)
   L.rect(mid,x+9,horizon-height+21,7,11,L.color('dce7e4',65));L.rect(mid,x+26,horizon-height+21,7,11,L.color('dce7e4',65))
  end
  L.rect(near,0,horizon+25,w,4,L.color('6f918e',45));L.rect(near,0,horizon+29,w,7,L.color('93ada3',35))
  for i=1,3 do
   local spec=A.trees[i];local im=A.tree(spec);local x=({19,math.floor(w*.51),w-90})[i];local y=horizon+27-spec.anchor[2]
   for yy=0,im.height-1 do for xx=0,im.width-1 do if app.pixelColor.rgbaA(im:getPixel(xx,yy))>0 then L.px(near,x+xx,y+yy,L.color('87a59c',64)) end end end
  end
  L.saveLayers(w,h,{{name='Pale sky',image=sky},{name='Far city - subtle silhouette',image=far},{name='Mid city - low contrast roofs',image=mid},{name='Near soft trees and ground',image=near}},root..'backgrounds/city-faint-'..size.id)
  png(far,root..'backgrounds/city-far-'..size.id);png(mid,root..'backgrounds/city-mid-'..size.id);png(near,root..'backgrounds/city-trees-'..size.id)
 end
end
return A
