-- Native pixel city scenery, drawn using Aseprite Image:drawPixel primitives.
local root='D:/GitHub/TheProducers/'
local out='D:/EP45/ndlp/Producers/Native-city/'
app.fs.makeAllDirectories(out)
local L=dofile(root..'assets/lots/source/pixel-lib.lua');local C=L.C
local R,B,E,P,T=L.rect,L.line,L.ellipse,L.poly,L.text
local function c(h)return L.color(h)end
C.ink=c('292331')
local function box(im,x,y,w,h,col)R(im,x,y,w,h,C.ink);R(im,x+1,y+1,w-2,h-2,col)end
local function sign(im,x,y,txt)box(im,x,y,#txt*6+12,18,c('413f4e'));T(im,x+6,y+6,txt,c('f1d399'));B(im,x+2,y+1,x+#txt*6+9,y+1,c('a18470'))end
local function lamp(im,x,y)R(im,x,y,2,95,C.ink);R(im,x-4,y+94,10,3,C.ink);box(im,x-5,y-12,12,16,c('aa9166'));R(im,x-3,y-10,8,11,c('ffe2a0'));R(im,x-1,y-10,1,11,c('fff0c4'));R(im,x-3,y-15,8,3,C.ink)end
local function plant(im,x,f)
 box(im,x-8,f-17,19,17,c('956850'));R(im,x-6,f-16,15,2,c('d2a47b'));B(im,x,f-17,x+2,f-47,c('4b573b'))
 for i=0,4 do local y=f-42+i*6;P(im,{{x,y+7},{x-14,y-2},{x-16,y-7},{x-7,y-5}},c('3b6351'));P(im,{{x+1,y+5},{x+13,y-5},{x+16,y-5},{x+12,y+2}},c('698761'));B(im,x+3,y+2,x+12,y-3,c('a4ad74'))end
end
local function bench(im,x,f,w)
 R(im,x+5,f-29,3,29,C.ink);R(im,x+w-8,f-29,3,29,C.ink)
 for i=0,2 do box(im,x,f-51+i*7,w,6,c('a17755'));R(im,x+2,f-50+i*7,w-4,1,c('d5ac7b'))end
 box(im,x-3,f-29,w+6,6,c('906548'));R(im,x-2,f-28,w+4,1,c('d5ac7b'));B(im,x+8,f-22,x+w-8,f-22,C.ink)
end
local function tree(im,x,f)
 R(im,x-3,f-75,7,75,c('584943'));B(im,x,f-4,x,f-70,c('ae8661'))
 for _,v in ipairs({{-26,-92,42,44},{-6,-107,43,53},{15,-87,33,37}})do E(im,x+v[1],f+v[2],v[3],v[4],c('294b46'));E(im,x+v[1]+2,f+v[2]+1,v[3]-5,v[4]-10,c('486d54'));E(im,x+v[1]+6,f+v[2]+2,v[3]-14,12,c('78915e'))end
end
local function door(im,x,f)
 box(im,x,f-136,53,136,c('86634f'));box(im,x+4,f-131,45,126,c('4b5559'));box(im,x+7,f-128,39,81,c('38525e'));B(im,x+9,f-126,x+42,f-126,c('8da7a4'));R(im,x+41,f-56,3,11,c('e5c58e'));box(im,x+8,f-40,37,30,c('5f716e'))
end
local function interior(im,wall)
 R(im,0,0,430,242,c(wall));R(im,0,0,430,8,C.ink);R(im,0,9,430,2,c('b49c8a'));R(im,0,146,430,72,c('45434b'));R(im,0,145,430,2,c('85756c'))
 for x=6,429,36 do B(im,x,150,x,214,c('56505a'))end
 R(im,0,215,430,3,C.ink);R(im,0,218,430,24,c('84654f'));for y=221,242,8 do B(im,0,y,429,y,c('665143'));for x=(y%2)*31,429,62 do B(im,x,y,x,y+6,c('755946'))end end
end
local function pendant(im,x,y)
 R(im,x,10,1,y-10,C.ink);P(im,{{x-8,y},{x+9,y},{x+15,y+15},{x-14,y+15}},C.ink);P(im,{{x-6,y+2},{x+7,y+2},{x+12,y+13},{x-11,y+13}},c('a67a50'));R(im,x-10,y+14,21,2,c('ffe0a2'))
end
local function skyline(im)
 R(im,0,0,430,242,c('8293ad'));R(im,0,52,430,90,c('b9a8aa'))
 for j=0,9 do local x=j*46-4;local y=25+(j*17)%40;R(im,x,y,39,135-y,c('6d798e'));R(im,x+32,y,7,135-y,c('5f6a7f'));for yy=y+6,130,10 do for xx=x+5,x+28,8 do R(im,xx,yy,3,4,c('bdc2bf'))end end end
end
local gallery=L.image(860,726)
for i,kind in ipairs({'city','park','restaurant','hall','shop','agency'})do
 local im=L.image(430,242)
 if kind=='city' then
  skyline(im);R(im,0,205,430,37,c('716b70'));R(im,0,216,430,3,c('b9aaa0'));B(im,0,238,429,238,c('47444f'))
  box(im,7,36,130,170,c('775764'));box(im,144,19,137,187,c('a17969'));box(im,288,43,135,163,c('546774'))
  for x=17,410,49 do if x<130 or x>290 then box(im,x,57,31,42,c('344452'));R(im,x+3,60,24,2,c('a5aaa6'));R(im,x+14,60,1,36,c('887b75'))end end
  sign(im,18,105,'VINYL CLUB');box(im,18,129,105,72,c('354b58'))
  for j=0,2 do box(im,24+j*31,151,27,33,({c('b66c6c'),c('c0a26d'),c('6d9b94')})[j+1]);E(im,30+j*31,157,15,15,C.ink);E(im,36+j*31,163,3,3,c('d2b17c'))end
  door(im,187,205);sign(im,158,43,'MUSIC ROW');for _,j in ipairs({0,3})do box(im,153+j*29,71,22,31,c('4c5967'));R(im,155+j*29,73,18,1,c('b8c4be'))end
  sign(im,302,105,'NIGHT CAFE');box(im,301,131,107,70,c('453c49'));for _,x in ipairs({326,380})do R(im,x,134,1,12,C.ink);E(im,x-8,146,17,5,c('e2b57c'))end
  for x=298,413,12 do R(im,x,125,12,9,((x-298)//12)%2==0 and c('af655e')or c('d6baa0'))end
  plant(im,143,216);plant(im,282,216);box(im,30,190,34,26,c('32333f'));T(im,34,196,'LIVE',c('e3bd80'));T(im,34,206,'8 PM',c('d6d0b9'))
  for x=8,429,43 do B(im,x,220,x-5,236,c('92837d'))end
 elseif kind=='park' then
  skyline(im);R(im,0,120,430,122,c('647d61'));R(im,0,121,430,3,c('8d9b73'))
  P(im,{{186,121},{242,121},{337,242},{75,242}},c('c0ab8b'));B(im,186,122,75,241,c('e2cba4'));B(im,242,122,337,241,c('e2cba4'))
  tree(im,35,170);tree(im,102,144);tree(im,389,164);tree(im,329,133)
  E(im,265,157,135,40,c('354e54'));E(im,267,155,131,36,c('aaa99a'));E(im,273,158,119,27,c('5b939d'));E(im,285,161,92,18,c('78acac'))
  box(im,325,139,13,30,c('b5b7a6'));E(im,309,136,46,10,c('d4ceb4'));E(im,313,137,38,5,c('77a7a9'));B(im,332,125,332,139,c('d4ece1'));B(im,329,127,325,135,c('9ac7c5'));B(im,335,127,339,135,c('9ac7c5'))
  bench(im,15,211,77);bench(im,340,231,77);lamp(im,130,109);lamp(im,260,88)
  for j=0,32 do local x=(j*73+11)%430;local y=160+(j*17)%78;if x<95 or x>345 then B(im,x,y,x,y+4,c('3f604b'));R(im,x-1,y-1,3,2,j%3==0 and c('e6bc84')or c('c88489'))end end
 elseif kind=='restaurant' then
  interior(im,'795451');pendant(im,70,32);pendant(im,220,35);pendant(im,367,32)
  for _,x in ipairs({22,290})do box(im,x,60,119,80,c('b18c70'));box(im,x+4,64,111,72,c('354559'));for j=0,5 do R(im,x+9+j*17,88+(j%3)*9,11,43-(j%3)*9,c('526378'));R(im,x+11+j*17,96+(j%3)*9,2,3,c('d5b684'))end;R(im,x+57,65,3,70,c('9b7c6b'))end
  sign(im,152,16,'BLUE NOTE BISTRO');box(im,173,76,81,64,c('303d40'));T(im,185,86,'TODAY',c('dfcfaa'));T(im,181,104,'JAZZ',c('c39276'));T(im,181,118,'DINNER',c('d0b694'))
  for _,x in ipairs({15,330})do box(im,x,164,85,45,c('713f4c'));box(im,x+3,167,79,23,c('9b6268'));for j=1,3 do B(im,x+j*20,168,x+j*20,188,c('5f3844'))end;box(im,x-3,190,91,9,c('ad7777'));R(im,x+4,199,5,19,C.ink);R(im,x+75,199,5,19,C.ink);box(im,x+8,181,68,6,c('b98d68'));R(im,x+39,187,4,31,C.ink);E(im,x+27,215,28,3,C.ink);E(im,x+17,178,17,4,c('e9dabb'));E(im,x+51,178,17,4,c('e9dabb'));R(im,x+40,170,2,10,c('f6d69a'));R(im,x+40,167,2,3,c('f4b365'))end
  plant(im,116,218);plant(im,315,218)
 elseif kind=='hall' then
  interior(im,'483a52');R(im,0,218,430,24,c('723e4d'));R(im,24,173,382,7,c('ca9a5e'));R(im,24,180,382,10,c('694753'));R(im,17,190,396,9,c('bb885c'));R(im,9,200,412,10,c('8c614f'));B(im,10,200,418,200,c('e0b27b'))
  box(im,47,34,336,138,c('302f45'));box(im,100,52,230,98,c('1e3445'));sign(im,123,66,'THE PRODUCER AWARDS');T(im,145,95,'MUSIC OF THE YEAR',c('b4bbc3'))
  for _,x in ipairs({38,345})do R(im,x,26,48,147,c('703443'));for j=0,3 do R(im,x+j*12,28,6,143,c('a65056'));R(im,x+j*12+6,28,3,143,c('4b293c'))end end
  for x=45,389,56 do box(im,x,18,14,8,c('4a4b55'));R(im,x+3,25,8,3,c('ffe4aa'))end
  box(im,203,134,40,33,c('77564c'));R(im,205,135,36,2,c('c79a68'));E(im,216,145,13,13,c('d1a267'));B(im,225,134,227,124,C.ink);R(im,223,122,6,3,C.steel)
  for _,x in ipairs({114,285})do box(im,x,137,28,35,c('5c5162'));E(im,x+7,123,14,13,c('d3a65c'));R(im,x+12,136,4,4,c('d3a65c'));R(im,x+6,140,16,2,c('e7c886'))end
 elseif kind=='shop' then
  interior(im,'555565');sign(im,115,25,'SIDE B RECORDS');pendant(im,64,39);pendant(im,366,39)
  for _,x in ipairs({18,314})do box(im,x,80,97,123,c('684d47'));for row=0,2 do local y=88+row*35;R(im,x+3,y+28,91,3,c('c0926c'));for j=0,3 do local xx=x+7+j*22;box(im,xx,y,19,27,({c('b66e77'),c('6b9296'),c('c3a56b'),c('7a729f')})[(j+row)%4+1]);E(im,xx+3,y+5,13,13,C.ink);E(im,xx+8,y+10,3,3,c('e1c290'))end end end
  for j=0,2 do local x=161+j*47;R(im,x,78,2,55,c('be9972'));E(im,x-11,121,25,28,c('332a39'));E(im,x-9,123,21,24,j%2==0 and c('c99256')or c('9b555e'));E(im,x-2,129,7,7,C.ink);B(im,x+1,82,x+1,145,c('ead1a3'));R(im,x-2,75,7,10,c('755343'))end
  box(im,139,163,154,55,c('725650'));R(im,141,165,150,4,c('c6a179'));box(im,173,170,84,36,c('394754'));for j=0,7 do B(im,180+j*9,174,180+j*9,201,c('778c91'));R(im,178+j*9,182+(j%3)*4,5,3,c('b6bdb4'))end
 elseif kind=='agency' then
  interior(im,'65747a');sign(im,123,24,'MARKET MELODY');box(im,21,66,111,89,c('b2ada0'));box(im,25,70,103,81,c('d4d6c7'))
  for j=0,4 do R(im,35+j*17,137-j*9,10,10+j*9,c('658d89'))end;B(im,33,140,118,140,c('67767c'));T(im,36,79,'AUDIENCE',c('455b68'))
  box(im,292,65,116,90,c('aaa89a'));box(im,296,69,108,82,c('e2d8bc'));for j=0,5 do local x=302+(j%3)*32;local y=78+(j//3)*32;box(im,x,y,25,24,j%2==0 and c('bd8b7a')or c('88a5a0'));B(im,x+4,y+6,x+20,y+6,c('e5dac1'))end
  box(im,147,77,126,72,c('293847'));box(im,151,81,118,64,c('344e60'));T(im,164,91,'INSIGHT',c('94c5bf'));for j=0,3 do R(im,164,110+j*7,78-j*11,2,c('7aa7aa'))end
  box(im,123,168,184,50,c('576875'));R(im,125,170,180,4,c('b5baa9'));box(im,166,145,44,24,c('293742'));box(im,169,148,38,18,c('648e94'));R(im,162,168,52,2,c('cbd2c5'));T(im,176,190,'CONSULT',c('dfd3b3'));plant(im,52,218);plant(im,380,218)
 end
 -- Material details: restrained three-tone clusters, never smooth gradients.
 if kind=='city' then
  for y=41,97,9 do for x=11,134,24 do if y<55 or x>116 then B(im,x,y,math.min(135,x+16),y,c('8e6870'))end end end
  for _,x in ipairs({19,68,313,362})do B(im,x+2,62,x+8,62,c('b5bbb2'));B(im,x+3,64,x+3,82,c('637d88'))end
  R(im,10,101,124,3,c('4b3848'));R(im,290,101,130,3,c('384b58'))
  B(im,8,29,143,32,C.ink);B(im,143,32,280,17,C.ink);B(im,280,17,425,35,C.ink)
  for j=0,14 do local x=12+j*28;local y=x<143 and 30 or(x<280 and 23 or 30);R(im,x,y,2,4,c('f3d495'))end
 elseif kind=='park' then
  for j=0,12 do local x=280+(j*19)%107;local y=163+(j*7)%17;B(im,x,y,x+7,y,c('a9cbc5'))end
  for j=0,38 do local x=(j*41)%430;local y=133+(j*11)%105;if (x<90 or x>347)then B(im,x,y,x+3,y-2,c('81956a'))end end
  box(im,184,138,37,17,c('52655c'));T(im,188,143,'PARK',c('e8d6a5'));R(im,201,155,2,16,c('6c5848'))
 elseif kind=='restaurant' then
  for _,x in ipairs({27,295})do B(im,x,66,x+105,66,c('aeb6ad'));B(im,x,69,x+37,106,c('647d86'))end
  box(im,11,82,6,50,c('b0906a'));box(im,414,82,6,50,c('b0906a'))
  for _,x in ipairs({18,333})do R(im,x,166,78,2,c('c18a83'));R(im,x,198,78,2,c('583441'))end
 elseif kind=='hall' then
  for x=53,377,14 do R(im,x,38,2,2,c('d3b47d'))end
  for _,x in ipairs({47,354})do R(im,x,30,3,139,c('c2716a'));R(im,x+21,30,2,139,c('402739'))end
  for j=0,8 do local x=90+j*30;R(im,x,210,13,1,c('c59464'))end
 elseif kind=='shop' then
  for _,x in ipairs({18,314})do for y=84,191,35 do B(im,x+2,y,x+93,y,c('c39a75'))end end
  box(im,161,48,105,18,c('3b4652'));T(im,166,54,'LISTEN / CREATE',c('cbb899'))
  for x=147,281,19 do R(im,x,175,2,31,c('554049'))end
 elseif kind=='agency' then
  for j=0,2 do box(im,24+j*22,32,16,23,c('3c4b59'));R(im,27+j*22,35,10,14,c('b9ad8b'));B(im,29+j*22,40,34+j*22,40,c('f2dfb6'))end
  R(im,125,174,180,1,c('94a9aa'));R(im,125,214,180,3,c('354750'))
 end
 local s=Sprite(430,242);s.layers[1].name='Native city environment';s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(out..kind..'.aseprite');s:close();im:saveAs(root..'assets/city/'..kind..'.png')
 local preview=Image(im)
 for j,id in ipairs({'male','alice'})do local sp=app.open(root..'assets/sprites/'..id..'/idle.png');local a=L.image(480,480);a:drawSprite(sp,1);sp:close();preview:drawImage(Image(a,Rectangle(0,0,160,160)),Point((j==1 and 162 or 277)-80,218-137))end
 gallery:drawImage(preview,Point((i-1)%2*430,(i-1)//2*242))
end
gallery:saveAs(out..'city-scale-review.png')
local f=assert(io.open(root..'assets/city/scene-scale.json','w'));f:write(json.encode({canvas={430,242},ui_size={860,484},pixel_scale=2,character_visible_height=114,feet_y=218,scenes={'city','park','restaurant','hall','shop','agency'}}));f:close()
print('6 native city backgrounds drawn at 430x242')
