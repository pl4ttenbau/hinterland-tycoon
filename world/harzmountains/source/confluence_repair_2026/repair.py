from pathlib import Path
import numpy as np,json
from PIL import Image,ImageDraw
P=Path(__file__).parent
h=np.zeros((512,512),dtype=np.float32)
for r in json.loads((P/'live_inputs.json').read_text()):
 x,z=r['location'];h[(z-5)*256:(z-4)*256,(x-11)*256:(x-10)*256]=np.fromfile(P/(r['file']+'.live.rf'),dtype='<f4').reshape(256,256)
after=h.copy();zz,xx=np.indices(h.shape);x=xx+2816;z=zz+1280
# Retain a simple Y: western Holtemme, southeastern Zillierbach, northern outlet.
paths=[[[2989,1580],[2974,1568],[2961,1550],[2950,1528],[2946,1505],[2947,1480],[2949,1455],[2952,1430],[2956,1405],[2961,1382],[2966,1360],[2971,1342],[2975,1330]],[[3139,1542],[3128,1532],[3110,1528],[3096,1523],[3089,1510],[3084,1495],[3077,1482],[3066,1468],[3056,1452],[3042,1440],[3032,1434],[3020,1429],[3008,1423],[2998,1413],[2990,1402],[2984,1388],[2980,1372],[2976,1355],[2975,1330]],[[2975,1330],[2972,1318],[2973,1304],[2970,1290]]]
# Round the control polylines into continuous bank shapes.
def smooth(a):
 a=np.array(a,float);out=[]
 for i in range(len(a)-1):
  p,q=a[i:i+2];m=(q-a[max(0,i-1)])*.4;n=(a[min(len(a)-1,i+2)]-p)*.4
  for t in np.linspace(0,1,12)[:-1]:out.append((2*t**3-3*t*t+1)*p+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*q+(t**3-t*t)*n)
 return np.array(out+[a[-1]])
d=np.full(h.shape,np.inf)
for path in paths:
 ps=smooth(path)
 for a,b in zip(ps,ps[1:]):
  v=b-a;tt=np.clip(((x-a[0])*v[0]+(z-a[1])*v[1])/np.dot(v,v),0,1);dd=np.sqrt((x-a[0]-tt*v[0])**2+(z-a[1]-tt*v[1])**2);d=np.minimum(d,dd)
# Explicit local repair area. Fill ALL depressions outside retained channels above live water.
zone=(x>=2932)&(x<=3146)&(z>=1295)&(z<=1580)
water=np.full(h.shape,-1e6)
for w in json.loads((P/'live_water.json').read_text()):
 o=np.array(w['origin']);bx=np.array(w['basis_x']);bz=np.array(w['basis_z']);mat=np.array([[bx[0],bz[0]],[bx[2],bz[2]]]);inv=np.linalg.inv(mat);u=inv[0,0]*(x-o[0])+inv[0,1]*(z-o[2]);v=inv[1,0]*(x-o[0])+inv[1,1]*(z-o[2]);inside=(abs(u)<=w['size'][0]/2)&(abs(v)<=w['size'][1]/2);y=o[1]+u*bx[1]+v*bz[1];water=np.maximum(water,np.where(inside,y,-1e6))
# Reconstruct the abandoned scars using surrounding dry bank heights, not low-bed preservation.
fill=zone&(d>4.5)&(h<water+.5)
base=np.maximum(h,water+.65)
# Iterative neighbour diffusion only inside filled scars; hard lower bound prevents water exposure.
for _ in range(120):
 mean=(np.roll(base,1,0)+np.roll(base,-1,0)+np.roll(base,1,1)+np.roll(base,-1,1))/4
 base[fill]=np.maximum(mean[fill],water[fill]+.65)
after[fill]=base[fill]
# Defined cross section, no leftover islands in retained beds.
bed=3.3+np.clip((z-1330)/250,0,1)*.8
profile=bed+np.maximum(d-1.4,0)*.9
cut=zone&(d<=4.5);after[cut]=np.minimum(after[cut],profile[cut])
# Ensure no unwanted water patch survives outside the two-stream footprint.
assert not np.any(zone&(d>4.5)&(after<water))
assert np.array_equal(after[~zone],h[~zone])
rows=[]
for r in json.loads((P/'live_inputs.json').read_text()):
 rx,rz=r['location'];sl=(slice((rz-5)*256,(rz-4)*256),slice((rx-11)*256,(rx-10)*256));a=after[sl]
 if np.any(a!=h[sl]):a.astype('<f4').tofile(P/(r['file']+'.fixed.rf'));rows.append(r)
(P/'repair_regions.json').write_text(json.dumps(rows,indent=2));np.save(P/'fixed.npy',after);np.save(P/'live_before.npy',h)
report={'regions':len(rows),'raised_samples':int(np.count_nonzero(after>h)),'lowered_samples':int(np.count_nonzero(after<h)),'unwanted_water_pixels_after':int(np.count_nonzero(zone&(d>4.5)&(after<water))),'outside_selection_unchanged':True}
(P/'repair_report.json').write_text(json.dumps(report,indent=2));print(report)
for name,hh in [('before',h),('after',after)]:
 gz,gx=np.gradient(hh);shade=np.clip(.85-gx*.35-gz*.35,.25,1);rgb=np.stack([np.full(h.shape,195),np.full(h.shape,207),np.full(h.shape,168)],axis=-1)*shade[:,:,None];rgb[hh<water]=[35,69,84];im=Image.fromarray(rgb.clip(0,255).astype('uint8')).crop((100,0,350,330)).resize((750,990));im.save(P/('water-visible-'+name+'.png'))
