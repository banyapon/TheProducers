-- Native Aseprite finishing pass over the existing character drafts.
-- Keeps male motion/160px registration; redraws pixels using three-tone ramps.
-- Does not claim that the input drafts were manually painted.
local root="D:/GitHub/TheProducers/"
local work="D:/EP45/ndlp/Producers/Sprites-native-review/"
local meta=json.decode(assert(io.open(root.."tools/sprites/native_palette.json")):read("*a"))
local pc=app.pixelColor
local function rgba(c)return pc.rgba(c[1],c[2],c[3],255)end
local function read(path)return Image{fromFile=path}end
local ids={}
for id in pairs(meta.characters)do ids[#ids+1]=id end
table.sort(ids)
local gallery=Image(1024,704)
local manifest={cell={160,160},grid={3,3},anchor={80,137},animations={"idle","walk","talk","play"},fps={idle=5,walk=9,talk=9,play=9},characters={},gallery_order=ids,
workflow="Existing pose-based drafts finished pixel-by-pixel through Aseprite Lua; three-tone material ramps; layered native sources."}
local font={A={"010","101","111","101","101"},N={"101","111","111","111","101"},V={"101","101","101","101","010"},
["0"]={"111","101","101","101","111"},["1"]={"010","110","010","010","111"},["2"]={"110","001","010","100","111"},["3"]={"110","001","010","001","110"},["4"]={"101","101","111","001","001"},["5"]={"111","100","110","001","110"},["6"]={"011","100","111","101","111"},["7"]={"111","001","010","010","010"},["8"]={"111","101","111","101","111"},["9"]={"111","101","111","001","110"}}
local function label(im,text,x,y)
 for n=1,#text do local glyph=font[text:sub(n,n)];if glyph then for yy=1,5 do for xx=1,3 do if glyph[yy]:sub(xx,xx)=="1"then im:drawPixel(x+(n-1)*4+xx,y+yy,pc.rgba(239,203,119,255))end end end end end
end
for n,id in ipairs(ids)do
 local entry=meta.characters[id]
 local target=root.."assets/sprites/"..id.."/"
 local backup=work.."draft-backup/"..id.."/"
 app.fs.makeAllDirectories(backup)
 -- Keep exact earlier sheets available for comparison and recovery.
 local input={}
 for _,anim in ipairs(manifest.animations)do
  input[anim]=read(app.fs.isFile(backup..anim..".png") and backup..anim..".png" or target..anim..".png")
  if not app.fs.isFile(backup..anim..".png")then input[anim]:saveAs(backup..anim..".png")end
 end
 local mapping={}
 for _,ramp in ipairs(entry.ramps)do
  mapping[rgba(ramp[1])]=rgba(ramp[1])
  mapping[rgba(ramp[2])]=rgba(ramp[1])
  mapping[rgba(ramp[3])]=rgba(ramp[3])
  mapping[rgba(ramp[4])]=rgba(ramp[4])
 end
 local sprite=Sprite(160,160,ColorMode.RGB)
 sprite.layers[1].name="Body and clothing"
 local body=sprite.layers[1]
 local head=sprite:newLayer();head.name="Face and hair"
 local frames=0
 for _,anim in ipairs(manifest.animations)do
  local output=Image(480,480)
  local first=frames+1
  for f=0,8 do
   frames=frames+1
   local frame=frames==1 and sprite.frames[1] or sprite:newEmptyFrame(frames)
   frame.duration=1/manifest.fps[anim]
   local b,h=Image(160,160),Image(160,160)
   local off=meta.offsets[anim][f+1]
   for y=0,159 do for x=0,159 do
    local p=input[anim]:getPixel((f%3)*160+x,(f//3)*160+y)
    if pc.rgbaA(p)>0 then
     p=mapping[p]or p
     -- Solid alpha and one native pixel per drawing operation; no filtered edges.
     p=pc.rgba(pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p),255)
     if y<48+off[2] then h:drawPixel(x,y,p)else b:drawPixel(x,y,p)end
    end
   end end
   -- Redraw stepped hair strands inside the silhouette, avoiding face and glasses.
   if not entry.style.bald then
    local hair=entry.ramps[5];local mask={}
    for _,tone in ipairs(hair)do mask[rgba(tone)]=true end
    local left,right,top=160,0,160
    for y=0,60 do for x=35,120 do if mask[h:getPixel(x,y)]then left=math.min(left,x);right=math.max(right,x);top=math.min(top,y)end end end
    if right-left>8 then
     local light=rgba(hair[4]);local shade=rgba(hair[1])
     for x=left+4,right-4 do
      local y=top+3+math.floor(math.abs(x-(left+right)/2)/5)
      if mask[h:getPixel(x,y)] and mask[h:getPixel(x,y+1)]then
       h:drawPixel(x,y,light)
       if x%4==0 and mask[h:getPixel(x,y+2)]then h:drawPixel(x,y+2,shade)end
      end
     end
     for y=top+7,math.min(top+14,46+off[2])do
      local x=left+4+math.floor((y-top-7)/3)
      if mask[h:getPixel(x,y)]then h:drawPixel(x,y,light)end
     end
    end
   end
   sprite:newCel(body,frames,b,Point(0,0))
   sprite:newCel(head,frames,h,Point(0,0))
   local merged=Image(160,160);merged:drawImage(b);merged:drawImage(h)
   output:drawImage(merged,Point((f%3)*160,(f//3)*160))
   if anim=="idle" and f==0 then
    local gx=((n-1)%8)*128;local gy=((n-1)//8)*176
    for y=0,175 do for x=0,127 do gallery:drawPixel(gx+x,gy+y,pc.rgba(25,38,54,255))end end
    gallery:drawImage(merged,Point(gx-16,gy))
    label(gallery,id=="alice" and "A"or(id:sub(1,3)=="npc"and"N"..id:sub(5,6)or"V"..id:sub(7,8)),gx+58,gy+160)
   end
  end
  local tag=sprite:newTag(first,frames);tag.name=anim
  output:saveAs(target..anim..".png")
 end
 local source=root.."sources/sprites/"..id..".aseprite"
 if app.fs.isFile(source)and not app.fs.isFile(backup..id..".aseprite")then
  local original=app.open(source);original:saveAs(backup..id..".aseprite");original:close()
 end
 sprite:saveAs(source);sprite:close()
 manifest.characters[id]={path="res://assets/sprites/"..id.."/",source="sources/sprites/"..id..".aseprite",reference_world=entry.reference_world,reference_portrait=entry.reference_portrait}
 print("FINISHED "..n.."/31 "..id)
end
gallery:saveAs(work.."cast-gallery.png")
local out=assert(io.open(root.."assets/sprites/manifest.json","w"));out:write(json.encode(manifest));out:close()
print("DONE: 31 characters, 124 sheets, 1116 frames")
