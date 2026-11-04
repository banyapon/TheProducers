-- Assembles build_character_sprites.py output in Aseprite.
-- For each character: a tagged 36-frame source, and the 3x3 sheets the game loads.
--
--   aseprite -b --script-param raw=<raw dir> --script-param sheets=assets/sprites \
--            --script-param sources=sources/sprites --script tools/sprites/assemble_sprites.lua
local raw = app.params["raw"]
local sheets = app.params["sheets"]
local sources = app.params["sources"]
local CELL = 160
local ANIMS = { "idle", "walk", "talk", "play" }
local DURATION = { idle = 0.2, walk = 0.111, talk = 0.111, play = 0.111 }

app.fs.makeAllDirectories(sources)
local built = 0
for _, id in ipairs(app.fs.listFiles(raw)) do
  local dir = app.fs.joinPath(raw, id)
  if app.fs.isDirectory(dir) then
    local sprite = Sprite(CELL, CELL, ColorMode.RGB)
    sprite.layers[1].name = id
    local layer = sprite.layers[1]
    local target = app.fs.joinPath(sheets, id)
    app.fs.makeAllDirectories(target)
    local total = 0
    for _, animation in ipairs(ANIMS) do
      local source = Image { fromFile = app.fs.joinPath(dir, animation .. ".png") }
      local first = total + 1
      local out = Image(CELL * 3, CELL * 3, ColorMode.RGB)
      for index = 0, 8 do
        total = total + 1
        local frame = total == 1 and sprite.frames[1] or sprite:newEmptyFrame(total)
        frame.duration = DURATION[animation]
        local cell = Image(CELL, CELL, ColorMode.RGB)
        local x, y = (index % 3) * CELL, (index // 3) * CELL
        cell:drawImage(source, Point(-x, -y))
        sprite:newCel(layer, total, cell, Point(0, 0))
        out:drawImage(cell, Point(x, y))
      end
      local tag = sprite:newTag(first, total)
      tag.name = animation
      out:saveAs(app.fs.joinPath(target, animation .. ".png"))
    end
    sprite:saveAs(app.fs.joinPath(sources, id .. ".aseprite"))
    sprite:close()
    built = built + 1
  end
end
print("assembled " .. built .. " characters")
