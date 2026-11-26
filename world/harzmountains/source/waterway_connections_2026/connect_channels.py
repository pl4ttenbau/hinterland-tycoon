"""Cut missing links in existing model channels; does not trace new real-world waterways."""
from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image,ImageDraw
P=Path(__file__).parent
h=np.load(P/'current.npy');after=h.copy()
# XZ controls fitted to existing excavations. Order is upstream to downstream.
paths=[{'name':'Existing southeast channel to northern Holtemme reach','controls':[[3139,1542],[3130,1533],[3110,1528],[3096,1523],[3089,1510],[3084,1495],[3077,1482],[3066,1468],[3056,1452],[3042,1440],[3032,1434],[3020,1429],[3008,1423],[2998,1413],[2990,1402],[2984,1388],[2980,1372],[2976,1355],[2975,1330],[2972,1318],[2973,1304]],'bed_upstream':3.6,'bed_downstream':3.15}, {'name':'Hasserode branch connection','controls':[[3035,1490],[3041,1481],[3051,1477],[3066,1468]],'bed_upstream':3.6,'bed_downstream':3.45}]
# Limit construction to interruptions, rather than deepening the original streambed.
cut=np.zeros(h.shape,dtype=bool);distance=np.full(h.shape,np.inf)
for path in paths:
 pts=np.array(path['controls'],float);lengths=np.linalg.norm(np.diff(pts,axis=0),axis=1);total=lengths.sum();walk=0
 for a,b,length in zip(pts,pts[1:],lengths):
  v=b-a
  for z in range(int(min(a[1],b[1]))-5,int(max(a[1],b[1]))+6):
   for x in range(int(min(a[0],b[0]))-5,int(max(a[0],b[0]))+6):
    if not (2816<=x<3328 and 1280<=z<1792):continue
    t=float(np.clip(np.dot(np.array([x,z])-a,v)/np.dot(v,v),0,1));d=float(np.linalg.norm(np.array([x,z])-a-t*v));iz,ix=z-1280,x-2816
    if d>4:continue
    # Only raised interruptions. Leave all original low bed pixels byte-for-byte unchanged.
    original=float(h[iz,ix]);bed=path['bed_upstream']+(path['bed_downstream']-path['bed_upstream'])*(walk+t*length)/total
    profile=bed+max(0,d-1.2)*.8
    if original<=4.65 or profile>=original:continue
    after[iz,ix]=min(after[iz,ix],profile);cut[iz,ix]=True;distance[iz,ix]=min(distance[iz,ix],d)
  walk+=length
manifest=json.loads((P/'inputs.json').read_text());staged=[]
for r in manifest:
 x,z=r['location'];sl=(slice((z-5)*256,(z-4)*256),slice((x-11)*256,(x-10)*256));a=after[sl];orig=h[sl]
 if np.any(a!=orig):a.astype('<f4').tofile(P/(r['file']+'.rf'));r['changed_samples']=int(np.count_nonzero(a!=orig));staged.append(r)
assert np.all(after<=h);assert np.array_equal(h[h<=4.65],after[h<=4.65]);assert np.all((after==h)|cut)
(P/'to_apply.json').write_text(json.dumps(staged,indent=2));(P/'routes.json').write_text(json.dumps(paths,indent=2))
# Find roads crossing the excavated interruptions for subsequent bridge/culvert inspection.
roads=json.loads((P.parents[1]/'jsondata/roads.json').read_text());crossings=[]
for r in roads:
 hit=[]
 for aa,bb in zip(r['points'],r['points'][1:]):
  a=np.array(aa['pos']);b=np.array(bb['pos'])
  for t in np.linspace(0,1,max(2,int(np.linalg.norm((b-a)[::2])*2))):
   p=a+(b-a)*t;x,z=round(p[0]),round(p[2])
   if 2816<=x<3328 and 1280<=z<1792 and cut[z-1280,x-2816] and h[z-1280,x-2816]-after[z-1280,x-2816]>.5:hit.append([x,z])
 if hit:crossings.append({'road_num':r['num'],'name':r['name'],'near_xz':hit[len(hit)//2]})
report={'changed_samples':int(np.count_nonzero(after!=h)),'max_cut':round(float((h-after).max()),3),'regions':len(staged),'existing_low_beds_unchanged':True,'roads_for_crossing_review':crossings,'surface_added':False,'paint_changed':False,'scope':'Missing links within current model excavations; not a wholesale historical rerouting.'}
(P/'report.json').write_text(json.dumps(report,indent=2));np.save(P/'after.npy',after)
im=Image.open(P/'channel-inspection.png').convert('RGB');dr=ImageDraw.Draw(im)
for iz,ix in np.argwhere(cut):
 if h[iz,ix]-after[iz,ix]>.1:dr.rectangle((ix*2,iz*2,ix*2+1,iz*2+1),fill=(220,75,35))
im.save(P/'excavated-links.png');print(json.dumps(report))
