local root='D:/GitHub/TheProducers/'
local out='D:/EP45/ndlp/Producers/Native-lots/'
local L=dofile(root..'assets/lots/source/pixel-lib.lua');local R,B,E,P=L.rect,L.line,L.ellipse,L.poly;local C=L.C
local function save(im,name,path)
 im:saveAs(root..path);local s=Sprite(im.width,im.height);s.layers[1].name=name;s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(out..name..'.aseprite');s:close()
end
for k,id in ipairs({'far','mid','trees'})do
 local im=L.image(512,288)
 if id~='trees' then
  for j=0,10 do local x=j*49-8;local h=35+(j*31+k*19)%100;local y=288-h;local col=L.color(k==1 and '52647a' or '394b61');R(im,x,y,43,h,col);R(im,x+2,y+1,39,1,L.color(k==1 and '65768a' or '52647a'));R(im,x+34,y+2,8,h-2,L.color(k==1 and '4b5d73' or '304155'))
   for yy=y+8,280,9 do for xx=x+5,x+30,8 do if (xx+yy)%5~=0 then R(im,xx,yy,3,4,L.color(k==1 and '6c7b8c' or '72818a'))end end end
   if j%3==0 then R(im,x+18,y-12,1,12,col);R(im,x+10,y-3,23,3,col)end
  end
 else
  for j=0,6 do local x=j*82+20;local h=45+(j*13)%25;R(im,x,288-h,4,h,C.bark);B(im,x+1,282,x-10,255,C.bark);E(im,x-24,288-h-17,49,37,C.leafDark);E(im,x-20,288-h-20,39,30,C.leaf);E(im,x-16,288-h-20,27,18,C.leafMid);B(im,x-12,288-h-18,x+4,288-h-18,C.leafHi)end
 end
 save(im,'city-'..id, 'assets/lots/backgrounds/city-'..id..'-16x9.png')
end
local im=L.image(144,192)
for row=0,7 do for f=0,5 do local x=f*24+7;local y=row*24+7+(f%3-1);local col=({C.goldHi,C.cyan,C.pink,C.white})[row%4+1]
 E(im,x,y+8,5,3,C.ink);E(im,x+1,y+8,4,2,col);R(im,x+4,y,1,9,C.ink);R(im,x+3,y+1,1,8,col)
 if row%2==0 then R(im,x+4,y,7,2,col);R(im,x+10,y,1,8,col);E(im,x+7,y+7,4,3,col)else B(im,x+4,y,x+8,y+4,col);B(im,x+8,y+4,x+7,y+6,col)end
end end
save(im,'music-notes','assets/lots/effects/music-notes-atlas.png')
