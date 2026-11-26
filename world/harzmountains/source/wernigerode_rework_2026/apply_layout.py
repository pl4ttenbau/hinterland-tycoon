from pathlib import Path
import json,re,hashlib,copy,math,zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).parent
ART=Path('/home/cornelinux/.codex/visualizations/2026/11/26/01a2174c-20d4-70e3-864a-1a4ebf9b7353')
plan=json.loads((OUT/'road_layout_plan.json').read_text()); hashes=json.loads((OUT/'before_hashes.json').read_text())
for p,h in hashes.items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h, 'Changed input '+p
roads=json.loads((ROOT/'jsondata/roads.json').read_text()); original=copy.deepcopy(roads); by={int(r['num']):r for r in roads}; nextid=max(by)+1
height=np.load(ART/'harz-heights.npy'); fixed={tuple(p['pos'][::2]):p['pos'][1] for r in roads for p in r['points']}
def H(x,z):return float(height[round(z)-1024,round(x)-2560])
def smooth(ps):
 ps=np.array(ps,dtype=float);result=[]
 for i in range(len(ps)-1):
  a,b=ps[i:i+2]; prev=ps[max(0,i-1)];nxt=ps[min(len(ps)-1,i+2)]
  m=(b-prev)*.35;n=(nxt-a)*.35
  for t in np.linspace(0,1,max(2,int(np.linalg.norm(b-a)/3)+1))[:-1]:
   result.append((2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*b+(t**3-t*t)*n)
 result.append(ps[-1]);return result
changed=set();new_geometry=set(); removed=set(plan['remove_road_ids'])
for n in removed:by.pop(n)
for r in plan['rename_existing_roads']:by[r['num']]['name']=r['name'];changed.add(r['num'])
for spec in plan['replace_roads']+plan['add_roads']:
 n=spec.get('num');
 if n is None:n=nextid;nextid+=1
 pts=smooth(spec['controls_xz']); ys=np.array([H(*p)+.25 for p in pts]); ys=np.convolve(np.pad(ys,(3,3),mode='edge'),np.ones(7)/7,mode='valid')
 for i,p in enumerate(pts):
  k=tuple(np.round(p,2));
  if k in fixed:ys[i]=fixed[k]
 record={'num':n,'name':spec['name'],'type':spec['type'],'autosmooth':False,'points':[{'pos':[round(float(p[0]),2),round(float(y),2),round(float(p[1]),2)]} for p,y in zip(pts,ys)]}
 by[n]=record;changed.add(n);new_geometry.add(n)
# Split at every XZ intersection involving rebuilt geometry. Existing lines retain their controls.
cuts={n:{} for n in by};ids=list(by)
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
for ai,n in enumerate(ids):
 for m in ids[ai+1:]:
  if n not in new_geometry and m not in new_geometry:continue
  aa=by[n]['points'];bb=by[m]['points']
  for i in range(len(aa)-1):
   a=np.array(aa[i]['pos'])[::2];v=np.array(aa[i+1]['pos'])[::2]-a
   for j in range(len(bb)-1):
    b=np.array(bb[j]['pos'])[::2];w=np.array(bb[j+1]['pos'])[::2]-b;den=cross(v,w)
    if abs(den)<1e-8:continue
    t=cross(b-a,w)/den;u=cross(b-a,v)/den
    if -.00001<=t<=1.00001 and -.00001<=u<=1.00001:
     t=float(np.clip(t,0,1));u=float(np.clip(u,0,1));p=a+t*v
     y1=aa[i]['pos'][1]*(1-t)+aa[i+1]['pos'][1]*t;y2=bb[j]['pos'][1]*(1-u)+bb[j+1]['pos'][1]*u
     y=y2 if m not in new_geometry else y1 if n not in new_geometry else (y1+y2)/2
     xyz=[round(float(p[0]),2),round(float(y),2),round(float(p[1]),2)]
     cuts[n][round(i+t,6)]=xyz;cuts[m][round(j+u,6)]=xyz
# Shared design controls also count, including collinear joins.
endpoints={tuple(r['points'][k]['pos'][::2]) for r in by.values() for k in [0,-1]}
for n,r in by.items():
 for i,p in enumerate(r['points']):
  if tuple(p['pos'][::2]) in endpoints:cuts[n].setdefault(float(i),p['pos'])
for spec in plan['known_required_splits']:
 if 'existing_road' in spec:cuts[spec['existing_road']][float(spec['point_index'])]=by[spec['existing_road']]['points'][spec['point_index']]['pos']
for n,r in list(by.items()):
 interior=[t for t in cuts[n] if 1e-5<t<len(r['points'])-1-1e-5]
 if not interior:continue
 allpoints={float(i):copy.deepcopy(p) for i,p in enumerate(r['points'])}
 for t,xyz in cuts[n].items():allpoints[t]={'pos':xyz}
 keys=sorted(allpoints); bounds=sorted(set([0.,float(len(r['points'])-1)]+interior)); parts=[]
 for lo,hi in zip(bounds,bounds[1:]):
  pp=[copy.deepcopy(allpoints[t]) for t in keys if lo-1e-7<=t<=hi+1e-7]
  clean=[]
  for p in pp:
   if not clean or np.linalg.norm(np.array(p['pos'])-clean[-1]['pos'])>.025:clean.append(p)
  if len(clean)>=2 and np.linalg.norm(np.array(clean[0]['pos'])-clean[-1]['pos'])>.1:parts.append(clean)
 if len(parts)>1:
  for k,pp in enumerate(parts):
   num=n if k==0 else nextid
   if k:nextid+=1
   rr=copy.deepcopy(r);rr['num']=num;rr['points']=pp;by[num]=rr;changed.add(num)
# Canonical coincident endpoints share exactly the same elevation.
groups={}
for n,r in by.items():
 for i in [0,len(r['points'])-1]:groups.setdefault(tuple(r['points'][i]['pos'][::2]),[]).append((n,i))
for key,entries in groups.items():
 if len(entries)<2:continue
 old=[by[n]['points'][i]['pos'][1] for n,i in entries if n not in changed];y=old[0] if old else round(sum(by[n]['points'][i]['pos'][1] for n,i in entries)/len(entries),2)
 for n,i in entries:
  if n in changed:by[n]['points'][i]['pos'][1]=y
# Rebuild only endpoint lists. Existing unrelated geometry remains intact.
for n,r in by.items():
 for i,p in enumerate(r['points']):
  if n in changed or any(v in removed or v in changed for v in p.get('cross',{}).get('autoConnectiveRoads',[])+p.get('cross',{}).get('connectiveRoads',[])):p.pop('cross',None)
 for i in [0,len(r['points'])-1]:
  p=r['points'][i];neighbors=sorted(m for m,j in groups[tuple(p['pos'][::2])] if m!=n and np.linalg.norm(np.array(p['pos'])-by[m]['points'][j]['pos'])<=.02)
  if neighbors:p['cross']={'autoConnectiveRoads':neighbors}
# Validate endpoint-only links for affected roads.
for n in changed:
 r=by[n]
 for i,p in enumerate(r['points']):
  if 'cross' in p:assert i in [0,len(r['points'])-1]
  for m in p.get('cross',{}).get('autoConnectiveRoads',[]):assert any(np.linalg.norm(np.array(p['pos'])-q['pos'])<=.02 for q in [by[m]['points'][0],by[m]['points'][-1]])
# Scene reference curves: replace affected nodes and append new references.
path=ROOT/'mapscenes/editorobjects_harzmountains.tscn';scene=path.read_text();blocks=re.split(r'(?=\[(?:sub_resource|node) )',scene);curveids=set();kept=[]
for b in blocks:
 if b.startswith('[node ') and 'infr_domain = 1' in b:
  num=re.search(r'^num = (\d+)',b,re.M)
  if num and int(num[1]) in changed|removed:
   curveids.update(re.findall(r'curve = SubResource\("([^"]+)"\)',b));continue
 kept.append(b)
kept=[b for b in kept if not (b.startswith('[sub_resource') and any('id="'+c+'"' in b.splitlines()[0] for c in curveids))]
scene=''.join(kept); sub=[];nodes=[]
for n in sorted(changed):
 r=by[n];ps=r['points'];o=np.array(ps[0]['pos']);flat=[]
 for p in ps:flat.extend(p.get('handleIn',[0,0,0]));flat.extend(p.get('handleOut',[-v for v in p.get('handleIn',[0,0,0])]));flat.extend(np.array(p['pos'])-o)
 cid='Curve3D_wr_'+str(n); vals=', '.join(str(round(float(v),5)) for v in flat)
 sub.append('[sub_resource type="Curve3D" id="'+cid+'"]\n_data = {\n"points": PackedVector3Array('+vals+'),\n"tilts": PackedFloat32Array('+', '.join('0' for _ in ps)+')\n}\npoint_count = '+str(len(ps))+'\n\n')
 nodes.append(f'[node name="RoadWay_{n}" type="Path3D" parent="EditorInfr/EditorRoads"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {o[0]}, {o[1]}, {o[2]})\ncurve = SubResource("{cid}")\nscript = ExtResource("4_nc52l")\nnum = {n}\ninfr_name = '+json.dumps(r['name'],ensure_ascii=False)+f'\ninfr_domain = 1\nautosmooth = {str(r.get("autosmooth",True)).lower()}\ncolor = Color(1, 0.54901963, 0, 1)\nmaterial = ExtResource("7_j2dcm")\n\n')
idx=scene.index('[node ');scene=scene[:idx]+''.join(sub)+scene[idx:]+''.join(nodes)
# Remove obstructing residence nodes, and discard the obsolete serialized getter cache.
worldpath=ROOT/'mapscenes/world_harzmountains.tscn';world=worldpath.read_text();world=re.sub(r'^houses = Array\[Node3D\]\(\[.*?\]\)\n','',world,flags=re.M|re.S)
newsegs=[(np.array(a['pos'])[::2],np.array(b['pos'])[::2]) for n in changed for a,b in zip(by[n]['points'],by[n]['points'][1:])]
def dist(p,a,b):
 v=b-a;t=np.clip(np.dot(p-a,v)/max(np.dot(v,v),1e-9),0,1);return np.linalg.norm(p-a-v*t)
cleared=[];parts=[]
for b in re.split(r'(?=\[node )',world):
 if b.startswith('[node ') and 'parent="Residences/' in b.splitlines()[0]:
  tr=re.search(r'^transform = Transform3D\(([^\n]*)\)',b,re.M)
  if tr:
   p=np.array([float(v) for v in tr[1].split(',')][-3:])[::2]
   if min((dist(p,a,c) for a,c in newsegs),default=999)<9:
    cleared.append(b.splitlines()[0]);continue
 parts.append(b)
world=''.join(parts)
# Station anchors, without altering rail geometry.
inter=json.loads((ROOT/'jsondata/interchanges.json').read_text());stops=[s['num'] for r in inter for s in r['stops']]
for r in inter:
 if r['num']==19:r['stops'][0]['nodeIndex']=12
 if r['num']==9:r['stops'].append({'num':max(stops)+1,'domain':'RAIL','trackNum':12,'nodeIndex':4,'type':'STATION_PASS'})
# Stage road-bed raster edits; channel samples stay untouched.
after=height.copy();mask=np.zeros(height.shape,dtype=bool)
for n in new_geometry:
 # Original rebuilt records may have been split: include all descendants by their names.
 name=by[n]['name'];records=[r for r in by.values() if r['name']==name]
 for r in records:
  for a,b in zip(r['points'],r['points'][1:]):
   a=np.array(a['pos']);b=np.array(b['pos']);v=b[[0,2]]-a[[0,2]];length=np.dot(v,v)
   if length<.0001:continue
   for z in range(max(1024,math.floor(min(a[2],b[2])-7)),min(2047,math.ceil(max(a[2],b[2])+7))+1):
    for x in range(max(2560,math.floor(min(a[0],b[0])-7)),min(3583,math.ceil(max(a[0],b[0])+7))+1):
     t=np.clip(np.dot(np.array([x,z])-a[[0,2]],v)/length,0,1);d=np.linalg.norm(np.array([x,z])-a[[0,2]]-v*t)
     if d>=6:continue
     h=float(height[z-1024,x-2560])
     # Conservative protection of all low channels, including tilted Hasserode water.
     if h<4.8 or (x<2800 and z>1650 and h<8.1):continue
     target=a[1]*(1-t)+b[1]*t-.22;weight=1 if d<=3 else (6-d)/3;new=h+(target-h)*weight
     if abs(new-h)>2.5:continue
     after[z-1024,x-2560]=new;mask[z-1024,x-2560]=True
terrain=[]
for d in json.loads((OUT/'terrain_regions_before.json').read_text()):
 x,z=d['location'];a=after[(z-4)*256:(z-3)*256,(x-10)*256:(x-9)*256];old=height[(z-4)*256:(z-3)*256,(x-10)*256:(x-9)*256]
 if np.any(a!=old):
  a.astype('<f4').tofile(OUT/(d['file']+'.rf'));terrain.append(d)
(OUT/'terrain_to_apply.json').write_text(json.dumps(terrain,indent=2))
def dump(value):
 s=json.dumps(value,ensure_ascii=False,indent='\t');return re.sub(r'\[\s+([-\d.eE+,\s]+)\]',lambda m:'['+', '.join(v.strip() for v in m[1].split(','))+']',s)+'\n'
(ROOT/'jsondata/roads.json').write_text(dump(sorted(by.values(),key=lambda r:r['num'])))
(ROOT/'jsondata/interchanges.json').write_text(dump(inter));path.write_text(scene);worldpath.write_text(world)
report={'status':'APPLIED_ROADS_STATIONS_SCENES_TERRAIN_PENDING','road_count_before':len(original),'road_count_after':len(by),'changed_road_ids':sorted(changed),'removed_road_ids':sorted(removed),'cleared_residences':cleared,'terrain_samples_staged':int(np.count_nonzero(after!=height)),'terrain_regions':len(terrain),'water_and_paint_preserved':True}
(OUT/'implementation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
