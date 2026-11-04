-- Final orientation stage. Run after refine_heads.lua.
local root="D:/GitHub/TheProducers/"
local work="D:/EP45/ndlp/Producers/Sprites-right/"
app.fs.makeAllDirectories(work.."left")
app.fs.makeAllDirectories(work.."male")
local path=root.."assets/sprites/manifest.json"
local cfg=json.decode(assert(io.open(path)):read("*a"))
local ids={}
for id in pairs(cfg.characters)do if id~="male"then ids[#ids+1]=id end end
table.sort(ids);table.insert(ids,1,"male")
local pc=app.pixelColor
local gallery=Image(1024,704)
for n,id in ipairs(ids)do
 local original
 if id=="male"then
  original=Sprite(160,160,ColorMode.RGB)
  original.layers[1].name="Original male"
  local total=0
  for _,anim in ipairs(cfg.animations)do
   local backup=work.."male/"..anim..".png"
   local im=Image{fromFile=app.fs.isFile(backup)and backup or root.."assets/sprites/male/"..anim..".png"}
   if not app.fs.isFile(backup)then im:saveAs(backup)end
   for f=0,8 do
    total=total+1
    local frame=total==1 and original.frames[1]or original:newEmptyFrame(total)
    frame.duration=1/cfg.fps[anim]
    local cell=Image(160,160);cell:drawImage(im,Point(-(f%3)*160,-(f//3)*160))
    original:newCel(original.layers[1],total,cell,Point(0,0))
   end
  end
 else
  local stable=work.."left/"..id..".aseprite"
  local source=root.."sources/sprites/"..id..".aseprite"
  original=app.open(cfg.default_facing=="right"and stable or source)
  if cfg.default_facing~="right"then original:saveAs(stable)end
 end
 local sprite=Sprite(160,160,ColorMode.RGB)
 for i,layer in ipairs(original.layers)do
  local dest=i==1 and sprite.layers[1]or sprite:newLayer()
  dest.name=layer.name
 end
 for f=1,36 do
  local frame=f==1 and sprite.frames[1]or sprite:newEmptyFrame(f)
  frame.duration=original.frames[f].duration
  for i,layer in ipairs(original.layers)do
   local c=layer:cel(f)
   if c then
    local im=Image(160,160);im:drawImage(c.image,c.position)
    local flipped=Image(160,160)
    for y=0,159 do for x=0,159 do flipped:drawPixel(159-x,y,im:getPixel(x,y))end end
    sprite:newCel(sprite.layers[i],f,flipped,Point(0,0))
   end
  end
 end
 for a,anim in ipairs(cfg.animations)do
  local sheet=Image(480,480)
  local tag=sprite:newTag((a-1)*9+1,a*9);tag.name=anim
  for f=0,8 do
   local cell=Image(160,160);cell:drawSprite(sprite,(a-1)*9+f+1)
   sheet:drawImage(cell,Point(f%3*160,f//3*160))
   if a==1 and f==0 then
    local gx=(n-1)%8*128;local gy=(n-1)//8*176
    for y=0,175 do for x=0,127 do gallery:drawPixel(gx+x,gy+y,pc.rgba(25,38,54,255))end end
    gallery:drawImage(cell,Point(gx-16,gy))
   end
  end
  sheet:saveAs(root.."assets/sprites/"..id.."/"..anim..".png")
 end
 sprite:saveAs(root.."sources/sprites/"..id..".aseprite")
 original:close();sprite:close()
 print("RIGHT "..n.."/32 "..id)
end
cfg.default_facing="right";cfg.head_facing="right";cfg.head_revision=4
cfg.head_anchor={82,47}
cfg.head_reference="Original 2x2 portraits at 50 percent; legacy hair removed from clothing, whole frame mirrored to right."
cfg.characters.male={path="res://assets/sprites/male/",source="sources/sprites/male.aseprite"}
cfg.gallery_order=ids
local file=assert(io.open(path,"w"));file:write(json.encode(cfg));file:close()
gallery:saveAs(work.."gallery.png")
print("DONE 32 characters / 128 sheets / 1152 frames, right-facing")
