-- Native Aseprite wardrobe pass: short skirts, preserving all head/upper-body frames.
local root="D:/GitHub/TheProducers/"
local work="D:/EP45/ndlp/Producers/Short-skirts/"
app.fs.makeAllDirectories(work)
local pc=app.pixelColor
local meta=json.decode(assert(io.open(root.."tools/sprites/native_palette.json")):read("*a"))
local cast={
 {"npc-16-female-sidesweep","white",{"afa9b3","edeae5","fffaf0"}},
 {"npc-24-female-highpony","denim",{"2a425f","507f9d","81a9bb"}},
 {"super-02","black",{"14141d","282733","494652"}}
}
local function hex(s)return pc.rgba(tonumber(s:sub(1,2),16),tonumber(s:sub(3,4),16),tonumber(s:sub(5,6),16),255)end
local function rgb(c)return pc.rgba(c[1],c[2],c[3],255)end
local ink=hex("2e222f")
local gallery=Image(1280,960)
local checked=0
for row,spec in ipairs(cast)do
 local id,kind,colors=spec[1],spec[2],spec[3]
 local path=root.."sources/sprites/"..id..".aseprite"
 local backup=work..id.."-before.aseprite"
 local sprite=app.open(app.fs.isFile(backup)and backup or path)
 if not app.fs.isFile(backup)then sprite:saveAs(backup)end
 local layer
 for _,l in ipairs(sprite.layers)do if l.name=="Body and clothing"then layer=l end end
 assert(layer)
 local originals={}
 for frame=1,36 do local cel=layer:cel(frame);local im=Image(160,160);im:drawImage(cel.image,cel.position);originals[frame]=im end
 local pants,skin={},meta.characters[id].ramps[4]
 for tone,c in ipairs(meta.characters[id].ramps[3])do pants[rgb(c)]=tone end
 local shades={hex(colors[1]),hex(colors[2]),hex(colors[3])}
 local total=0
 for a,anim in ipairs({"idle","walk","talk","play"})do
  local sheet=Image(480,480)
  for f=0,8 do
   total=total+1
   local c=layer:cel(total)
   local original=originals[total]
   local im=Image(original)
   local top=160
   for y=78,110 do
    local count,l,r=0,160,0
    for x=40,115 do if pants[original:getPixel(x,y)]then count=count+1;l=math.min(l,x);r=math.max(r,x)end end
    if count>=8 and r-l>=12 then top=y;break end
   end
   assert(top<105,id.." missing waist")
   local left,right=160,0
   for y=top,top+4 do for x=40,115 do if pants[original:getPixel(x,y)]then left=math.min(left,x);right=math.max(right,x)end end end
   local hem=top+14
   if f==4 then print(id.." "..anim.." waist="..top.." bounds="..left..","..right)end
   -- Rebuild bare legs: remove trouser outlines/seams, narrow the silhouette.
   local shoe={}
   for _,v in ipairs(meta.characters[id].ramps[6])do shoe[rgb(v)]=true end
   for y=hem-2,136 do
    local runs={};local start=nil
    for x=34,126 do
     local isleg=pants[original:getPixel(x,y)]~=nil
     if isleg and not start then start=x end
     if start and(not isleg or x==126)then
      table.insert(runs,{start,x-1});start=nil
     end
    end
    -- Join fragments separated by a dark trouser seam, but retain the leg gap.
    local joined={}
    for _,r in ipairs(runs)do
     local prev=joined[#joined]
     if prev and r[1]-prev[2]<=3 and pc.rgbaA(original:getPixel(prev[2]+1,y))>0 then prev[2]=r[2]
     else table.insert(joined,{r[1],r[2]})end
    end
    for _,r in ipairs(joined)do
     local l,rr=r[1],r[2]
     for x=l-1,rr+1 do
      local p=original:getPixel(x,y)
      if pants[p]or p==ink then im:drawPixel(x,y,0)end
     end
     local inset=(rr-l>=7 and y>hem+1)and 1 or 0
     l=l+inset;rr=rr-inset
     for x=l,rr do
      if not shoe[original:getPixel(x,y)]then
       local color=rgb(skin[3])
       if x==rr then color=rgb(skin[2]) elseif x==l then color=rgb(skin[4])end
       im:drawPixel(x,y,color)
      end
     end
    end
   end
   -- A-line silhouette with three flat tones and stepped side seams.
   for y=top-1,hem do
    local flare=math.min(1,math.floor((y-top+1)/8))
    local l,r=left-flare,right+flare
    if y>=hem-1 then l=l+1;r=r-1 end
    for x=l,r do
     local p=original:getPixel(x,y)
     -- Keep hands and shirt tails in front of the skirt.
     if pc.rgbaA(p)==0 or pants[p]or p==ink then
      local color=shades[2]
      if x==l or x==r or y==hem then color=ink
      elseif y==top-1 or y==hem-1 or x>=r-3 then color=shades[1]
      elseif x<=l+2 then color=shades[3]
      elseif kind~="denim"and(x==left+5 or x==right-4)and y>top+3 then color=shades[1]
      elseif kind=="denim"and y==hem-2 then color=shades[3]end
      im:drawPixel(x,y,color)
     end
    end
   end
   -- Confirm the change never reaches the head or upper torso.
   for y=0,top-2 do for x=0,159 do assert(im:getPixel(x,y)==original:getPixel(x,y),id.." upper body changed")end end
   c.image=im;c.position=Point(0,0)
   local merged=Image(160,160);merged:drawSprite(sprite,total)
   sheet:drawImage(merged,Point(f%3*160,f//3*160))
   checked=checked+1
   if f==4 then
    for y=0,159 do for x=0,159 do
     local p=merged:getPixel(x,y)
     if pc.rgbaA(p)==0 then p=pc.rgba(25,38,54,255)end
     for yy=0,1 do for xx=0,1 do gallery:drawPixel((a-1)*320+x*2+xx,(row-1)*320+y*2+yy,p)end end
    end end
   end
  end
  sheet:saveAs(root.."assets/sprites/"..id.."/"..anim..".png")
 end
 sprite:saveAs(path);sprite:close()
 print(id.." -> "..kind)
end
gallery:saveAs(work.."preview.png")
local path=root.."assets/sprites/manifest.json"
local cfg=json.decode(assert(io.open(path)):read("*a"))
for _,spec in ipairs(cast)do cfg.characters[spec[1]].bottom={type="short_skirt",material=spec[2],palette=spec[3]}end
local file=assert(io.open(path,"w"));file:write(json.encode(cfg));file:close()
print("CHECKED "..checked.." frames; head and upper torso unchanged")
