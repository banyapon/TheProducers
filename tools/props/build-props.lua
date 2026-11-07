local G=dofile('D:/GitHub/TheProducers/tools/props/tree-style.lua')
-- Draw original Thai scene props as native Aseprite pixels.
local root='D:/GitHub/TheProducers/'
local src='D:/EP45/ndlp/Producers/Props/'
app.fs.makeAllDirectories(src)
local L=dofile(root..'assets/lots/source/pixel-lib.lua');local C=L.C
local R,B,E,P,T=L.rect,L.line,L.ellipse,L.poly,L.text
local function c(h)return L.color(h)end
local ink=c('2e2734')
local function box(im,x,y,w,h,col)R(im,x,y,w,h,ink);R(im,x+1,y+1,w-2,h-2,col)end
local manifest={version=1,pixel_scale=1,character_height=114,props={}}
local previews={}
local function soften(im)
 local pc=app.pixelColor;local cache={}
 for y=0,im.height-1 do for x=0,im.width-1 do
  local p=im:getPixel(x,y)
  if pc.rgbaA(p)>0 then
   if not cache[p]then
    local r,g,b=pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p)
    local lum=r*.299+g*.587+b*.114
    local mix=lum<65 and .055 or .12
    local function tone(v,target)return math.floor((v*.94+lum*.06)*(1-mix)+target*mix+.5)end
    cache[p]=pc.rgba(tone(r,239),tone(g,231),tone(b,219),pc.rgbaA(p))
   end
   im:drawPixel(x,y,cache[p])
  end
 end end
end
local function save(id,group,im,anchor,front)
 soften(im)
 local path='assets/props/'..group..'/'..id..'.png'
 im:saveAs(root..path)
 local s=Sprite(im.width,im.height);s.layers[1].name=front and 'Foreground - above all characters' or 'Prop';s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(src..id..'.aseprite');s:close()
 manifest.props[id]={texture='res://'..path,cell={im.width,im.height},anchor=anchor,frames=1,z_index=front and 6 or 0,placement={group},tintable=false}
 table.insert(previews,{id,im})
end
local function pot(im,x,f,w,kind)
 local col=kind==2 and c('cbc7b7')or c('a46b4d')
 P(im,{{x-w//2,f-24},{x+w//2,f-24},{x+w//2-3,f-1},{x-w//2+3,f-1}},ink)
 P(im,{{x-w//2+2,f-22},{x+w//2-2,f-22},{x+w//2-5,f-2},{x-w//2+5,f-2}},col)
 B(im,x-w//2+4,f-20,x-w//2+6,f-4,kind==2 and c('eeeadb')or c('cf9670'))
 box(im,x-w//2-1,f-25,w+2,5,col);R(im,x-w//2+2,f-24,w-4,1,c('5d423b'))
end
local function leaf(im,x,y,dx,dy)
 local len=math.sqrt(dx*dx+dy*dy);local nx=-dy/len;local ny=dx/len;local w=math.max(4,len*.16)
 P(im,{{x,y},{x+dx*.35+nx*w,y+dy*.35+ny*w},{x+dx*.72+nx*w*.6,y+dy*.72+ny*w*.6},{x+dx,y+dy},{x+dx*.6-nx*w,y+dy*.6-ny*w}},c('274f44'))
 P(im,{{x,y},{x+dx*.35+nx*(w-1),y+dy*.35+ny*(w-1)},{x+dx,y+dy},{x+dx*.6,y+dy*.6}},c('548366'))
 B(im,x,y,x+dx*.85,y+dy*.85,c('92ad72'))
end

for k,id in ipairs({'monstera','snake-plant','rubber-plant','areca-palm','lotus-pot','bonsai'})do
 local im=G.draw(80,104,k,true)
 local canvas=L.image(80,112);canvas:drawImage(im,Point(0,4))
 save('plant-'..id,'inside',canvas,{40,108},false)
end
for k,id in ipairs({'arcade-fighter','arcade-rhythm'})do
 local im=L.image(72,144)
 P(im,{{7,140},{7,48},{12,14},{59,14},{65,44},{57,79},{66,87},{65,140}},ink)
 P(im,{{9,138},{9,49},{14,16},{57,16},{62,43},{54,80},{63,89},{62,138}},k==1 and c('714357')or c('325b70'))
 box(im,12,19,46,15,c('ad775d'));T(im,15,24,k==1 and 'FIGHT' or 'DANCE',c('f3dfa8'))
 box(im,13,39,44,39,c('182c3f'));R(im,16,42,38,2,c('7489a0'))
 if k==1 then R(im,17,47,15,2,c('bd6d77'));R(im,37,47,15,2,c('7ca492'));E(im,23,53,6,6,c('ddb387'));R(im,23,59,7,11,c('ba6770'));E(im,42,54,6,6,c('ddb387'));R(im,41,60,7,10,c('648ba1'));R(im,17,72,35,2,c('6c7790'))
 else for j=0,3 do local x=18+j*9;B(im,x,49,x,69,c('3e516b'));P(im,{{x-3,57+j%2*6},{x,54+j%2*6},{x+3,57+j%2*6}},j%2==0 and c('cd80a4')or c('79bbb8'))end end
 P(im,{{12,79},{54,79},{63,88},{9,88}},c('9d8191'));B(im,12,80,53,80,c('dac2bd'));R(im,23,76,2,9,ink);E(im,20,74,7,5,c('d47a74'))
 for j=0,2 do E(im,38+j*7,83,5,3,j%2==0 and c('e3b56d')or c('87afab'))end
 box(im,25,100,22,27,c('283342'));R(im,31,105,10,2,c('a9a9a1'));R(im,30,118,12,5,ink);R(im,11,137,50,2,ink)
 save(id,'inside',im,{36,140},false)
end
local bar=L.image(208,88)
box(bar,5,19,198,65,c('845d4b'));R(bar,7,22,194,4,c('bb9067'));R(bar,8,77,192,5,c('543c3e'))
for j=0,5 do box(bar,12+j*31,30,27,43,c('a77b57'));B(bar,15+j*31,32,34+j*31,32,c('d2a677'));R(bar,34+j*31,34,2,36,c('70503f'))end
box(bar,1,14,206,9,c('554449'));R(bar,3,15,202,2,c('e0bc91'));R(bar,4,19,200,2,c('9d7960'))
for j=0,2 do local x=20+j*15;box(bar,x,3,8,12,c('6f9384'));R(bar,x+2,0,4,5,c('aac1a0'));R(bar,x+2,8,4,3,c('e6d8b8'))end
box(bar,158,7,17,7,c('e0d7c4'));R(bar,179,5,7,9,c('d7c7af'));save('wood-bar-front','inside',bar,{104,84},true)
-- Outdoor vehicle: locally familiar yellow roof and green lower body, parked side view.
local taxi=L.image(240,112)
E(taxi,28,78,32,30,ink);E(taxi,177,78,32,30,ink)
for _,x in ipairs({32,181})do E(taxi,x,82,24,22,c('444451'));E(taxi,x+6,87,12,12,c('a5a8ac'));E(taxi,x+9,90,6,6,c('5c6370'))end
P(taxi,{{8,85},{14,63},{55,57},{83,29},{158,29},{190,58},{224,64},{232,85},{226,96},{210,96},{205,79},{183,75},{174,96},{63,96},{57,79},{36,75},{27,96},{9,94}},ink)
P(taxi,{{10,84},{16,65},{57,59},{84,31},{157,31},{189,60},{222,66},{229,84},{224,92},{212,92},{206,77},{183,73},{173,92},{65,92},{58,77},{36,73},{25,92},{11,91}},c('36765b'))
P(taxi,{{18,65},{57,59},{84,31},{157,31},{189,60},{222,66},{223,71},{17,71}},c('dbb648'))
P(taxi,{{64,58},{87,35},{117,35},{117,58}},c('344e61'));P(taxi,{{122,35},{153,35},{179,58},{122,58}},c('344e61'));B(taxi,89,37,113,37,c('8fabb5'));B(taxi,126,37,151,37,c('8fabb5'))
B(taxi,120,60,120,89,c('224e44'));B(taxi,72,61,66,89,c('224e44'));B(taxi,185,62,173,89,c('224e44'));R(taxi,103,65,11,2,c('ddd1a6'));R(taxi,159,65,11,2,c('ddd1a6'))
box(taxi,103,20,33,10,c('e8d9ae'));T(taxi,108,22,'TAXI',ink);R(taxi,13,73,13,7,c('eee2bc'));R(taxi,215,74,12,6,c('c06f67'));R(taxi,13,88,12,3,c('b1b7b1'));R(taxi,214,88,14,3,c('b1b7b1'));T(taxi,90,79,'BANGKOK',c('c8dfbd'))
save('thai-taxi-green-yellow','outside',taxi,{120,108},false)
for k,id in ipairs({'rain-tree','banana-tree','coconut-palm'})do
 local im=L.image(160,208);im:drawImage(G.draw(156,200,k,false),Point(2,4))
 save(id,'outside',im,{80,204},false)
end
local pole=L.image(192,272)
box(pole,91,10,11,258,c('8f9290'));R(pole,93,12,3,252,c('c3c2b4'));R(pole,99,13,2,252,c('626e72'))
for _,y in ipairs({38,65,91})do box(pole,51,y,94,5,c('6a7375'));for _,x in ipairs({60,83,113,135})do R(pole,x,y-11,3,12,ink);for j=0,2 do box(pole,x-2,y-10+j*3,7,3,c('a4aaa1'))end end end
box(pole,105,109,28,44,c('627880'));R(pole,108,111,22,3,c('b3c0ba'));for x=108,129,4 do B(pole,x,117,x,145,c('3e535e'))end
for j=0,5 do local y=39+j*10;B(pole,0,y,47,y+7,ink);B(pole,47,y+7,94,y+3,ink);B(pole,94,y+3,144,y+9,ink);B(pole,144,y+9,191,y+3,ink)end
B(pole,115,152,115,192,ink);B(pole,115,192,101,200,ink);box(pole,93,207,7,18,c('dccfb4'));T(pole,94,212,'8',ink);save('thai-power-pole','outside',pole,{96,268},false)
local store=L.image(320,208)
box(store,9,24,302,176,c('c5c3b4'));R(store,12,28,296,8,c('eddfc4'));box(store,15,39,290,37,c('f0e5cc'))
R(store,17,41,286,6,c('ce7855'));R(store,17,49,286,5,c('e5b956'));R(store,17,56,286,6,c('5b9075'));box(store,124,32,69,40,c('ede1c5'));T(store,133,42,'8-12',c('44685e'),2)
for _,x in ipairs({20,214})do box(store,x,83,86,105,c('3e525e'));for j=0,2 do for k=0,5 do local xx=x+5+k*12;local y=99+j*27;box(store,xx,y,9,16,({c('b77c6b'),c('c9b370'),c('82aaa4')})[(j+k)%3+1])end;R(store,x+3,117+j*27,80,3,c('bec2b1'))end end
box(store,112,81,96,119,c('768b8e'));box(store,116,85,88,111,c('304a59'));R(store,158,84,3,114,c('c0c8bf'));R(store,151,132,3,17,c('ddd4b7'));R(store,166,132,3,17,c('ddd4b7'));B(store,119,88,154,88,c('8fb0b5'));B(store,164,88,201,88,c('8fb0b5'));R(store,10,198,300,6,c('788082'));R(store,13,198,294,2,c('d1d0bc'));save('8-12-convenience-store','outside',store,{160,204},false)
local gallery=L.image(960,900)
for i,v in ipairs(previews)do local x=(i-1)%4*240;local y=(i-1)//4*180;R(gallery,x,y,240,180,c('333b49'));local im=v[2];if im.width<=240 and im.height<=150 then gallery:drawImage(im,Point(x+(240-im.width)//2,y+150-im.height))else local small=Image(im);small:resize(math.floor(im.width*.55),math.floor(im.height*.55));gallery:drawImage(small,Point(x+(240-small.width)//2,y+150-small.height))end;T(gallery,x+8,y+160,v[1],C.white)end
gallery:saveAs(src..'props-catalogue.png')
local f=assert(io.open(root..'assets/props/manifest.json','w'));f:write(json.encode(manifest));f:close();print('Props exported: '..#previews)
