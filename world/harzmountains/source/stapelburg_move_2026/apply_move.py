"""Move Stapelburg as a bundle. Preserve terrain and unrelated map objects. Single-use, backed up before writing."""
from pathlib import Path
import copy,hashlib,json,re,zipfile,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent
assert not (OUT/'applied.json').exists(),'Already applied'
files=['jsondata/roads.json','jsondata/towns.json','mapscenes/world_harzmountains.tscn','mapscenes/towns_harzmountains.tscn','mapscenes/editorobjects_harzmountains.tscn']
before={f:(ROOT/f).read_bytes() for f in files}
guarded=[*ROOT.glob('heightdata/*.res'),*ROOT.glob('vegetation/*'),ROOT/'mapscenes/terrain/terrain_harzmountains.tscn']
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in guarded if p.is_file()}
roads=json.loads(before[files[0]]);by={int(r['num']):copy.deepcopy(r) for r in roads}
assert len(by)==318 and max(by)==329,'Review updated map first'
moved={102,103,104,203};removed=set();changed=set(moved)
# Correct geographic centre, from the map's actual bounds and the reference gazetteer point.
reference=[51.90075,10.66240];info=json.loads((ROOT/'jsondata/mapinfo.json').read_text())['sizeAndPos'];north,west=info['longLat']['topLeft'];south,east=info['longLat']['bottomRight']
old_centre=[1309.,445.]
target=[round((reference[1]-west)/(east-west)*(info['rasterSize'][0]-1),2),round((north-reference[0])/(north-south)*(info['rasterSize'][1]-1),2)]
delta=[round(target[i]-old_centre[i],2) for i in [0,1]]
height={(x,z):np.fromfile('/tmp/stapelburg_move_%02d_%02d.rf'%(x,z),np.float32).reshape(256,256) for x,z in [(5,1),(5,2),(6,0)]}
def h(x,z):
 ix,iz=math.floor(x),math.floor(z);fx,fz=x-ix,z-iz
 def at(x,z):return float(height[x//256,z//256][z%256,x%256])
 return (at(ix,iz)*(1-fx)+at(ix+1,iz)*fx)*(1-fz)+(at(ix,iz+1)*(1-fx)+at(ix+1,iz+1)*fx)*fz

def move_pos(p,rounded=4):
 x,y,z=map(float,p);nx=x+delta[0];nz=z+delta[1]
 return [round(nx,rounded),round(y+h(nx,nz)-h(x,z),rounded),round(nz,rounded)]
frozen={int(r['num']):r for r in json.loads(Path('/tmp/stapelburg_move_frozen_roads.json').read_text())}
assert set(frozen)==moved
for n in moved:
 r=copy.deepcopy(frozen[n])
 assert len(r['points'])==len(by[n]['points'])
 for p in r['points']:
  old=np.array(p['pos'],float);new=move_pos(old,2)
  for key in ['handleIn','handleOut']:
   control=move_pos(old+np.array(p[key]),5)
   p[key]=[round(float(control[i]-new[i]),5) for i in range(3)]
  p['pos']=new
 by[n]=r
for n in removed:by.pop(n)
# Only changed endpoint groups are rebuilt. Keep unaffected junctions and manual links intact.
groups={}
for n,r in by.items():
 for i in [0,len(r['points'])-1]:groups.setdefault(tuple(r['points'][i]['pos']),[]).append(n)
for n,r in by.items():
 for i,p in enumerate(r['points']):
  old=copy.deepcopy(p)
  targets=p.get('cross',{}).get('autoConnectiveRoads',[])+p.get('cross',{}).get('connectiveRoads',[])
  if n in moved or any(t in moved|removed for t in targets):
   p.pop('cross',None)
   if i in [0,len(r['points'])-1]:
    links=sorted(m for m in groups[tuple(p['pos'])] if m!=n)
    if links:p['cross']={'autoConnectiveRoads':links}
  if p!=old:changed.add(n)
for n in changed:
 for i,p in enumerate(by[n]['points']):
  if 'cross' in p:assert i in [0,len(by[n]['points'])-1]
  for m in p.get('cross',{}).get('autoConnectiveRoads',[]):
   matches=[q for q in [by[m]['points'][0],by[m]['points'][-1]] if q['pos']==p['pos']]
   assert matches and n in matches[0]['cross']['autoConnectiveRoads'],(n,m)
# Move the existing residence and decoration subtrees without changing local rotations.
world=before['mapscenes/world_harzmountains.tscn'].decode()
world=re.sub(r'^houses = Array\[Node3D\]\(\[.*?\]\)\n','',world,flags=re.M|re.S)
moved_nodes=[];parts=[]
for block in re.split(r'(?=\[node )',world):
 if not block.startswith('[node '):parts.append(block);continue
 header=block.splitlines()[0];name=re.search(r'name="([^"]+)"',header)[1];parent=re.search(r'parent="([^"]+)"',header)
 parent=parent[1] if parent else ''
 full=(parent+'/'+name).removeprefix('./')
 if parent.startswith(('Residences/12_Stapelburg','Deco/Stapelburg')):
  tr=re.search(r'^transform = Transform3D\(([^\n]+)\)',block,re.M)
  if tr:
   vals=[float(v) for v in tr[1].split(',')];old=vals[-3:];new=move_pos(old);vals[-3:]=new
   block=block[:tr.start(1)]+', '.join(str(v) for v in vals)+block[tr.end(1):]
   moved_nodes.append({'node':full,'before':old,'after':new})
 parts.append(block)
world=''.join(parts)
assert len([n for n in moved_nodes if n['node'].startswith('Residences/12_Stapelburg/')])==7
assert len([n for n in moved_nodes if n['node'].startswith('Deco/Stapelburg/')])==2
# Update both the authoritative scene node and TownData coordinates.
townscene=before['mapscenes/towns_harzmountains.tscn'].decode();town_parts=[]
for b in re.split(r'(?=\[(?:sub_resource|node) )',townscene):
 if b.startswith('[sub_resource') and 'town_name = "Stapelburg"' in b:
  b=re.sub(r'pos_xz = Vector2\([^\n]+\)',f'pos_xz = Vector2({target[0]}, {target[1]})',b)
 if b.startswith('[node ') and 'town = SubResource("Resource_fe2ms")' in b:
  b=re.sub(r'transform = Transform3D\([^\n]+\)',f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {target[0]}, {round(h(*target),4)}, {target[1]})',b)
 town_parts.append(b)
townscene=''.join(town_parts)
legacy=json.loads(before['jsondata/towns.json'])
for t in legacy:
 if t['name']=='Stapelburg':t['pos']=target
# Synchronize editor reference curves and road nodes from the same data.
source=(OUT.parent/'wernigerode_rework_2026/apply_layout.py').read_text()
exec(source[source.index('# Scene reference curves:'):source.index('# Remove obstructing residence')])
scene=scene.replace('material = ExtResource("7_j2dcm")\n','').replace('color = Color(1, 0.54901963, 0, 1)\n','')
# Guarded snapshot and atomic file replacement.
with zipfile.ZipFile(OUT/'before.zip','w',zipfile.ZIP_DEFLATED) as z:
 for f,data in before.items():z.writestr(f,data)
 def keep_input(name):z.writestr('inputs/'+name,Path('/tmp/'+name).read_bytes())
 keep_input('stapelburg_move_frozen_roads.json')
for f,data in before.items():assert (ROOT/f).read_bytes()==data,'Inputs changed during planning'
outputs={'jsondata/roads.json':json.dumps(sorted(by.values(),key=lambda r:r['num']),ensure_ascii=False,indent='\t')+'\n','jsondata/towns.json':json.dumps(legacy,ensure_ascii=False,indent='\t')+'\n','mapscenes/world_harzmountains.tscn':world,'mapscenes/towns_harzmountains.tscn':townscene,'mapscenes/editorobjects_harzmountains.tscn':scene}
for f,s in outputs.items():
 if f.endswith('.json'):s=re.sub(r'\[\s+([-\d.eE+,\s]+)\]',lambda m:'['+', '.join(v.strip() for v in m[1].split(','))+']',s)
 p=ROOT/f;temp=p.with_suffix(p.suffix+'.tmp');temp.write_text(s);temp.replace(p)
assert hashes=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in guarded if p.is_file()}
assert all(r==by[int(r['num'])] for r in roads if int(r['num']) not in changed|removed)
report={'stapelburg':{'reference_lat_lon':reference,'centre_xz':target,'translation_xz':delta,'roads_moved':sorted(moved),'nodes_moved':moved_nodes},'road_records_changed':sorted(changed),'road_count':len(by),'terrain_and_paint_unchanged':True,'approach_roads_to_redraw':[101,204],'outlying_forest_moved':False}
(OUT/'applied.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
