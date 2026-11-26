"""Station access pass. Run once; snapshot and report are retained beside it."""
from pathlib import Path
import json,re,copy,math,zipfile,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent
roadpath=ROOT/'jsondata/roads.json'; path=ROOT/'mapscenes/editorobjects_harzmountains.tscn'
assert not (OUT/'station_roads_applied.json').exists(),'Already applied'
original=json.loads(roadpath.read_text());by={int(r['num']):copy.deepcopy(r) for r in original};nextid=max(by)+1
assert nextid==276,'Catalog changed; review new IDs'
with zipfile.ZipFile(OUT/'before_station_roads.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in [roadpath,path]:z.write(p,p.relative_to(ROOT))
# Stable current elevations from the untouched station terrain region.
region=ROOT/'heightdata/terrain3d_12_04.res'
manifest=json.loads((OUT/'terrain_regions_before.json').read_text())
assert hashlib.sha256(region.read_bytes()).hexdigest()==next(r['sha256'] for r in manifest if r['file']==region.name)
ART=Path('/home/cornelinux/.codex/visualizations/2026/11/26/01a2174c-20d4-70e3-864a-1a4ebf9b7353');height=np.load(ART/'harz-heights.npy')
F=[3157.,5.2,1189.];J=copy.deepcopy(by[141]['points'][2]['pos']);B=copy.deepcopy(by[257]['points'][-1]['pos'])
def curve(n,name,controls):
 a=np.array(controls,float);res=[]
 for i in range(len(a)-1):
  p,q=a[i:i+2];m=(q-a[max(0,i-1)])*.35;k=(a[min(len(a)-1,i+2)]-p)*.35
  for t in np.linspace(0,1,max(2,int(np.linalg.norm(q[[0,2]]-p[[0,2]])/3)+1))[:-1]:
   v=(2*t**3-3*t*t+1)*p+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*q+(t**3-t*t)*k
   res.append({'pos':[round(float(x),2) for x in v]})
 res.append({'pos':list(controls[-1])})
 return {'num':n,'name':name,'type':'cobblestone_road','autosmooth':False,'points':res}
by[257]['name']='Wernigerode Bahnhof Ostzufahrt'
by[258]=curve(258,'Wernigerode Bahnhofsplatz Nordarm',[B,[3223.88,5.26,1138.35],[3210,5.3,1158],[3190,5.2,1180],F])
by[259]=curve(259,'Wernigerode Bahnhofsplatz Südarm',[B,[3260,4.9,1148],[3235,5.1,1175],[3200,5.2,1193],F])
by[276]=curve(276,'Wernigerode Bahnhofsplatz Stadtzufahrt',[F,[3170,5.2,1203],[3185,5.15,1220],J])
old=copy.deepcopy(by[141]);by[141]['points']=copy.deepcopy(old['points'][:3]);by[277]=copy.deepcopy(old);by[277]['num']=277;by[277]['points']=copy.deepcopy(old['points'][2:]);by[277]['name']='Wernigerode Schreiberstraße Ost'
removed={260,261};changed={141,257,258,259,276,277}
for n in removed:by.pop(n)
# Rebuild affected reciprocal endpoint links, leaving unrelated records unchanged.
groups={}
for n,r in by.items():
 for i in [0,len(r['points'])-1]:groups.setdefault(tuple(r['points'][i]['pos']),[]).append((n,i))
for n,r in by.items():
 for i,p in enumerate(r['points']):
  targets=p.get('cross',{}).get('autoConnectiveRoads',[])+p.get('cross',{}).get('connectiveRoads',[])
  if n in changed or any(v in changed|removed for v in targets):
   p.pop('cross',None)
   if i in [0,len(r['points'])-1]:
    links=sorted(m for m,j in groups[tuple(p['pos'])] if m!=n)
    if links:p['cross']={'autoConnectiveRoads':links}
# Actual new-road clearance against native track curves, including Bezier handles.
tracks=json.loads((ROOT/'jsondata/tracks.json').read_text());railsegs=[]
for tr in tracks:
 ps=[]
 for a,b in zip(tr['points'],tr['points'][1:]):
  p=np.array(a['pos']);q=np.array(b['pos']);ho=np.array(a.get('handleOut',[-v for v in a.get('handleIn',[0,0,0]) ]));hi=np.array(b.get('handleIn',[0,0,0]))
  for t in np.linspace(0,1,16):ps.append((1-t)**3*p+3*(1-t)**2*t*(p+ho)+3*(1-t)*t*t*(q+hi)+t**3*q)
 railsegs.extend(zip(ps,ps[1:]))
def dist(p,a,b):
 v=b-a;t=np.clip(np.dot(p-a,v)/max(np.dot(v,v),1e-8),0,1);return float(np.linalg.norm(p-a-v*t))
ra=np.array([a[::2] for a,b in railsegs]);rv=np.array([b[::2]-a[::2] for a,b in railsegs]);den=np.maximum(np.sum(rv*rv,axis=1),1e-9)
clearance=999.0
for n in [258,259,276]:
 for p in by[n]['points']:
  delta=np.array(p['pos'])[::2]-ra;t=np.clip(np.sum(delta*rv,axis=1)/den,0,1);clearance=min(clearance,float(np.min(np.linalg.norm(delta-rv*t[:,None],axis=1))))
assert clearance>7,clearance
for n in changed:
 for i,p in enumerate(by[n]['points']):
  if 'cross' in p:assert i in [0,len(by[n]['points'])-1]
  for m in p.get('cross',{}).get('autoConnectiveRoads',[]):assert any(q['pos']==p['pos'] for q in [by[m]['points'][0],by[m]['points'][-1]])
# Synchronize the same road IDs in the saved editor reference scene.
source=(OUT/'apply_layout.py').read_text();section=source[source.index('# Scene reference curves:'):source.index('# Remove obstructing residence')];exec(section)
# Remove the obsolete getter cache and only residences obstructing these new arms.
wp=ROOT/'mapscenes/world_harzmountains.tscn';world=wp.read_text();beforeworld=world
world=re.sub(r'^houses = Array\[Node3D\]\(\[.*?\]\)\n','',world,flags=re.M|re.S)
segs=[(np.array(a['pos'])[::2],np.array(b['pos'])[::2]) for n in [258,259,276] for a,b in zip(by[n]['points'],by[n]['points'][1:])];parts=[];razed=[]
for block in re.split(r'(?=\[node )',world):
 if block.startswith('[node ') and 'parent="Residences/' in block.splitlines()[0]:
  tr=re.search(r'^transform = Transform3D\(([^\n]*)\)',block,re.M)
  if tr:
   pos=np.array([float(v) for v in tr[1].split(',')][-3:])[::2]
   if min(dist(pos,a,b) for a,b in segs)<8:razed.append(block.splitlines()[0]);continue
 parts.append(block)
world=''.join(parts)
if world!=beforeworld:
 with zipfile.ZipFile(OUT/'before_station_roads.zip','a',zipfile.ZIP_DEFLATED) as z:z.writestr('mapscenes/world_harzmountains.tscn',beforeworld)
 wp.write_text(world)
# No terrain or paint mutation; current station grade is almost level.
errors=[]
for n in [258,259,276]:
 for p in by[n]['points']:
  x,y,z=p['pos'];errors.append(abs(y-(float(height[round(z)-1024,round(x)-2560])+.2)))
assert max(errors)<.8,max(errors)
s=json.dumps(sorted(by.values(),key=lambda r:r['num']),ensure_ascii=False,indent='\t');s=re.sub(r'\[\s+([-\d.eE+,\s]+)\]',lambda m:'['+', '.join(v.strip() for v in m[1].split(','))+']',s)
roadpath.write_text(s+'\n');path.write_text(scene)
report={'changed':sorted(changed),'removed':sorted(removed),'added':[276,277],'minimum_new_road_centre_to_rail_centre':round(clearance,2),'max_road_ground_height_difference':round(max(errors),2),'razed':razed,'terrain_and_paint_changed':False,'north_side_changed':False}
(OUT/'station_roads_applied.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
