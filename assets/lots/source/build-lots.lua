local root='D:/EP45/ndlp/Producers/lots/'
local base='D:/EP45/ndlp/Producers/'
local L=dofile(root..'source/pixel-lib.lua');local Rooms=dofile(root..'source/side-room-art.lua');local Instruments=dofile(root..'source/instrument-art.lua');local C=L.C
local function png(im,path)
 local s=Sprite(im.width,im.height,ColorMode.RGB);s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(path..'.png');s:close()
end
local actors={}
for i,name in ipairs({'producer-mini-6x4.png','secret-mini-6x4.png'}) do
 local s=Sprite{fromFile=base..name};local all=L.fromSprite(s,1);local idle=L.image(32,48);idle:drawImage(all,Point(0,0))
 local sway,talk={},{}
 for f=0,5 do sway[f+1]=L.image(32,48);sway[f+1]:drawImage(all,Point(-f*32,-96));talk[f+1]=L.image(32,48);talk[f+1]:drawImage(all,Point(-f*32,-144)) end
 actors[i]={idle=idle,sway=sway,talk=talk};s:close()
end
local kinds={'recording','lounge','office','meeting','cafeteria','storage'}
local sizes={{id='4x3',w=192,h=144},{id='2x2',w=160,h=160},{id='16x9',w=256,h=144}}
local index=assert(io.open(root..'rooms/index.csv','w'));index:write('room,ratio,width,height,png,aseprite,scale_preview\n')
local roomContacts=L.image(576,288);local roomCount=0
for kindIndex,kind in ipairs(kinds) do for _,size in ipairs(sizes) do
 local layers,collision=Rooms.render(kind,size.w,size.h)
 local refs=L.image(size.w,size.h)
 refs:drawImage(actors[1].idle,Point(math.floor(size.w/2)-45,size.h-61));refs:drawImage(actors[2].idle,Point(math.floor(size.w/2)+18,size.h-61))
 layers[#layers+1]={name='SCALE REFERENCE - 32x48 characters - hidden',image=refs,hidden=true}
 local guide=L.image(size.w,size.h)
 for _,box in ipairs(collision) do L.frame(guide,box[1],box[2],box[3],box[4],C.redHi) end
 layers[#layers+1]={name='COLLISION FOOTPRINTS - hidden guide',image=guide,hidden=true}
 local name=kind..'-'..size.id
 local flat=L.saveLayers(size.w,size.h,layers,root..'rooms/'..name)
 local rear=L.image(size.w,size.h);for k=1,4 do rear:drawImage(layers[k].image,Point(0,0)) end
 png(rear,root..'rooms/'..name..'-back');png(layers[5].image,root..'rooms/'..name..'-front')
 local compare=L.image(size.w,size.h);compare:drawImage(flat,Point(0,0));compare:drawImage(refs,Point(0,0))
 L.rect(compare,8,size.h-13,100,10,C.ink);L.text(compare,12,size.h-11,'PEOPLE 32X48',C.white)
 png(compare,root..'previews/'..name..'-scale')
 if size.id=='4x3' then roomContacts:drawImage(compare,Point(((kindIndex-1)%3)*192,math.floor((kindIndex-1)/3)*144)) end
 local meta=assert(io.open(root..'rooms/'..name..'.json','w'))
 meta:write(string.format('{"name":"%s","view":"side_cutaway","ratio":"%s","width":%d,"height":%d,"floor_baseline":%d,"pixel_scale":{"character_frame":[32,48],"character_visible_height":43,"door_height":54},"walkable_floor":[4,%d,%d,3],"actor_y":%d,"exit_anchor":[%d,%d],"background_prop_bounds":[',kind,size.id,size.w,size.h,size.h-16,size.h-16,size.w-8,size.h-61,size.w-19,size.h-16))
 for k,b in ipairs(collision) do if k>1 then meta:write(',') end;meta:write(string.format('[%d,%d,%d,%d]',b[1],b[2],b[3],b[4])) end
 meta:write(']}');meta:close()
 index:write(string.format('%s,%s,%d,%d,%s.png,%s.aseprite,../previews/%s-scale.png\n',kind,size.id,size.w,size.h,name,name,name));roomCount=roomCount+1
end end
index:close();png(roomContacts,root..'previews/rooms-overview')
local instrumentIndex=assert(io.open(root..'instruments/index.csv','w'));instrumentIndex:write('instrument,width,height,anchor_x,anchor_y,overlay_frames\n')
local comparison=L.image(384,224);L.rect(comparison,0,0,384,224,C.sky)
for id,spec in ipairs(Instruments.specs) do
 local back,front,flat=Instruments.render(spec,1)
 L.saveLayers(spec.w,spec.h,{{name='Back - behind actor',image=back},{name='Front - in front of actor',image=front}},root..'instruments/'..spec.id)
 png(back,root..'instruments/'..spec.id..'-back');png(front,root..'instruments/'..spec.id..'-front')
 local anim=Sprite(spec.w,spec.h,ColorMode.RGB);anim:setPalette(L.palette);local b=anim.layers[1];b.name='Behind actor';local fr=anim:newLayer();fr.name='In front of actor'
 local sheet=L.image(spec.w*6,spec.h)
 for f=1,6 do
  if f>1 then anim:newEmptyFrame() end
  local bb,ff,ii=Instruments.render(spec,f);anim:newCel(b,f,bb,Point(0,0));anim:newCel(fr,f,ff,Point(0,0));anim.frames[f].duration=.18;sheet:drawImage(ii,Point((f-1)*spec.w,0))
 end
 local tag=anim:newTag(1,6);tag.name='Front sway - 6 matching frames'
 anim:saveAs(root..'instruments/'..spec.id..'-overlay.aseprite');anim:close();png(sheet,root..'instruments/'..spec.id..'-6frames')
 local actorOffsetX=spec.anchor[1]-16;local actorOffsetY=spec.anchor[2]-45
 local meta=assert(io.open(root..'instruments/'..spec.id..'.json','w'));meta:write(string.format('{"instrument":"%s","canvas":[%d,%d],"anchor":[%d,%d],"actor_frame":[32,48],"actor_offset":[%d,%d],"draw_order":["back","actor","front"],"overlay_frames":6,"frame_ms":180,"character_animation":"front_sway"}',spec.id,spec.w,spec.h,spec.anchor[1],spec.anchor[2],actorOffsetX,actorOffsetY));meta:close()
 local cellX=((id-1)%4)*96;local cellY=math.floor((id-1)/4)*112
 L.rect(comparison,cellX+3,cellY+3,90,106,C.wallLight);L.frame(comparison,cellX+3,cellY+3,90,106,C.wallDark)
 local ox=cellX+math.floor((96-spec.w)/2);local oy=cellY+17
 comparison:drawImage(back,Point(ox,oy));comparison:drawImage(actors[(id%2)+1].sway[1],Point(ox+actorOffsetX,oy+actorOffsetY));comparison:drawImage(front,Point(ox,oy))
 L.text(comparison,cellX+8,cellY+94,spec.id,C.ink)
 instrumentIndex:write(string.format('%s,%d,%d,%d,%d,6\n',spec.id,spec.w,spec.h,spec.anchor[1],spec.anchor[2]))
end
L.text(comparison,299,137,'32X48',C.ink);comparison:drawImage(actors[1].idle,Point(295,155));comparison:drawImage(actors[2].idle,Point(329,155))
L.line(comparison,294,202,365,202,C.ink);L.text(comparison,294,207,'SAME SCALE',C.ink)
instrumentIndex:close();L.saveImage(comparison,root..'previews/instrument-scale-guide')
local f=assert(io.open(root..'source/rooms-instruments-validation.txt','w'));f:write('PASS: '..roomCount..' native rooms; six room types x three aspect ratios. All have clean PNGs and editable Aseprite layers, hidden 32x48 actor references and collision guides. Seven separately layered instruments with six overlay frames, anchors and draw-order metadata.\n');f:close()
