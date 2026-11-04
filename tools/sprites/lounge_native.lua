-- Native 640x360 lounge, drawn directly into Aseprite pixel layers.
local root='D:/GitHub/TheProducers/'
local pc=app.pixelColor
local function c(h)return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255)end
local back=Image(640,360);local front=Image(640,360)
local function rect(im,x,y,w,h,col)for yy=y,y+h-1 do for xx=x,x+w-1 do im:drawPixel(xx,yy,c(col))end end end
local function box(im,x,y,w,h,fill)rect(im,x,y,w,h,'202333');rect(im,x+1,y+1,w-2,h-2,fill)end
rect(back,0,0,640,360,'202333');rect(back,4,5,632,315,'514657')
rect(back,7,9,626,4,'827084');rect(back,7,14,626,2,'393444')
rect(back,7,169,626,151,'47404e');rect(back,7,168,626,2,'675866')
for x=12,630,42 do rect(back,x,174,1,145,'514657')end
rect(back,7,312,626,8,'302d3d');rect(back,0,320,640,40,'222431')
rect(back,4,320,632,2,'8b7782')
-- Notice board: pinned schedules, music flyers, and a small gold record.
box(back,228,115,172,101,'9c7157');rect(back,231,118,166,95,'543d42')
rect(back,234,121,160,89,'b28c68')
for i=0,3 do local x=243+i*36;box(back,x,132+(i%2)*10,28,42,i%2==0 and 'eee3c7' or '94b8b1');rect(back,x+11,130+(i%2)*10,3,3,'d78270');for j=0,3 do rect(back,x+4,142+(i%2)*10+j*6,18-j*2,1,'7e787b')end end
-- Three-seat sofa, seat at the characters' knee height, no mattress or pillow bed.
rect(back,47,312,178,6,'252431');box(back,55,246,160,56,'435965')
rect(back,58,248,154,3,'8badae')
for i=0,2 do box(back,62+i*48,253,46,32,'64818a');rect(back,65+i*48,255,39,1,'95b7b4');rect(back,64+i*48,281,41,2,'3b505e')end
box(back,55,286,160,24,'394e5d')
for i=0,2 do box(back,64+i*47,285,45,12,'77999d');rect(back,66+i*47,286,40,2,'aac4bb')end
box(back,48,274,16,35,'526e7b');box(back,207,274,16,35,'526e7b');rect(back,50,275,12,3,'95b7b4');rect(back,209,275,12,3,'95b7b4')
rect(back,58,309,7,11,'211f2d');rect(back,207,309,7,11,'211f2d')
-- Side table and reading lamp.
box(back,241,281,50,6,'b58b70');rect(back,245,287,4,33,'61474a');rect(back,282,287,4,33,'61474a')
rect(back,257,275,18,4,'292a37');rect(back,265,241,2,35,'a7aaa1');box(back,253,231,27,14,'d5b98b');rect(back,255,244,23,2,'f2dba6')
box(back,245,278,13,3,'c8d0bd')
-- Tall door matching the native sprite height.
box(back,553,174,61,146,'85735b');box(back,557,178,53,138,'574d46');box(back,561,183,45,46,'304651');rect(back,563,185,41,2,'66838b');rect(back,599,253,3,7,'d9c399')
-- Plant and framed acoustic print.
box(back,438,280,28,40,'927059');rect(back,441,282,22,3,'c6a385');rect(back,450,240,3,40,'6d7652')
for i=0,5 do local x= i%2==0 and 432 or 451;local y=240+i*6;rect(back,x,y,19,6,'345952');rect(back,x+2,y-2,14,3,'69846a')end
box(back,64,119,118,78,'a49c90');box(back,68,123,110,70,'293541')
for i=0,9 do local h=12+(i*13)%48;rect(back,77+i*9,181-h,4,h,'6f9397');rect(back,77+i*9,181-h,4,2,'cbb996')end
back:saveAs(root..'assets/lots/rooms/lounge-16x9-back.png');front:saveAs(root..'assets/lots/rooms/lounge-16x9-front.png')
local s=Sprite(640,360);s.layers[1].name='Lounge architecture and furniture';s:newCel(s.layers[1],1,back,Point(0,0));local l=s:newLayer();l.name='Foreground';s:newCel(l,1,front,Point(0,0));s:saveAs('D:/EP45/ndlp/Producers/lounge-native.aseprite');s:close()
-- Scale reference contact sheet: original sprites, no resampling.
local preview=Image(back)
for i,id in ipairs({'male','alice'})do local sp=app.open(root..'assets/sprites/'..id..'/idle.png');local im=Image(480,480);im:drawSprite(sp,1);preview:drawImage(Image(im,Rectangle(0,0,160,160)),Point(300+(i-1)*170,183));sp:close()end
preview:saveAs('D:/EP45/ndlp/Producers/lounge-native-preview.png')
