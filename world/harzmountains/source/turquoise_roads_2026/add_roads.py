"""1967-supported infill, simplified to the model's existing street anchors. Single use."""
from pathlib import Path
import copy,json,re,zipfile,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent
roadpath=ROOT/'jsondata/roads.json'; path=ROOT/'mapscenes/editorobjects_harzmountains.tscn'
assert not (OUT/'applied.json').exists(), 'Already applied'
original=json.loads(roadpath.read_text());by={int(r['num']):copy.deepcopy(r) for r in original}
assert max(by)==319 and len(by)==312,'Review changed catalog'
nextid=max(by)+1; changed=set();removed=set();split_ids=[];new_ids=[]
terrain_before={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'heightdata').glob('*.res')}
worldpath=ROOT/'mapscenes/world_harzmountains.tscn';world_before=hashlib.sha256(worldpath.read_bytes()).hexdigest()
height={(x,z):np.fromfile('/tmp/harz_%02d_%02d.rf'%(x,z),np.float32).reshape(256,256) for x in [11,12] for z in [5,6]}
def h(x,z):
 ix,iz=int(x),int(z);fx,fz=x-ix,z-iz
 def at(x,z):return float(height[x//256,z//256][z%256,x%256])
 return (at(ix,iz)*(1-fx)+at(ix+1,iz)*fx)*(1-fz)+(at(ix,iz+1)*(1-fx)+at(ix+1,iz+1)*fx)*fz

def nearest(n,x,z):
 ps=by[n]['points'];i=min(range(1,len(ps)-1),key=lambda i:(ps[i]['pos'][0]-x)**2+(ps[i]['pos'][2]-z)**2)
 return i,copy.deepcopy(ps[i]['pos'])
def split(n,i):
 global nextid
 old=copy.deepcopy(by[n]);assert old.get('autosmooth',True)==False
 assert 0<i<len(old['points'])-1
 by[n]['points']=copy.deepcopy(old['points'][:i+1]);by[nextid]=old;by[nextid]['num']=nextid;by[nextid]['points']=copy.deepcopy(old['points'][i:])
 changed.update([n,nextid]);split_ids.append(nextid);nextid+=1
 return nextid-1
# Kirchstraße turns into the Klint / northern church-square approach.
i,A=nearest(263,3039,1370);split(263,i)
i,B=nearest(265,3110,1405);tail=split(265,i)
# Oberengengasse continues east from the southern part of the Marktstraße axis.
i,C=nearest(tail,3121,1423);split(tail,i)
i,D=nearest(26,3190,1416);split(26,i)
J=[3130.,round(h(3130,1514)+.2,2),1514.]
E=copy.deepcopy(next(r for r in original if int(r['num'])==265)['points'][-1]['pos'])
by[116]=json.loads(Path('/tmp/harz_frozen116.json').read_text())
F=copy.deepcopy(by[116]['points'][2]['pos']);split(116,2)
G=copy.deepcopy(by[42]['points'][-1]['pos'])

def add(name,controls):
 global nextid
 # Closely sampled Catmull-Hermite geometry; no auto-smoothing changes at junctions.
 a=np.array(controls,float);xz=[]
 for i in range(len(a)-1):
  p,q=a[i:i+2];m=(q-a[max(0,i-1)])*.35;k=(a[min(len(a)-1,i+2)]-p)*.35
  for t in np.linspace(0,1,max(2,int(np.linalg.norm(q[[0,2]]-p[[0,2]])/2)+1))[:-1]:
   xz.append((2*t**3-3*t*t+1)*p+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*q+(t**3-t*t)*k)
 xz.append(a[-1]);ps=[]
 for v in xz:
  x,z=float(v[0]),float(v[2]);ps.append({'pos':[round(x,2),round(h(x,z)+.2,2),round(z,2)]})
 # Forckestraße spans the model stream at bank height, rather than diving into its bed.
 if name=='Forckestraße':
  lengths=np.r_[0,np.cumsum([np.linalg.norm(np.array(q['pos'])[::2]-np.array(p['pos'])[::2]) for p,q in zip(ps,ps[1:])])]
  for p,d in zip(ps,lengths):p['pos'][1]=round(max(p['pos'][1],float(a[0,1]+(a[-1,1]-a[0,1])*d/lengths[-1])),2)
 # Meet exact XYZ of the receiving road; taper the terrain offset over 8 metres.
 for end,target in [(0,a[0]),(-1,a[-1])]:
  d=np.array([np.linalg.norm(np.array(p['pos'])[::2]-target[::2]) for p in ps]);offset=float(target[1])-ps[end]['pos'][1]
  for p,dist in zip(ps,d):p['pos'][1]=round(p['pos'][1]+offset*max(0,1-dist/8),2)
  ps[end]['pos']=list(target)
 by[nextid]={'num':nextid,'name':'Wernigerode '+name,'type':'cobblestone_road','autosmooth':False,'points':ps}
 changed.add(nextid);new_ids.append(nextid);nextid+=1
add('Kirchstraße und Klint',[A,[3065,0,1383],[3075,0,1400],[3090,0,1407],B])
add('Oberengengasse',[C,[3144,0,1420],[3169,0,1417],D])
add('Dammstraße',[E,[3131,0,1492],J])
add('Forckestraße',[F,[3105,0,1522],J])
add('Lindenbergstraße',[J,[3152,0,1520],[3176,0,1529],G])
# Refresh reciprocal links only where this pass changed segment ownership.
groups={}
for n,r in by.items():
 for i in [0,len(r['points'])-1]:groups.setdefault(tuple(r['points'][i]['pos']),[]).append((n,i))
touched={tuple(by[n]['points'][i]['pos']) for n in changed for i in [0,-1]}
affected=set(changed)
for n,r in by.items():
 for i,p in enumerate(r['points']):
  targets=p.get('cross',{}).get('autoConnectiveRoads',[])+p.get('cross',{}).get('connectiveRoads',[])
  if n in affected or tuple(p['pos']) in touched or any(v in affected for v in targets):
   old=copy.deepcopy(p);p.pop('cross',None)
   if i in [0,len(r['points'])-1]:
    links=sorted(m for m,j in groups[tuple(p['pos'])] if m!=n)
    if links:p['cross']={'autoConnectiveRoads':links}
   if p!=old:changed.add(n)
for n in changed:
 for i,p in enumerate(by[n]['points']):
  if 'cross' in p:assert i in [0,len(by[n]['points'])-1]
  for m in p.get('cross',{}).get('autoConnectiveRoads',[]):
   match=[q for q in [by[m]['points'][0],by[m]['points'][-1]] if q['pos']==p['pos']];assert match,(n,m)
   assert n in match[0]['cross']['autoConnectiveRoads'],(n,m,p['pos'])
# Roads on opposite sides of St Sylvestri; no building/ground edits in this pass.
new_segs=[(np.array(a['pos'])[::2],np.array(b['pos'])[::2],n) for n in new_ids for a,b in zip(by[n]['points'],by[n]['points'][1:])]
def dist(p,a,b):
 v=b-a;t=np.clip(np.dot(p-a,v)/max(np.dot(v,v),1e-8),0,1);return np.linalg.norm(p-a-t*v)
collisions=[]
for block in re.split(r'(?=\[node )',worldpath.read_text()):
 if not block.startswith('[node ') or 'parent="Residences/' not in block.splitlines()[0]:continue
 tr=re.search(r'^transform = Transform3D\(([^\n]*)\)',block,re.M)
 if not tr:continue
 p=np.array([float(v) for v in tr[1].split(',')][-3:])[::2]
 d,n=min((dist(p,a,b),n) for a,b,n in new_segs)
 if d<5:collisions.append({'node':block.splitlines()[0],'distance':round(float(d),2),'road':n})
assert not collisions,collisions
maxgrade=max(abs(b['pos'][1]-a['pos'][1])/np.linalg.norm(np.array(b['pos'])[::2]-np.array(a['pos'])[::2]) for n in new_ids for a,b in zip(by[n]['points'],by[n]['points'][1:]))
assert maxgrade<.3,maxgrade
# Keep original geometry byte-for-byte as authored point sequences after splitting.
for n in [263,265,26]:
 old=next(r for r in original if int(r['num'])==n)
 for p in old['points']:assert any(p['pos']==q['pos'] for r in by.values() for q in r['points'])
with zipfile.ZipFile(OUT/'before.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for p in [roadpath,path]:archive.write(p,p.relative_to(ROOT))
source=(OUT.parent/'wernigerode_rework_2026/apply_layout.py').read_text()
exec(source[source.index('# Scene reference curves:'):source.index('# Remove obstructing residence')])
s=json.dumps(sorted(by.values(),key=lambda r:r['num']),ensure_ascii=False,indent='\t');s=re.sub(r'\[\s+([-\d.eE+,\s]+)\]',lambda m:'['+', '.join(v.strip() for v in m[1].split(','))+']',s)
roadpath.write_text(s+'\n');scene=scene.replace('material = ExtResource("7_j2dcm")\n','').replace('color = Color(1, 0.54901963, 0, 1)\n','');path.write_text(scene)
assert terrain_before=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'heightdata').glob('*.res')}
assert hashlib.sha256(worldpath.read_bytes()).hexdigest()==world_before
report={'historical_source':'doc/harzmountains_pics/StadtplanWernigerode67.webp','layout':'Compressed model connections, not surveyed positions. Kirchstraße/Klint church approach, Oberengengasse, Dammstraße–Forckestraße–Lindenbergstraße junction south of old town.','added_routes':[{ 'id':n,'name':by[n]['name']} for n in new_ids],'split_piece_ids':split_ids,'changed_ids':sorted(changed),'count':len(by),'max_grade':round(float(maxgrade),3),'terrain_and_ground_paint_unchanged':True,'world_and_buildings_unchanged':True,'park_side_link_added':False,'short_stream_crossing':{'road':'Forckestraße','road_at_bank_height':True,'bridge_scenery_placed':False}}
(OUT/'applied.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False))
