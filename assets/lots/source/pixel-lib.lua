local lib={}
local rgba=app.pixelColor.rgba
function lib.color(h,a) return rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),a or 255) end
local hex={ink='202332',edge='343b4d',shadow='434655',slate='566377',steel='8290a4',silver='b7c4cd',white='f3eee2',cream='dfd3b5',sand='bea886',wood='997451',woodDark='634a3e',woodHi='c9a579',redDark='582736',red='963c48',redMid='bf5960',redHi='e38a7d',greenDark='254b46',green='43816a',greenHi='77aa7a',lime='b4cd84',blueDark='273b5d',blue='477299',blueHi='7fb1cc',cyan='91d4cc',goldDark='946436',gold='d4a14c',goldHi='f4d68b',purple='805b95',pink='d27da1',coral='ec947c',floorWood='af8965',floorWoodHi='bc9873',floorWoodDark='947556',wall='9ca7ad',wallLight='bec7c6',wallDark='77858f',carpet='5b707e',carpetHi='637b88',tile='96ac9d',tileHi='a5b8a5',tileLine='7f998a',concrete='8e9696',concreteHi='9ca3a0',sky='d9e7e5',cityFar='b7c8cb',cityMid='9db4be',cityNear='88a4b1',leafDark='294e43',leaf='46765a',leafMid='689669',leafHi='96b17a',bark='765442',barkHi='ad8060',paper='e9e1c8',black='171d2b',screen='254759',screenHi='68b1b3',skin='d79460',skinHi='f0b57a'}
lib.C={};for k,v in pairs(hex) do lib.C[k]=lib.color(v) end
lib.palette=Palette(256);lib.palette:setColor(0,Color{r=0,g=0,b=0,a=0});local pi=1
local keys={};for k in pairs(hex) do keys[#keys+1]=k end;table.sort(keys)
for _,k in ipairs(keys) do local h=hex[k];lib.palette:setColor(pi,Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255});pi=pi+1 end
function lib.image(w,h) return Image(w,h,ColorMode.RGB) end
function lib.px(im,x,y,c) x=math.floor(x);y=math.floor(y);if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,c) end end
function lib.rect(im,x,y,w,h,c) x=math.floor(x);y=math.floor(y);w=math.floor(w);h=math.floor(h);for yy=math.max(0,y),math.min(im.height-1,y+h-1) do for xx=math.max(0,x),math.min(im.width-1,x+w-1) do im:drawPixel(xx,yy,c) end end end
function lib.line(im,x,y,a,b,c)
 x=math.floor(x);y=math.floor(y);a=math.floor(a);b=math.floor(b);local dx,dy=math.abs(a-x),-math.abs(b-y);local sx=x<a and 1 or -1;local sy=y<b and 1 or -1;local e=dx+dy
 while true do lib.px(im,x,y,c);if x==a and y==b then break end;local ee=e*2;if ee>=dy then e=e+dy;x=x+sx end;if ee<=dx then e=e+dx;y=y+sy end end
end
function lib.poly(im,p,c)
 local lo,hi=im.height,0;for _,q in ipairs(p) do lo=math.min(lo,q[2]);hi=math.max(hi,q[2]) end
 for y=math.floor(lo),math.floor(hi) do local xs={};local yy=y+.5
  for i,a in ipairs(p) do local b=p[i%#p+1];if(a[2]<=yy and b[2]>yy)or(b[2]<=yy and a[2]>yy)then xs[#xs+1]=a[1]+(yy-a[2])*(b[1]-a[1])/(b[2]-a[2]) end end
  table.sort(xs);for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.ceil(xs[i+1])-1 do lib.px(im,x,y,c) end end
 end
end
function lib.ellipse(im,x,y,w,h,c)
 for yy=0,h-1 do for xx=0,w-1 do if ((xx+.5-w/2)/(w/2))^2+((yy+.5-h/2)/(h/2))^2<=1 then lib.px(im,x+xx,y+yy,c) end end end
end
function lib.frame(im,x,y,w,h,c) lib.rect(im,x,y,w,1,c);lib.rect(im,x,y+h-1,w,1,c);lib.rect(im,x,y,1,h,c);lib.rect(im,x+w-1,y,1,h,c) end
function lib.box(im,x,y,w,h,top,front,edge)
 lib.rect(im,x,y,w,h,edge or lib.C.ink);lib.rect(im,x+1,y+1,w-2,math.max(3,math.floor(h*.36)),top);lib.rect(im,x+1,y+math.max(4,math.floor(h*.36))+1,w-2,h-math.max(4,math.floor(h*.36))-2,front)
 lib.line(im,x+1,y+math.max(4,math.floor(h*.36)),x+w-2,y+math.max(4,math.floor(h*.36)),edge or lib.C.ink)
end
function lib.shadow(im,x,y,w,h) lib.ellipse(im,x,y,w,h,rgba(20,26,39,55)) end
local glyphs={
 A={'01110','10001','10001','11111','10001','10001','10001'},B={'11110','10001','10001','11110','10001','10001','11110'},C={'01111','10000','10000','10000','10000','10000','01111'},D={'11110','10001','10001','10001','10001','10001','11110'},E={'11111','10000','10000','11110','10000','10000','11111'},F={'11111','10000','10000','11110','10000','10000','10000'},G={'01111','10000','10000','10111','10001','10001','01110'},H={'10001','10001','10001','11111','10001','10001','10001'},I={'111','010','010','010','010','010','111'},J={'00111','00010','00010','00010','10010','10010','01100'},K={'10001','10010','10100','11000','10100','10010','10001'},L={'10000','10000','10000','10000','10000','10000','11111'},M={'10001','11011','10101','10101','10001','10001','10001'},N={'10001','11001','10101','10011','10001','10001','10001'},O={'01110','10001','10001','10001','10001','10001','01110'},P={'11110','10001','10001','11110','10000','10000','10000'},Q={'01110','10001','10001','10001','10101','10010','01101'},R={'11110','10001','10001','11110','10100','10010','10001'},S={'01111','10000','10000','01110','00001','00001','11110'},T={'11111','00100','00100','00100','00100','00100','00100'},U={'10001','10001','10001','10001','10001','10001','01110'},V={'10001','10001','10001','10001','10001','01010','00100'},W={'10001','10001','10001','10101','10101','11011','10001'},X={'10001','10001','01010','00100','01010','10001','10001'},Y={'10001','10001','01010','00100','00100','00100','00100'},Z={'11111','00001','00010','00100','01000','10000','11111'},
 ['0']={'01110','10001','10011','10101','11001','10001','01110'},['1']={'010','110','010','010','010','010','111'},['2']={'01110','10001','00001','00110','01000','10000','11111'},['3']={'11110','00001','00001','01110','00001','00001','11110'},['4']={'10010','10010','10010','11111','00010','00010','00010'},['5']={'11111','10000','10000','11110','00001','00001','11110'},['6']={'01110','10000','10000','11110','10001','10001','01110'},['7']={'11111','00001','00010','00100','01000','01000','01000'},['8']={'01110','10001','10001','01110','10001','10001','01110'},['9']={'01110','10001','10001','01111','00001','00001','01110'},['?']={'01110','10001','00001','00010','00100','00000','00100'},['!']={'1','1','1','1','1','0','1'},['.']={'0','0','0','0','0','0','1'},['-']={'000','000','000','111','000','000','000'},['/']={'00001','00001','00010','00100','01000','10000','10000'},[':']={'0','1','0','0','1','0','0'} }
function lib.text(im,x,y,t,c,scale)
 scale=scale or 1;local ox=x
 for ch in t:upper():gmatch('.') do
  if ch==' ' then x=x+4*scale else local g=glyphs[ch] or glyphs['?'];for yy,row in ipairs(g) do for xx=1,#row do if row:sub(xx,xx)=='1' then lib.rect(im,x+(xx-1)*scale,y+(yy-1)*scale,scale,scale,c) end end end;x=x+(#g[1]+1)*scale end
 end
 return x-ox
end
function lib.fromSprite(sprite,frame)
 local im=lib.image(sprite.width,sprite.height)
 for _,layer in ipairs(sprite.layers) do local cel=layer:cel(frame or 1);if cel and layer.isVisible then
  for y=0,cel.image.height-1 do for x=0,cel.image.width-1 do local p=cel.image:getPixel(x,y)
   if cel.image.colorMode==ColorMode.INDEXED then local co=sprite.palettes[1]:getColor(p);p=rgba(co.red,co.green,co.blue,p==sprite.transparentColor and 0 or co.alpha) end
   if app.pixelColor.rgbaA(p)>0 then lib.px(im,x+cel.position.x,y+cel.position.y,p) end
  end end
 end end
 return im
end
function lib.saveLayers(w,h,layers,path)
 local s=Sprite(w,h,ColorMode.RGB);s:setPalette(lib.palette)
 for i,info in ipairs(layers) do local layer=i==1 and s.layers[1] or s:newLayer();layer.name=info.name;s:newCel(layer,1,info.image,Point(0,0));if info.hidden then layer.isVisible=false end end
 s:saveAs(path..'.aseprite')
 local flat=lib.image(w,h);for _,info in ipairs(layers) do if not info.hidden then flat:drawImage(info.image,Point(0,0)) end end
 local png=Sprite(w,h,ColorMode.RGB);png:newCel(png.layers[1],1,flat,Point(0,0));png:saveAs(path..'.png');png:close();s:close();return flat
end
function lib.saveImage(im,path)
 local s=Sprite(im.width,im.height,ColorMode.RGB);s:setPalette(lib.palette);s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(path..'.aseprite');s:saveAs(path..'.png');s:close()
end
function lib.enlarge(im,k) local big=lib.image(im.width*k,im.height*k);for y=0,big.height-1 do for x=0,big.width-1 do big:drawPixel(x,y,im:getPixel(math.floor(x/k),math.floor(y/k))) end end;return big end
return lib
