-- Shared foliage vocabulary: stepped leaf masses, three flat green tones, exposed branches.
local L=dofile('D:/GitHub/TheProducers/assets/lots/source/pixel-lib.lua')
local G={}
function G.draw(w,h,variant,potted)
 local im=L.image(w,h);local green={L.color('3e6957'),L.color('73a66a'),L.color('b6d58b')}
 local bark={L.color('55423e'),L.color('99745a'),L.color('c6a17b')}
 local function poly(points,color)local q={};for _,p in ipairs(points)do q[#q+1]={math.floor(p[1]*w/100),math.floor(p[2]*h/100)}end;L.poly(im,q,color)end
 local function mass(x,y,sx,sy)
  local function shape(points,color)local q={};for _,p in ipairs(points)do q[#q+1]={x+p[1]*sx/100,y+p[2]*sy/100}end;poly(q,color)end
  shape({{0,48},{8,48},{8,28},{21,28},{21,15},{37,15},{37,3},{53,3},{53,11},{70,11},{70,23},{84,23},{84,36},{95,36},{95,53},{100,53},{100,78},{89,78},{89,91},{69,91},{69,100},{43,100},{43,92},{20,92},{20,83},{7,83},{7,68},{0,68}},green[1])
  shape({{4,46},{12,46},{12,29},{25,29},{25,18},{40,18},{40,7},{51,7},{51,15},{68,15},{68,27},{81,27},{81,40},{92,40},{92,55},{97,55},{97,72},{82,72},{82,83},{63,83},{63,90},{44,90},{44,80},{23,80},{23,72},{9,72}},green[2])
  shape({{9,47},{16,47},{16,30},{29,30},{29,20},{43,20},{43,11},{49,11},{49,24},{38,24},{38,36},{26,36},{26,49},{17,49},{17,58},{9,58}},green[3])
  shape({{55,18},{66,18},{66,30},{79,30},{79,44},{87,44},{87,55},{76,55},{76,46},{64,46},{64,34},{55,34}},green[3])
  shape({{28,60},{39,60},{39,70},{50,70},{50,80},{40,80},{40,74},{28,74}},green[1])
  -- Broken highlight patches instead of a continuous band around every clump.
  for j=0,5 do
   local px=18+(j*19+variant*7)%57;local py=22+(j*13)%38
   shape({{px,py},{px+6,py},{px+6,py-5},{px+13,py-5},{px+13,py+3},{px+18,py+3},{px+18,py+9},{px+10,py+9},{px+10,py+14},{px+3,py+14},{px+3,py+6},{px,py+6}},green[3])
  end
 end
 if potted then
  local lean=variant%3
  poly({{43,82},{46,68},{34,57},{37,46},{51,37},{54,23},{60,24},{56,42},{44,51},{45,57},{57,67},{55,82}},bark[1])
  poly({{48,81},{51,69},{39,56},{41,48},{54,39},{58,27},{58,39},{46,51},{49,58},{60,68},{56,81}},bark[2])
  poly({{52,77},{54,69},{44,57},{46,53},{51,60},{59,68},{55,78}},bark[3])
  poly({{42,54},{23,47},{20,40},{24,41},{29,46},{46,49}},bark[2])
  if lean==0 then mass(13,14,70,24);mass(3,40,51,23);mass(48,53,47,18)
  elseif lean==1 then mass(28,11,60,25);mass(5,39,53,25);mass(53,45,42,23)
  else mass(19,15,65,26);mass(3,45,49,21);mass(49,48,46,23)end
  local tall=variant%2==0
  local bottom=tall and 97 or 93
  poly({{17,80},{83,80},{77,bottom},{25,bottom}},bark[1]);poly({{23,82},{80,82},{75,bottom-2},{42,bottom-2},{34,89}},bark[2]);poly({{63,83},{76,83},{73,bottom-3},{68,bottom-3}},bark[3])
  poly({{12,78},{88,78},{88,82},{80,82},{80,85},{20,85},{20,82},{12,82}},bark[2]);poly({{12,78},{88,78},{88,80},{12,80}},bark[3])
 else
  -- Flared roots and open Y branches, readable at the same native pixel grid as actors.
  poly({{21,99},{36,94},{42,85},{44,69},{33,58},{23,46},{27,40},{35,52},{46,59},{48,31},{55,29},{55,56},{66,46},{74,34},{79,37},{73,50},{57,65},{56,85},{63,94},{79,99}},bark[1])
  poly({{29,97},{42,90},{47,72},{46,65},{35,55},{30,46},{38,53},{50,60},{51,32},{54,32},{53,60},{68,48},{75,39},{70,51},{53,67},{51,84},{58,94},{69,98},{54,95},{47,89},{42,95}},bark[2])
  poly({{48,87},{48,73},{51,69},{51,85},{56,91},{61,94},{56,94}},bark[3])
  poly({{49,58},{52,41},{54,37},{53,56}},bark[3])
  poly({{38,55},{32,45},{35,46},{42,56}},bark[3])
  poly({{45,81},{46,75},{49,75},{48,82}},bark[1])
  poly({{50,68},{54,65},{54,72},{51,75}},bark[1])
  if variant%3==1 then
   mass(20,2,60,29);mass(4,18,48,30);mass(49,17,47,31);mass(0,34,38,26);mass(67,36,33,24)
  elseif variant%3==2 then
   mass(26,1,53,31);mass(8,21,45,31);mass(51,21,46,32);mass(0,39,36,22);mass(70,39,30,25)
  else
   mass(17,2,60,30);mass(2,21,48,31);mass(48,20,49,31);mass(0,40,35,22);mass(65,39,35,26)
  end

 end
 return im
end
return G
