-- Head-only replacement from each character's original 2x2 portrait.
-- Uses native Aseprite pixel reads/writes, nearest sampling and a tapered source jaw.
local root="D:/GitHub/TheProducers/"
local work="D:/EP45/ndlp/Producers/Sprites-heads-v2/"
app.fs.makeAllDirectories(work)
local meta=json.decode(assert(io.open(root.."tools/sprites/native_palette.json")):read("*a"))
local pc=app.pixelColor
local ids={}
for id in pairs(meta.characters)do ids[#ids+1]=id end
table.sort(ids)
local gallery=Image(1024,704)
local only=app.params["only"]
local male={}
for _,anim in ipairs({"idle","walk","talk","play"})do
 local stable="D:/EP45/ndlp/Producers/Sprites-right/male/"..anim..".png"
 local path=app.fs.isFile(stable)and stable or root.."assets/sprites/male/"..anim..".png"
 male[anim]=Image{fromFile=path}
end
for n,id in ipairs(ids)do if not only or id==only then
 local e=meta.characters[id]
 local reference=app.open(root..e.reference_portrait:gsub("res://",""))
 local ref=Image(reference.width,reference.height,ColorMode.RGB)
 ref:drawSprite(reference,1)
 reference:close()
 local source=root.."sources/sprites/"..id..".aseprite"
 local backup=work..id..".aseprite"
 local sprite=app.open(app.fs.isFile(backup)and backup or source)
 if not app.fs.isFile(backup)then sprite:saveAs(backup)end
 local body,head
 for _,layer in ipairs(sprite.layers)do if layer.name=="Body and clothing"then body=layer elseif layer.name=="Face and hair"then head=layer end end
 assert(head and body,"Missing layered source: "..id)
 local total=0
 for _,anim in ipairs({"idle","walk","talk","play"})do
  local sheet=Image(480,480)
  for f=0,8 do
   total=total+1
   local off=meta.offsets[anim][f+1]
   local dx,dy=off[1],off[2]
   local replacement=Image(160,160)
   local previous=head:cel(total)
   local original=Image(160,160)
   original:drawImage(previous.image,previous.position)
   -- Keep the neck seam and any raised hand outside the head silhouette.
   for x=72+dx,85+dx do replacement:drawPixel(x,47+dy,original:getPixel(x,47+dy))end
   for y=0,46+dy do for x=0,159 do
    if x<61+dx or x>98+dx then
     local p=original:getPixel(x,y)
     for _,skin in ipairs(e.ramps[4])do
      if p==pc.rgba(skin[1],skin[2],skin[3],255)then replacement:drawPixel(x,y,p)end
     end
    end
   end end
   local expression=(anim=="idle"and f==4)and 2 or (anim=="talk"and f%2==1)and 1 or 0
   -- Reduce the previous head by 9%, tuck the chin 2px left and 1px down
   -- into the existing collar. The body and its neck seam stay registered.
   for y=15,47+dy do for x=45,110 do
    -- Portraits face right; mirror around the chin to match the left-facing body.
    local sx=math.floor(38-(x-77-dx)/0.50+0.5)
    local sy=math.floor(48+(y-47-dy)/0.50+0.5)
    if sx>=0 and sx<64 and sy>=0 and sy<=48 then
     local p=ref:getPixel(sx+(expression%2)*64,sy+(expression//2)*64)
     if pc.rgbaA(p)>0 then replacement:drawPixel(x,y,pc.rgba(pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p),255))end
    end
   end end
   head:cel(total).image=replacement
   head:cel(total).position=Point(0,0)
   -- Long hair from the old head had been baked into the body layer.
   -- Remove that material and its outline, restoring the underlying garment
   -- from the original pose using this character's existing color mapping.
   local bc=body:cel(total)
   local clean=Image(160,160);clean:drawImage(bc.image,bc.position)
   local oldhair={}
   for _,tone in ipairs(e.ramps[5])do oldhair[pc.rgba(tone[1],tone[2],tone[3],255)]=true end
   local ink=pc.rgba(46,34,47,255)
   local mask={};local frequencies={}
   local function sourcePixel(x,y)return male[anim]:getPixel((f%3)*160+x,(f//3)*160+y)end
   for y=48+dy,80+dy do for x=40,115 do
    local p=clean:getPixel(x,y)
    if ((e.style.below or 0)>0 or (e.style.extra or 0)>0) and oldhair[p]then mask[y*160+x]=true end
    local sp=sourcePixel(x,y)
    if pc.rgbaA(sp)>0 and pc.rgbaA(p)>0 and not oldhair[p]then
     frequencies[sp]=frequencies[sp]or{};frequencies[sp][p]=(frequencies[sp][p]or 0)+1
    end
   end end
   local mapping={}
   for sp,counts in pairs(frequencies)do local best=0;for p,count in pairs(counts)do if count>best then best=count;mapping[sp]=p end end end
   local expand={}
   for index in pairs(mask)do
    local x=index%160;local y=index//160
    for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local xx,yy=x+delta[1],y+delta[2]
     if yy>=48+dy and clean:getPixel(xx,yy)==ink then expand[yy*160+xx]=true end
    end
   end
   for index in pairs(expand)do mask[index]=true end
   for index in pairs(mask)do
    local x=index%160;local y=index//160;local sp=sourcePixel(x,y)
    clean:drawPixel(x,y,pc.rgbaA(sp)==0 and 0 or(mapping[sp]or ink))
   end
   bc.image=clean;bc.position=Point(0,0)
   local merged=Image(160,160)
   merged:drawImage(clean)
   merged:drawImage(replacement)
   sheet:drawImage(merged,Point((f%3)*160,(f//3)*160))
   if anim=="idle"and f==0 then
    local gx=((n-1)%8)*128;local gy=((n-1)//8)*176
    for y=0,175 do for x=0,127 do gallery:drawPixel(gx+x,gy+y,pc.rgba(25,38,54,255))end end
    gallery:drawImage(merged,Point(gx-16,gy))
   end
  end
  sheet:saveAs(root.."assets/sprites/"..id.."/"..anim..".png")
 end
 sprite:saveAs(source);sprite:close()
 print("HEAD "..n.."/31 "..id)
end end
gallery:saveAs(work.."gallery.png")
if not only then
 local path=root.."assets/sprites/manifest.json"
 local cfg=json.decode(assert(io.open(path)):read("*a"))
 cfg.default_facing="left"
 local file=assert(io.open(path,"w"));file:write(json.encode(cfg));file:close()
end
