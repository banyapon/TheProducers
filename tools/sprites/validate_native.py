import json,struct,hashlib
from pathlib import Path
from PIL import Image
root=Path("assets/sprites")
manifest=json.loads((root/"manifest.json").read_text())
counts={"characters":0,"sheets":0,"frames":0,"sources":0}
bad=[]
for id,e in manifest["characters"].items():
 counts["characters"]+=1
 for anim in manifest["animations"]:
  path=root/id/(anim+".png")
  im=Image.open(path).convert("RGBA");counts["sheets"]+=1
  if im.size!=(480,480):bad.append(str(path)+" dimensions")
  if set(im.getchannel("A").getdata())-{0,255}:bad.append(str(path)+" soft alpha")
  for f in range(9):
   cell=im.crop((f%3*160,f//3*160,f%3*160+160,f//3*160+160))
   b=cell.getbbox();counts["frames"]+=1
   if not b or b[0]<=0 or b[1]<=0 or b[2]>=160 or b[3]>=160:bad.append(str(path)+" clipped frame "+str(f))
 data=Path(e["source"]).read_bytes()
 if struct.unpack_from("<H",data,4)[0]!=0xA5E0 or struct.unpack_from("<HHH",data,6)!=(36,160,160):bad.append(e["source"]+" invalid native source")
 else:counts["sources"]+=1
print(counts);print("ERRORS",bad)
Path("D:/EP45/ndlp/Producers/Sprites-native-review/validation.json").write_text(json.dumps({"counts":counts,"errors":bad},indent=2))
assert not bad
