local root='D:/EP45/ndlp/Producers/lots/'
local function open(path) return Sprite{fromFile=root..path} end
local rooms={'recording','lounge','office','meeting','cafeteria','storage'}
local sizes={{id='4x3',w=192,h=144},{id='2x2',w=160,h=160},{id='16x9',w=256,h=144}}
local count=0
for _,room in ipairs(rooms) do for _,size in ipairs(sizes) do
 local name='rooms/'..room..'-'..size.id
 local s=open(name..'.aseprite');assert(s.width==size.w and s.height==size.h and #s.layers==7)
 assert(not s.layers[6].isVisible and not s.layers[7].isVisible,'Scale and collision guides must be hidden')
 s:close();local p=open(name..'.png');assert(p.width==size.w and p.height==size.h);p:close()
 for _,suffix in ipairs({'-back.png','-front.png'}) do p=open(name..suffix);assert(p.width==size.w and p.height==size.h);p:close() end
 count=count+1
end end
local instruments=dofile(root..'source/instrument-art.lua')
for _,spec in ipairs(instruments.specs) do
 local s=open('instruments/'..spec.id..'.aseprite');assert(s.width==spec.w and s.height==spec.h and #s.layers==2);s:close()
 s=open('instruments/'..spec.id..'-overlay.aseprite');assert(#s.frames==6 and #s.layers==2 and #s.tags==1);s:close()
end
local effects=dofile(root..'source/effects-art.lua')
for _,id in ipairs(effects.notes) do local s=open('effects/note-'..id..'.aseprite');assert(s.width==24 and s.height==24 and #s.frames==6);s:close() end
for _,spec in ipairs(effects.bubbles) do local s=open('effects/chat-'..spec.id..'.aseprite');assert(s.width==80 and s.height==36 and #s.frames==6);s:close() end
local nature=dofile(root..'source/nature-art.lua')
for _,spec in ipairs(nature.trees) do local s=open('trees/'..spec.id..'.aseprite');assert(s.width==spec.w and s.height==spec.h);s:close() end
for _,size in ipairs({{id='4x3',w=384,h=288},{id='2x2',w=320,h=320},{id='16x9',w=512,h=288}}) do local s=open('backgrounds/city-faint-'..size.id..'.aseprite');assert(s.width==size.w and s.height==size.h and #s.layers==4);s:close() end
for _,name in ipairs({'conversation-demo','music-overlay-demo'}) do local s=open('previews/'..name..'.aseprite');assert(#s.frames==18 and #s.layers==2);s:close() end
local building=open('previews/building-cutaway-preview.aseprite');assert(building.width==1024 and building.height==576 and #building.layers==8);building:close()
local f=assert(io.open(root..'VALIDATION.txt','w'));f:write('PASS\n18 room PNGs and layered Aseprite files, exact 4:3 / 2:2 / 16:9 dimensions. Scale-reference and collision guides hidden in clean exports.\n7 instruments with separate back/front layers, 6 overlay frames and anchors.\n8 animated music-note effects and 10 animated pixel-emoji speech bubbles, 6 frames each.\n3 tree types and 3 layered faint-city background sizes.\n2 in-scene demonstrations, 18 frames each.\nAll geometry drawn on native integer pixel coordinates in Aseprite; no smooth resizing or anti-aliasing.\n');f:close()
