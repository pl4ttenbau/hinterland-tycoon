"""Implement the approved Stapelburg connection and reserve its castle site."""
from pathlib import Path
import json,re,copy,zipfile,hashlib,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent
assert not (OUT/'applied.json').exists(),'Already applied'
files=['jsondata/roads.json','mapscenes/editorobjects_harzmountains.tscn','mapscenes/world_harzmountains.tscn'];before={f:(ROOT/f).read_bytes() for f in files}
guarded=[*ROOT.glob('heightdata/*.res'),*ROOT.glob('vegetation/*'),ROOT/'mapscenes/terrain/terrain_harzmountains.tscn'];hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in guarded if p.is_file()}
original=json.loads(before[files[0]]);by={int(r['num']):copy.deepcopy(r) for r in original};assert len(by)==318 and max(by)==329
height=np.fromfile('/tmp/stapel_infill_06_00.rf',np.float32).reshape(256,256)
def h(x,z):
 ix,iz=math.floor(x)-1536,math.floor(z);fx=x-math.floor(x);fz=z-math.floor(z)
 return float((height[iz,ix]*(1-fx)+height[iz,ix+1]*fx)*(1-fz)+(height[iz+1,ix]*(1-fx)+height[iz+1,ix+1]*fx)*fz)
def point(x,z):return [x,round(h(x,z)+.2,2),z]
A=copy.deepcopy(by[102]['points'][0]['pos']);B=copy.deepcopy(by[203]['points'][-1]['pos']);J=point(1650.,99.);church=point(1646.,68.)
changed=set();removed=set();new_ids=[];nextid=max(by)+1

def add(name,controls):
 global nextid
 a=np.array(controls,float);samples=[]
 for i in range(len(a)-1):
  p,q=a[i:i+2];m=(q-a[max(0,i-1)])*.35;k=(a[min(len(a)-1,i+2)]-p)*.35
  for t in np.linspace(0,1,max(2,int(np.linalg.norm(q[::2]-p[::2])/2)+1))[:-1]:
   samples.append((2*t**3-3*t*t+1)*p+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*q+(t**3-t*t)*k)
 samples.append(a[-1]);ps=[{'pos':point(round(float(v[0]),2),round(float(v[2]),2))} for v in samples]
 for i,target in [(0,a[0]),(-1,a[-1])]:
  offset=float(target[1])-ps[i]['pos'][1]
  for p in ps:
   dist=np.linalg.norm(np.array(p['pos'])[::2]-target[::2]);p['pos'][1]=round(p['pos'][1]+offset*max(0,1-dist/8),2)
  ps[i]['pos']=list(target)
 by[nextid]={'num':nextid,'name':'Stapelburg '+name,'type':'cobblestone_road','autosmooth':False,'points':ps};changed.add(nextid);new_ids.append(nextid);nextid+=1
add('Dorfverbindung Nord',[A,point(1640,98),J])
add('Dorfverbindung Ost',[J,point(1662,99),point(1680,113),point(1690,145),point(1689,165),B])
add('Kirchzugang',[J,point(1647,78),church])
# Each arm terminates at J: the T-junction is never an interior curve point.
groups={}
for n,r in by.items():
 for i in [0,len(r['points'])-1]:groups.setdefault(tuple(r['points'][i]['pos']),[]).append(n)
touched={tuple(by[n]['points'][i]['pos']) for n in new_ids for i in [0,-1]}
for n,r in by.items():
 for i,p in enumerate(r['points']):
  if i in [0,len(r['points'])-1] and tuple(p['pos']) in touched:
   old=copy.deepcopy(p);p.pop('cross',None);links=sorted(m for m in groups[tuple(p['pos'])] if m!=n)
   if links:p['cross']={'autoConnectiveRoads':links}
   if p!=old:changed.add(n)
for n in changed:
 for i,p in enumerate(by[n]['points']):
  if 'cross' in p:assert i in [0,len(by[n]['points'])-1]
  for m in p.get('cross',{}).get('autoConnectiveRoads',[]):
   match=[q for q in [by[m]['points'][0],by[m]['points'][-1]] if q['pos']==p['pos']];assert match and n in match[0]['cross']['autoConnectiveRoads']
# Check new centre lines against existing houses (do not raze or shift them).
def dist(p,a,b):
 v=b-a;t=np.clip(np.dot(p-a,v)/max(np.dot(v,v),1e-9),0,1);return float(np.linalg.norm(p-a-v*t))
segs=[(np.array(p['pos'])[::2],np.array(q['pos'])[::2]) for n in new_ids for p,q in zip(by[n]['points'],by[n]['points'][1:])]
world=before['mapscenes/world_harzmountains.tscn'].decode();clearance=999.
for block in re.split(r'(?=\[node )',world):
 if not block.startswith('[node ') or 'parent="Residences/12_Stapelburg"' not in block.splitlines()[0]:continue
 tr=re.search(r'^transform = Transform3D\(([^\n]*)\)',block,re.M);p=np.array([float(v) for v in tr[1].split(',')][-3:])[::2]
 clearance=min(clearance,min(dist(p,a,b) for a,b in segs))
assert clearance>9,clearance
max_grade=max(abs(q['pos'][1]-p['pos'][1])/np.linalg.norm(np.array(q['pos'])[::2]-np.array(p['pos'])[::2]) for n in new_ids for p,q in zip(by[n]['points'],by[n]['points'][1:]))
assert max_grade<.20,max_grade
# Geographic site anchor. A marker only: it does not alter terrain or spawn a building.
lat,lon=51.90368,10.66945
info=json.loads((ROOT/'jsondata/mapinfo.json').read_text())['sizeAndPos'];north,west=info['longLat']['topLeft'];south,east=info['longLat']['bottomRight']
castle=[round((lon-west)/(east-west)*(info['rasterSize'][0]-1),2),0,round((north-lat)/(north-south)*(info['rasterSize'][1]-1),2)];castle[1]=round(h(castle[0],castle[2])+.05,3)
assert 'name="StapelburgCastleRuins"' not in world
world+='\n[node name="StapelburgCastleRuins" type="Marker3D" parent="Deco/Stapelburg"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, '+', '.join(map(str,castle))+')\ngizmo_extents = 8.0\neditor_description = "Burg Stapelburg ruins / Burgberg. Reserved landmark site. Geographic reference: 51.90368 N, 10.66945 E. Source: https://www.alleburgen.de/bd.php?id=27019"\n\n'
# Synchronize editor references using the same authoritative road records.
source=(OUT.parent/'wernigerode_rework_2026/apply_layout.py').read_text();exec(source[source.index('# Scene reference curves:'):source.index('# Remove obstructing residence')])
scene=scene.replace('material = ExtResource("7_j2dcm")\n','').replace('color = Color(1, 0.54901963, 0, 1)\n','')
with zipfile.ZipFile(OUT/'before.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for f,data in before.items():archive.writestr(f,data)
for f,data in before.items():assert (ROOT/f).read_bytes()==data
outputs={'jsondata/roads.json':json.dumps(sorted(by.values(),key=lambda r:r['num']),ensure_ascii=False,indent='\t')+'\n','mapscenes/editorobjects_harzmountains.tscn':scene,'mapscenes/world_harzmountains.tscn':world}
for f,s in outputs.items():
 if f.endswith('.json'):s=re.sub(r'\[\s+([-\d.eE+,\s]+)\]',lambda m:'['+', '.join(v.strip() for v in m[1].split(','))+']',s)
 p=ROOT/f;tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(s);tmp.replace(p)
assert hashes=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in guarded if p.is_file()}
assert all(r==by[int(r['num'])] for r in original if int(r['num']) not in changed)
report={'roads_added':[{'num':n,'name':by[n]['name']} for n in new_ids],'roads_changed':sorted(changed),'road_count':len(by),'castle_marker':{'node':'Deco/Stapelburg/StapelburgCastleRuins','pos':castle,'reference_lat_lon':[lat,lon]},'T_junction_xyz':J,'minimum_house_origin_clearance':round(clearance,2),'max_grade':round(float(max_grade),3),'terrain_paint_and_buildings_unchanged':True,'historical_alignment_status':'Approved representative model connection; exact 1960s street alignment not verified.'}
(OUT/'applied.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
