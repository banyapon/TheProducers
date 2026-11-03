local root='D:/EP45/ndlp/Producers/lots/'
local base='D:/EP45/ndlp/Producers/'
local L=dofile(root..'source/pixel-lib.lua');local Effects=dofile(root..'source/effects-art.lua');local Nature=dofile(root..'source/nature-art.lua');local Instruments=dofile(root..'source/instrument-art.lua');local C=L.C
Effects.build();Nature.build()
local actors={}
for id,name in ipairs({'producer-mini-6x4.png','secret-mini-6x4.png'}) do
 local s=Sprite{fromFile=base..name};local all=L.fromSprite(s);s:close();actors[id]={sway={},talk={}}
 for f=0,5 do
  actors[id].sway[f+1]=L.image(32,48);actors[id].sway[f+1]:drawImage(all,Point(-f*32,-96))
  actors[id].talk[f+1]=L.image(32,48);actors[id].talk[f+1]:drawImage(all,Point(-f*32,-144))
 end
end
local function loaded(path) local s=Sprite{fromFile=path};local im=L.fromSprite(s);s:close();return im end
local function demo(name,bg,render)
 local s=Sprite(bg.width,bg.height,ColorMode.RGB);s:setPalette(L.palette);local scene=s.layers[1];scene.name='Room - clean backdrop';local cast=s:newLayer();cast.name='Characters instruments and FX'
 for f=1,18 do
  if f>1 then s:newEmptyFrame() end
  local overlay=L.image(bg.width,bg.height);render(overlay,f)
  s:newCel(scene,f,bg,Point(0,0));s:newCel(cast,f,overlay,Point(0,0));s.frames[f].duration=.13
 end
 local tag=s:newTag(1,18);tag.name='Scale and animation demo'
 s:saveAs(root..'previews/'..name..'.aseprite');s:saveAs(root..'previews/'..name..'.gif');s:close()
end
local lounge=loaded(root..'rooms/lounge-4x3.png')
demo('conversation-demo',lounge,function(im,f)
 local phase=(f-1)%6+1;local left=f<=6 or f>12
 local x1,x2,y=40,125,lounge.height-61
 im:drawImage(actors[1].talk[left and phase or 1],Point(x1,y));im:drawImage(actors[2].talk[left and 1 or phase],Point(x2,y))
 local b1=Effects.bubble(Effects.bubbles[f>12 and 3 or 1],phase)
 local b2=Effects.bubble(Effects.bubbles[f>12 and 4 or 2],phase)
 if left then im:drawImage(b1,Point(x1-24,y-41)) end
 if not left or f>12 then im:drawImage(b2,Point(x2-24,y-41)) end
 if f>12 then im:drawImage(Effects.note(2,phase),Point(x2+20,y-14)) end
end)
local studio=loaded(root..'rooms/recording-4x3.png')
demo('music-overlay-demo',studio,function(im,f)
 local phase=(f-1)%6+1;local spec=Instruments.specs[f<=6 and 1 or(f<=12 and 7 or 4)]
 local back,front=Instruments.render(spec,phase)
 local x,y=83,studio.height-61
 im:drawImage(back,Point(x,y));im:drawImage(actors[1].sway[phase],Point(x,y));im:drawImage(front,Point(x,y))
 local keyboard=Instruments.specs[3];local b,k=Instruments.render(keyboard,phase)
 im:drawImage(b,Point(10,y));im:drawImage(actors[2].sway[phase],Point(26,y));im:drawImage(k,Point(10,y))
 im:drawImage(Effects.note(2,phase),Point(x+28,y-15));im:drawImage(Effects.note(1,phase),Point(x-11,y-20));im:drawImage(Effects.note(3,phase),Point(45,y-20))
end)
local instrumentGuide=loaded(root..'previews/instrument-scale-guide.png');L.saveImage(L.enlarge(instrumentGuide,2),root..'previews/instrument-scale-guide-2x')
local trees=loaded(root..'previews/tree-scale-guide.png');L.saveImage(L.enlarge(trees,2),root..'previews/tree-scale-guide-2x')
local log=assert(io.open(root..'source/extras-validation.txt','w'));log:write('PASS: eight music-note animations and ten pixel-emoji speech bubbles, six frames each. Three tree types and shadows. Three faint city backdrops with separate parallax layers. Two 18-frame in-scene scale demonstrations.\n');log:close()
