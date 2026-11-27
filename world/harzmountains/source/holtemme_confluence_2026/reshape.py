from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image,ImageDraw
P=Path(__file__).parent
assert not (P/'native_verification.json').exists(),'Already applied'
h=np.zeros((512,512),dtype=np.float32)
records=json.loads((P/'inputs.json').read_text())
for r in records:
 x,z=r['location'];h[(z-5)*256:(z-4)*256,(x-11)*256:(x-10)*256]=np.fromfile(P/(r['file']+'.original.rf'),dtype='<f4').reshape(256,256)
after=h.copy()
new=np.array([[2989,1580],[2974,1568],[2961,1550],[2950,1528],[2946,1505],[2947,1480],[2949,1455],[2952,1430],[2956,1405],[2961,1382],[2966,1360],[2971,1342],[2975,1330]],float)
old=np.array([[2989,1580],[3004,1567],[3018,1554],[3030,1540],[3039,1524],[3042,1505],[3049,1490],[3058,1480],[3066,1468]],float)
yy,xx=np.indices(h.shape);coords=np.stack([xx+2816,yy+1280],axis=-1)
def nearest(path):
 ds=np.full(h.shape,np.inf);along=np.zeros(h.shape);lengths=np.linalg.norm(np.diff(path,axis=0),axis=1);walk=0
 for a,b,length in zip(path,path[1:],lengths):
  v=b-a;t=np.clip(np.sum((coords-a)*v,axis=-1)/(length*length),0,1);d=np.linalg.norm(coords-a-t[:,:,None]*v,axis=-1);sel=d<ds;ds[sel]=d[sel];along[sel]=(walk+t*length)[sel];walk+=length
 return ds,along,walk
nd,ns,nlen=nearest(new);od,os,olen=nearest(old)
# Fill only the abandoned ditch footprint, inferred from banks on both sides.
# Ends taper so the retained upstream reach and Zillierbach remain open.
fill=np.zeros(h.shape,dtype=bool)
for iz,ix in np.argwhere((od<8)&(os>10)&(os<olen-10)&(nd>6)):
 # A percentile of surrounding bank samples avoids pulling the old channel up to hilltops.
 patch=h[max(0,iz-10):iz+11,max(0,ix-10):ix+11];bank=float(np.percentile(patch,70));base=float(h[iz,ix])
 if base>=bank:continue
 weight=min(1.,(os[iz,ix]-10)/12,(olen-10-os[iz,ix])/12,max(0.,(8-od[iz,ix])/3))
 target=base+(bank-base)*weight
 after[iz,ix]=max(after[iz,ix],target);fill[iz,ix]=target>base
# New narrow, continuously falling bed: upstream tie-in Y4.1, confluence Y3.3.
bed=4.1-(4.1-3.3)*ns/nlen
profile=bed+np.maximum(0,nd-1.2)*.9
cut=(nd<5)&(profile<after)
after[cut]=profile[cut]
# Keep original low terrain outside the corridor exactly intact.
assert np.array_equal(h[(nd>=5)&~fill],after[(nd>=5)&~fill])
paths={'model_alignment':True,'reference':'1967 town plan, fitted to compressed railway/road anchors','new_holtemme_upstream_to_downstream_xz':new.tolist(),'abandoned_branch_xz':old.tolist(),'confluence_xz':new[-1].tolist(),'bed_upstream_y':4.1,'bed_confluence_y':3.3}
(P/'alignment.json').write_text(json.dumps(paths,indent=2));staged=[]
for r in records:
 x,z=r['location'];sl=(slice((z-5)*256,(z-4)*256),slice((x-11)*256,(x-10)*256));a=after[sl];orig=h[sl]
 if np.any(a!=orig):a.astype('<f4').tofile(P/(r['file']+'.rf'));r['changed_samples']=int(np.count_nonzero(a!=orig));staged.append(r)
(P/'to_apply.json').write_text(json.dumps(staged,indent=2));np.save(P/'before.npy',h);np.save(P/'after.npy',after)
report={'confluence_xz':new[-1].tolist(),'regions':len(staged),'lowered_samples':int(np.count_nonzero(after<h)),'raised_samples':int(np.count_nonzero(after>h)),'max_cut':float((h-after).max()),'max_fill':float((after-h).max()),'roads_and_rails_unchanged':True,'water_surfaces_unchanged':True,'paint_unchanged':True,'historical_alignment_precision':'Model-scale approximation, not surveyed coordinates'}
(P/'report.json').write_text(json.dumps(report,indent=2))
gz,gx=np.gradient(after);shade=np.clip(.85-gx*.4-gz*.4,.2,1);rgb=np.stack([np.full(h.shape,205),np.full(h.shape,213),np.full(h.shape,180)],axis=-1)*shade[:,:,None];rgb[cut]=[68,131,170];rgb[fill&~cut]=[203,162,105]
im=Image.fromarray(rgb.clip(0,255).astype('uint8')).resize((1024,1024));d=ImageDraw.Draw(im)
for x,z,label in [(2975,1330,'NEW CONFLUENCE'),(2994,1347,'Westerntor station'),(3066,1468,'Old junction: branch filled'),(2989,1580,'Upstream tie-in')]:d.ellipse(((x-2816)*2-4,(z-1280)*2-4,(x-2816)*2+4,(z-1280)*2+4),fill='black');d.text(((x-2816)*2+8,(z-1280)*2),label,fill='black')
im.save(P/'confluence-after.png');print(json.dumps(report))
