local L=dofile('D:/GitHub/TheProducers/assets/lots/source/pixel-lib.lua')
local C=L.C
local out='D:/EP45/ndlp/Producers/City-Life/'
local function rect(im,x,y,w,h,c) L.rect(im,x,y,w,h,C[c] or L.color(c)) end
local function ellipse(im,x,y,w,h,c) L.ellipse(im,x,y,w,h,C[c] or L.color(c)) end
local function line(im,x,y,a,b,c) L.line(im,x,y,a,b,C[c] or L.color(c)) end
local function tree(im,x,y,k)
 rect(im,x-3*k,y,6*k,28*k,'bark');rect(im,x,y,2*k,27*k,'barkHi')
 ellipse(im,x-23*k,y-25*k,46*k,37*k,'leafDark');ellipse(im,x-20*k,y-29*k,38*k,34*k,'leaf');ellipse(im,x-16*k,y-30*k,28*k,23*k,'leafMid');ellipse(im,x-10*k,y-27*k,13*k,8*k,'leafHi')
end
local function lamp(im,x,y)
 rect(im,x-1,y,3,62,'ink');rect(im,x-5,y+59,11,4,'ink');rect(im,x-6,y-9,12,11,'goldDark');rect(im,x-4,y-7,8,7,'goldHi');rect(im,x-7,y-11,14,3,'ink')
end
local function bench(im,x,y)
 for j=0,2 do rect(im,x,y+j*4,47,3,'woodHi') end
 rect(im,x-2,y+14,51,4,'wood');rect(im,x+4,y+18,3,9,'ink');rect(im,x+40,y+18,3,9,'ink')
end
local function person(im,x,y,pose,scale)
 local k=scale or 1
 local function r(a,b,w,h,c) rect(im,x+a*k,y+b*k,w*k,h*k,c) end
 local sway=pose%2
 r(9,34,6,11,'ink');r(18,34,6,11,'ink');r(7,44,9,3,'black');r(18,44,9,3,'black')
 r(7,20+sway,20,17,'blueDark');r(11,21+sway,12,14,'white');r(8,22+sway,4,14,'ink');r(21,22+sway,4,14,'ink');r(15,22+sway,3,4,'red');r(14,26+sway,5,6,'redDark')
 r(8,4+sway,17,17,'skin');r(10,4+sway,13,14,'skinHi');r(8,3+sway,17,5,'woodDark');r(7,7+sway,3,7,'woodDark');r(23,7+sway,3,7,'woodDark');r(11,11+sway,2,2,'ink');r(20,11+sway,2,2,'ink');r(12,15+sway,10,3,'woodDark');r(16,14+sway,3,2,'skin');r(15,18+sway,5,1,'redDark')
 r(3,22+sway,5,13,'blueDark');r(2,33+sway,5,4,'skinHi');r(27,22+sway,4,8,'blueDark');r(26,28+sway,5,4,'skinHi');r(28,19+sway,2,11,'steel');r(27,17+sway,4,4,'black')
 if pose>2 then r(1,30+sway,8,5,'paper') end
end
for _,kind in ipairs({'city','park','restaurant','hall'}) do
 local bg=L.image(480,270);local architecture=L.image(480,270);local props=L.image(480,270)
 if kind=='city' or kind=='park' then
  rect(bg,0,0,480,270,'sky');rect(bg,0,55,480,50,'cityFar')
  for i=0,14 do local x=i*35;rect(bg,x,25+(i%4)*8,29,95,'cityMid');for yy=38,100,12 do for xx=x+4,x+23,8 do rect(bg,xx,yy,3,5,'sky') end end end
  rect(bg,0,120,480,150,kind=='park' and 'leafMid' or 'concrete')
  if kind=='city' then
   for i=0,3 do local x=8+i*119;local h=91+(i%2)*26
    rect(architecture,x,145-h,108,h,'ink');rect(architecture,x+3,148-h,102,h-3,({'coral','cream','blueHi','woodHi'})[i+1]);rect(architecture,x-3,141-h,114,5,'white')
    for yy=158-h,100,23 do for xx=x+11,x+89,24 do rect(architecture,xx,yy,15,17,'blueDark');rect(architecture,xx+2,yy+2,10,6,'cyan');line(architecture,xx+7,yy,xx+7,yy+17,'white') end end
    rect(architecture,x+6,111,96,10,'redDark');L.text(architecture,x+12,113,({'RECORDS','CAFE','MUSIC HALL','FLOWERS'})[i+1],C.goldHi)
    rect(architecture,x+7,123,94,22,'blueDark');for xx=x+9,x+94,15 do rect(architecture,xx,123,10,21,'cyan') end
   end
   rect(architecture,0,147,480,13,'cream');rect(architecture,0,161,480,55,'slate');for x=0,480,40 do rect(architecture,x,186,22,3,'goldHi') end
   rect(architecture,0,218,480,52,'concreteHi');for x=0,480,24 do line(architecture,x,219,x-12,270,'concrete') end
   tree(props,28,221,1);tree(props,450,220,1);lamp(props,145,108);lamp(props,348,108);bench(props,210,226)
  else
   L.poly(architecture,{{170,120},{251,120},{330,270},{85,270}},C.sand);L.poly(architecture,{{190,120},{234,120},{292,270},{116,270}},C.cream)
   ellipse(architecture,286,158,139,59,'leafDark');ellipse(architecture,290,158,130,50,'blue');ellipse(architecture,299,161,112,39,'blueHi')
   for i=0,8 do line(architecture,310+i*9,172+(i%3)*7,323+i*9,172+(i%3)*7,'cyan') end
   for _,p in ipairs({{38,131},{102,114},{370,122},{445,147},{43,228}}) do tree(props,p[1],p[2],1.4) end
   bench(props,88,169);bench(props,278,220);lamp(props,160,113);lamp(props,253,130)
   for i=1,60 do local x=(i*73)%480;local y=140+(i*31)%126;if x<115 or x>330 then rect(props,x,y,2,3,'leafDark');rect(props,x-1,y-2,4,3,i%2==0 and 'pink' or 'goldHi') end end
  end
 elseif kind=='restaurant' then
  rect(bg,0,0,480,270,'redDark');rect(bg,0,19,480,140,'cream');rect(bg,0,157,480,113,'floorWood')
  for y=165,270,14 do line(bg,0,y,480,y,'floorWoodDark');for x=(y%3)*17,480,51 do line(bg,x,y,x,y+13,'floorWoodDark') end end
  for i=0,3 do local x=24+i*115;rect(architecture,x,35,86,92,'woodDark');rect(architecture,x+4,39,78,82,'blueDark');rect(architecture,x+8,43,70,74,'blue');rect(architecture,x+40,39,4,82,'goldHi');rect(architecture,x+4,76,78,3,'goldHi');rect(architecture,x-5,29,96,7,'red');rect(architecture,x-3,36,13,92,'red');rect(architecture,x+73,36,15,92,'red');lamp(props,x+42,10) end
  rect(architecture,0,141,480,15,'woodDark');rect(architecture,0,141,480,3,'gold')
  for _,p in ipairs({{55,187},{199,187},{346,187},{129,244},{300,244}}) do local x,y=p[1],p[2]
   ellipse(props,x-8,y+8,91,14,'floorWoodDark');rect(props,x+10,y,4,29,'woodDark');rect(props,x+59,y,4,29,'woodDark');rect(props,x-12,y-15,14,26,'red');rect(props,x+72,y-15,14,26,'red');ellipse(props,x,y-10,74,22,'white');ellipse(props,x+7,y-6,17,10,'silver');ellipse(props,x+48,y-6,17,10,'silver');rect(props,x+35,y-17,4,14,'gold');rect(props,x+36,y-21,2,5,'goldHi');rect(props,x+26,y-1,4,6,'blueHi')
  end
 else
  rect(bg,0,0,480,270,'black');rect(bg,15,14,450,182,'purple');rect(bg,24,25,432,166,'blueDark')
  for x=28,450,35 do rect(architecture,x,25,17,155,'redDark');rect(architecture,x+2,25,4,154,'red') end
  rect(architecture,82,39,316,87,'ink');L.frame(architecture,84,41,312,83,C.gold);L.text(architecture,117,56,'THE PRODUCERS',C.goldHi,3);L.text(architecture,163,90,'MUSIC AWARDS',C.white,2)
  L.poly(architecture,{{77,20},{43,187},{210,187}},L.color('dfd3b5',45));L.poly(architecture,{{400,20},{270,187},{445,187}},L.color('dfd3b5',45))
  rect(architecture,19,185,442,13,'woodHi');rect(architecture,31,199,418,10,'wood');rect(architecture,48,211,384,10,'woodDark');rect(architecture,68,222,344,7,'goldDark')
  rect(props,287,143,44,43,'woodDark');rect(props,283,139,52,7,'gold');L.text(props,296,153,'TP',C.goldHi,2)
  ellipse(props,127,160,30,7,'goldDark');rect(props,139,140,6,21,'gold');ellipse(props,129,124,26,21,'goldHi');rect(props,126,123,32,4,'gold')
  for row=0,1 do for x=5+row*18,480,36 do ellipse(props,x,239+row*18,25,19,'ink');rect(props,x-2,251+row*17,29,16,'redDark') end end
 end
 L.saveLayers(480,270,{{name='Backdrop',image=bg},{name='Architecture',image=architecture},{name='Props',image=props}},out..kind)
end
local sheet=L.image(192,192)
for row=0,3 do for col=0,5 do person(sheet,col*32,row*48,col+row,1) end end
L.saveImage(sheet,out..'announcer-6x4')
local portrait=L.image(192,192)
for row=0,1 do for col=0,1 do person(portrait,col*96+16,row*96,col+row*2,2) end end
L.saveImage(portrait,out..'announcer-2x2')
local anim=Sprite(32,48,ColorMode.RGB);anim.layers[1].name='Mustached announcer - tuxedo and microphone'
for i=1,24 do if i>1 then anim:newEmptyFrame() end;local im=L.image(32,48);person(im,0,0,(i-1)%6+math.floor((i-1)/6),1);anim:newCel(anim.layers[1],i,im,Point(0,0));anim.frames[i].duration=0.16 end
for row=0,3 do local tag=anim:newTag(row*6+1,row*6+6);tag.name=({'Idle','Announce','Applause','Envelope'})[row+1] end
anim:saveAs(out..'announcer-animation.aseprite');anim:close()
for variant=1,3 do
 local s=Sprite(48,64,ColorMode.RGB);s.layers[1].name='Flames';local sheet=L.image(288,64)
 for frame=1,6 do
  if frame>1 then s:newEmptyFrame() end
  local im=L.image(48,64)
  for flame=0,4 do
   local x=5+flame*8;local top=14+((flame*11+frame*5+variant*7)%24)
   L.poly(im,{{x-6,60},{x-8,40},{x-1,top+9},{x+3,top-9},{x+5,top+12},{x+10,47},{x+7,62}},C.red)
   L.poly(im,{{x-4,60},{x-3,43},{x+2,top+6},{x+7,48},{x+5,62}},C.coral)
   L.poly(im,{{x-2,61},{x+2,top+19},{x+5,56},{x+4,63}},C.goldHi)
  end
  for n=1,5 do rect(im,(n*13+frame*3)%44,((n*9-frame*3)%32),2,3,'goldHi') end
  s:newCel(s.layers[1],frame,im,Point(0,0));s.frames[frame].duration=0.12;sheet:drawImage(im,Point((frame-1)*48,0))
 end
 local t=s:newTag(1,6);t.name='Burn';s:saveAs(out..'fire-'..variant..'-animation.aseprite');s:close();L.saveImage(sheet,out..'fire-'..variant)
end
print('City-Life: 4 layered scenes, announcer 2x2 / 6x4 / animation, 3 animated fire sheets built')
