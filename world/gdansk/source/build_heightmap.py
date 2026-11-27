"""Build the agreed 3600-square terrain. Run: PYTHONNOUSERSITE=1 /usr/bin/python3 build_heightmap.py"""
from pathlib import Path
import json, math, struct, shutil, hashlib, datetime
import numpy as np
from osgeo import gdal, ogr, osr
from PIL import Image, ImageDraw
gdal.UseExceptions();ogr.UseExceptions();osr.UseExceptions()
ROOT=Path(__file__).resolve().parent
N=3600;WEST,SOUTH,EAST,NORTH=18.6600,54.0465,19.2130,54.3700
WATER_LEVEL=20.;OFFSET=20.
def srs(code):
 s=osr.SpatialReference();s.SetFromUserInput(code);s.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER);return s
WGS=srs('EPSG:4326')
LOCAL=srs('+proj=eqc +lat_ts=54.20825 +lat_0=54.20825 +lon_0=18.9365 +datum=WGS84 +units=m +no_defs')
CT=osr.CoordinateTransformation(WGS,LOCAL)
nw=CT.TransformPoint(WEST,NORTH);se=CT.TransformPoint(EAST,SOUTH)
DX=(se[0]-nw[0])/(N-1);DY=(nw[1]-se[1])/(N-1)
GT=(nw[0]-DX/2,DX,0,nw[1]+DY/2,0,-DY)
EXTENT=[GT[0],GT[3]-N*DY,GT[0]+N*DX,GT[3]]
def mem(dtype=gdal.GDT_Float32):
 d=gdal.GetDriverByName('MEM').Create('',N,N,1,dtype);d.SetGeoTransform(GT);d.SetProjection(LOCAL.ExportToWkt());return d
def save_tif(name,a,dtype=gdal.GDT_Float32):
 d=gdal.GetDriverByName('GTiff').Create(str(ROOT/name),N,N,1,dtype,options=['COMPRESS=DEFLATE','PREDICTOR=3' if dtype==gdal.GDT_Float32 else 'PREDICTOR=2','TILED=YES'])
 d.SetGeoTransform(GT);d.SetProjection(LOCAL.ExportToWkt());d.GetRasterBand(1).WriteArray(a);d.FlushCache();d=None
def warp(path):
 return gdal.Warp('',str(path),format='MEM',dstSRS=LOCAL.ExportToWkt(),outputBounds=EXTENT,width=N,height=N,resampleAlg='bilinear',dstNodata=-9999,outputType=gdal.GDT_Float32).ReadAsArray()
def ring(c):
 r=ogr.Geometry(ogr.wkbLinearRing)
 for x,y in c:r.AddPoint_2D(x,y)
 r.CloseRings();return r
def polygon(c,holes=()):
 p=ogr.Geometry(ogr.wkbPolygon);p.AddGeometry(ring(c))
 for h in holes:p.AddGeometry(ring(h))
 return p
def geometry(coords):return [[p['lon'],p['lat']] for p in coords]
def stitch(parts):
 parts=[p[:] for p in parts if len(p)>1];closed=[];unclosed=[]
 def same(a,b):return abs(a[0]-b[0])<1e-7 and abs(a[1]-b[1])<1e-7
 while parts:
  c=parts.pop()
  while not same(c[0],c[-1]):
   hit=False
   for i,b in enumerate(parts):
    if same(c[-1],b[0]):c+=b[1:]
    elif same(c[-1],b[-1]):c+=b[-2::-1]
    elif same(c[0],b[-1]):c=b[:-1]+c
    elif same(c[0],b[0]):c=b[:0:-1]+c
    else:continue
    parts.pop(i);hit=True;break
   if not hit:break
  (closed if same(c[0],c[-1]) else unclosed).append(c)
 return closed,unclosed
def rasterize(gs):
 vd=ogr.GetDriverByName('Memory').CreateDataSource('');ly=vd.CreateLayer('water',LOCAL,ogr.wkbUnknown)
 count=0
 for geom in gs:
  if geom is None or geom.IsEmpty():continue
  if not geom.IsValid():geom=geom.MakeValid()
  f=ogr.Feature(ly.GetLayerDefn());f.SetGeometry(geom);ly.CreateFeature(f);count+=1
 dst=mem(gdal.GDT_Byte);gdal.RasterizeLayer(dst,[1],ly,burn_values=[1],options=['ALL_TOUCHED=TRUE'])
 return dst.ReadAsArray().astype(bool),count
def projected(p):
 p.AssignSpatialReference(WGS);p.Transform(CT);return p
def proximity(a,target):
 src=mem(gdal.GDT_Byte);src.GetRasterBand(1).WriteArray(a.astype(np.uint8));dst=mem()
 gdal.ComputeProximity(src.GetRasterBand(1),dst.GetRasterBand(1),options=['VALUES='+str(target),'DISTUNITS=PIXEL'])
 return dst.ReadAsArray()*((DX+DY)/2)
def blur(a,sigma):
 radius=int(math.ceil(3*sigma));xx=np.arange(-radius,radius+1);k=np.exp(-xx**2/(2*sigma**2));k/=k.sum()
 result=a.astype(np.float32)
 for axis in [0,1]:
  pads=[(0,0),(0,0)];pads[axis]=(radius,radius);p=np.pad(result,pads,mode='edge');z=np.zeros_like(result)
  for j,w in enumerate(k):
   sl=[slice(None),slice(None)];sl[axis]=slice(j,j+N);z+=p[tuple(sl)]*w
  result=z
 return result
def write_exr(path,a):
 def attr(n,t,d):return n.encode()+b'\0'+t.encode()+b'\0'+struct.pack('<I',len(d))+d
 ch=b''.join(n+b'\0'+struct.pack('<iB3xii',2,0,1,1) for n in [b'B',b'G',b'R'])+b'\0'
 box=struct.pack('<4i',0,0,N-1,N-1)
 header=struct.pack('<II',20000630,2)+attr('channels','chlist',ch)+attr('compression','compression',b'\0')+attr('dataWindow','box2i',box)+attr('displayWindow','box2i',box)+attr('lineOrder','lineOrder',b'\0')+attr('pixelAspectRatio','float',struct.pack('<f',1))+attr('screenWindowCenter','v2f',struct.pack('<ff',0,0))+attr('screenWindowWidth','float',struct.pack('<f',1))+attr('comments','string',b'Linear RGB Float32 elevation metres. North at row 0. Water surface 20m. No gamma transform.')+b'\0'
 rowbytes=N*12;start=len(header)+8*N
 with open(path,'wb') as f:
  f.write(header)
  for y in range(N):f.write(struct.pack('<Q',start+y*(8+rowbytes)))
  for y in range(N):
   r=a[y].astype('<f4').tobytes();f.write(struct.pack('<ii',y,rowbytes));f.write(r);f.write(r);f.write(r)
def read_validate_exr(path,a):
 with open(path,'rb') as f:
  assert struct.unpack('<II',f.read(8))==(20000630,2)
  attrs={}
  def cstr():
   b=b''
   while True:
    c=f.read(1)
    if c==b'\0':return b.decode()
    if not c:raise ValueError('Truncated EXR')
    b+=c
  while True:
   n=cstr()
   if not n:break
   t=cstr();size=struct.unpack('<I',f.read(4))[0];attrs[n]=(t,f.read(size))
  assert attrs['compression'][1]==b'\0'
  assert struct.unpack('<4i',attrs['dataWindow'][1])==(0,0,N-1,N-1)
  channels=attrs['channels'][1]
  assert channels.count(struct.pack('<iB3xii',2,0,1,1))==3
  offsets=struct.unpack('<'+'Q'*N,f.read(8*N));maximum=0.
  for y,offset in enumerate(offsets):
   f.seek(offset);yy,size=struct.unpack('<ii',f.read(8));assert yy==y and size==N*12
   rgb=np.frombuffer(f.read(size),dtype='<f4').reshape(3,N)
   assert np.isfinite(rgb).all() and np.array_equal(rgb[0],rgb[1]) and np.array_equal(rgb[1],rgb[2])
   maximum=max(maximum,float(np.max(np.abs(rgb[0]-a[y]))))
  assert maximum==0.
 return {'scanlines_checked':N,'channels':'RGB Float32','max_roundtrip_error_m':maximum,'dimensions':[N,N],'finite':True}

def make_preview(terrain,water):
 # Max-pool the water footprint so narrow channels survive preview downsampling.
 z=terrain.reshape(900,4,900,4).mean(axis=(1,3))
 counts=water.reshape(900,4,900,4).sum(axis=(1,3));wm=counts>0
 gy,gx=np.gradient(z,DX*4,DY*4)
 shade=np.clip((.75-gx*.7+gy*.45)/np.sqrt(1+gx*gx+gy*gy),.3,1)
 high=np.clip((z-20)/45,0,1)[...,None]
 rgb=(np.array([170,190,133])*(1-high)+np.array([210,195,154])*high)*shade[...,None]
 d=(((20-terrain)*water).reshape(900,4,900,4).sum(axis=(1,3))/np.maximum(counts,1))/15
 wc=np.stack([70-35*d,165-65*d,205-30*d],axis=-1);rgb[wm]=wc[wm]
 im=Image.fromarray(np.uint8(np.clip(rgb,0,255)));draw=ImageDraw.Draw(im)
 draw.rectangle((0,0,900,32),fill=(245,245,238))
 draw.text((12,9),'Gdansk / area A | terrain preview | north up | water y=20m',fill=(35,45,40))
 im.save(ROOT/'terrain_preview.png')

def main():
 print('Loading measured terrain',flush=True)
 source=ROOT/'originals/poland_nmt_tiled.vrt';assert source.exists()
 land=warp(source);assert np.isfinite(land).all() and not np.any(land==-9999)
 save_tif('land_dem_resampled_m.tif',land)
 raw=json.load(open(ROOT/'originals/osm_base.json'))['elements'];extra=json.load(open(ROOT/'originals/osm_water_extra.json'))['elements']
 chains=json.load(open(ROOT/'originals/coast_chains.json'))
 coast=[]
 for i in [1]:
  c=geometry(chains[i]);coast.append(projected(polygon(c+[[18.50,54.50],[18.50,53.90],[19.60,53.90],c[0]])))
 for i in [0,4,5,6,7,8]:
  c=geometry(chains[i]);coast.append(projected(polygon(c)))
 landmask,_=rasterize(coast);sea=~landmask
 polys=[];buffers=[];open_rings=0
 for x in raw+extra:
  t=x.get('tags',{})
  if x['type']=='way' and t.get('natural')=='water' and x.get('nodes',[0])[0]==x.get('nodes',[1])[-1]:polys.append(projected(polygon(geometry(x['geometry']))))
  if x['type']=='relation':
   outer,op=stitch([geometry(m['geometry']) for m in x.get('members',[]) if m.get('geometry') and m.get('role','outer') in ['outer','']]);inner,ip=stitch([geometry(m['geometry']) for m in x.get('members',[]) if m.get('geometry') and m.get('role')=='inner']);open_rings+=len(op)+len(ip)
   for c in outer:
    pg=polygon(c)
    for hole in inner:
     hp=polygon(hole)
     if pg.Contains(hp.PointOnSurface()):pg.AddGeometry(ring(hole))
    polys.append(projected(pg))
  if x['type']=='way' and t.get('waterway') in ['river','canal'] and x.get('geometry'):
   l=ogr.Geometry(ogr.wkbLineString)
   for p in geometry(x['geometry']):l.AddPoint_2D(*p)
   projected(l)
   try:w=float(t.get('width','').replace(' m',''))
   except (ValueError,TypeError):w=24. if t['waterway']=='river' else 12.
   buffers.append(l.Buffer(max(6.,w/2),8))
 inland,npolys=rasterize(polys+buffers);water=sea|inland
 save_tif('water_mask.tif',water.astype(np.uint8),gdal.GDT_Byte)
 print('Water area:',float(water.mean()),'polygon/buffer geometries:',npolys,'unclosed rings:',open_rings,flush=True)
 assert open_rings==0,'Incomplete OSM water polygons; inspect source.'
 near_land=proximity(water,0);near_water=proximity(water,1)
 # Inland beds are designed, not measured. Depth follows channel width.
 depth=2.+13.*(1.-np.exp(-near_land/95.))
 bath=warp(ROOT/'originals/emodnet_depth.tif')
 assert np.isfinite(bath).all() and not np.any(bath==-9999)
 # EMODnet signed elevations shape the seabed only; bounded gameplay depths
 # replace vertical-datum-sensitive absolute bathymetric elevations.
 ocean_depth=np.clip(-bath,2.,15.)
 depth=np.where(sea,ocean_depth,depth).astype(np.float32)
 weights=blur(water.astype(np.float32),2.)
 depth=blur(depth*water,2.)/np.maximum(weights,.000001)
 depth=np.clip(depth,2.,15.)
 # A submerged shelf joins the 2m-deep edge to the deeper channel over 70m.
 # Keep the first wet sample at 2m, including diagonal raster boundaries.
 edge_distance=max(DX,DY)*math.sqrt(2.)+0.001
 wet_ramp=np.clip((near_land-edge_distance)/70.,0.,1.)
 wet_ramp=wet_ramp*wet_ramp*(3.-2.*wet_ramp)
 depth=2.+(depth-2.)*wet_ramp
 beds=(WATER_LEVEL-depth).astype(np.float32)
 base=land+OFFSET
 # First dry sample meets the bank at 20.1m, then eases into measured land.
 # This retains a necessary 2.1m bank face imposed by the minimum wet depth.
 dry_ramp=np.clip((near_water-edge_distance)/80.,0.,1.)
 dry_ramp=dry_ramp*dry_ramp*(3.-2.*dry_ramp)
 blend=1.-dry_ramp
 terrain=(base*dry_ramp+20.1*blend).astype(np.float32)
 terrain[water]=beds[water]
 assert np.isfinite(terrain).all()
 depths=WATER_LEVEL-terrain[water]
 assert float(depths.min())>=1.99999 and float(depths.max())<=15.00001
 far=(~water)&(near_water>=edge_distance+80.)
 assert np.max(np.abs(terrain[far]-base[far]))<.00001
 save_tif('terrain_master_m.tif',terrain)
 exr=ROOT/'heightmap_gdansk.exr';write_exr(exr,terrain)
 validation=read_validate_exr(exr,terrain)
 # Independent georeferenced master read-back.
 master=gdal.Open(str(ROOT/'terrain_master_m.tif'))
 assert np.array_equal(master.ReadAsArray(),terrain)
 validation.update({'min_height_m':float(terrain.min()),'max_height_m':float(terrain.max()),'water_depth_min_m':float(depths.min()),'water_depth_max_m':float(depths.max()),'water_pixels':int(water.sum()),'dry_land_below_water_level_pixels':int(((~water)&(terrain<20)).sum()),'unclosed_water_rings':open_rings,'engine_import_tested':False})
 # Representative sampling establishes orientation and traceability.
 points=[]
 for name,lon,lat in [('Gdańsk narrow gauge',18.672508,54.346686),('Nowy Dwór',19.1150846,54.2146299),('Vistula',18.9400,54.3300),('Offshore',19.08,54.369),('Lisewo',18.830126,54.0970049)]:
  x,y,_=CT.TransformPoint(lon,lat);c=int(round((x-nw[0])/DX));r=int(round((nw[1]-y)/DY))
  points.append({'name':name,'latitude':lat,'longitude':lon,'pixel_col':c,'pixel_row':r,'raw_land_dem_m':float(land[r,c]),'output_height_m':float(terrain[r,c]),'water':bool(water[r,c])})
 validation['check_points']=points
 (ROOT/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
 manifest={'world_key':'gdansk','area':'A','created_date':'2026-11-03','bounds_wgs84_sample_centres':{'west':WEST,'south':SOUTH,'east':EAST,'north':NORTH},'dimensions':[N,N],'axis_order':'mapinfo corners are [latitude, longitude]','orientation':'north at row 0; west at column 0; Godot +X east, +Z south','horizontal_crs_wkt':LOCAL.ExportToWkt(),'geotransform_pixel_areas':list(GT),'sample_spacing_metres':[DX,DY],'span_between_outer_samples_metres':[(N-1)*DX,(N-1)*DY],'vertical_unit':'metres','land_source_vertical_datum':'PL-KRON86-NH as declared by GUGiK WCS coverage','land_elevation_offset_m':OFFSET,'land_vertical_scale':1.,'water_surface_height_m':WATER_LEVEL,'water_depth_range_m':[2.,15.],'bathymetry_method':'EMODnet signed elevation used to shape sea depth then clamped 2–15m; inland depth designed from distance to bank; no absolute vertical-datum equivalence claimed','river_bank_blending':'40m outside mapped water; 1.25-pixel normalized Gaussian bed smoothing; dry terrain beyond 40m unchanged','minimum_channel_width_m':12,'unmapped_width_defaults_m':{'river':24,'canal':12},'nodata':'GUGiK coverage audited tile by tile; source zero-only ocean cells excluded by coastline mask; no unknown land gaps silently filled','historical_limitations':'Contemporary DTM and OSM waterways, not reconstructed 1960 terrain. Modern embankments and infrastructure may remain.','water_rendering':'Use water meshes limited to water_mask footprint at y=20; a map-wide plane would flood real dry polders below sea level.','terrain3d_import':{'height_file':'heightmap_gdansk.exr','format':'32-bit float RGB; linear metre elevations; no alpha','height_scale':1,'height_offset':0,'suggested_vertex_spacing_m':10,'engine_span_m':35990,'horizontal_scale_vs_gis': [35990/((N-1)*DX),35990/((N-1)*DY)],'note':'10m spacing is suggested only; no engine scene/import created. Use exact anisotropic sample spacing in GIS; Terrain3D uniform spacing introduces the explicitly recorded tiny scale difference.'},'sources':[{'name':'GUGiK bare-earth NMT','url':'https://www.geoportal.gov.pl/pl/dane/numeryczny-model-terenu-nmt/','coverage':'DTM_PL-KRON86-NH_TIFF','native_grid_m':1,'download_grid_m':10,'horizontal_crs':'EPSG:2180','access_constraints':'WCS capabilities: none; fees none; retain attribution to GUGiK/PZGIK'},{'name':'EMODnet Bathymetry','url':'https://ows.emodnet-bathymetry.eu/wcs','coverage':'emodnet:mean','request_grid_degrees':.001041666667,'attribution':'EMODnet Bathymetry Consortium; retained WCS capabilities; underlying survey licences vary'},{'name':'OpenStreetMap contributors','url':'https://www.openstreetmap.org/copyright','licence':'ODbL 1.0','used_for':'coastline, water polygons, river/canal centrelines'}]}
 manifest['sources'][1].update({'release':'DTM 2024','doi':'https://doi.org/10.12770/cf51df64-56f9-4a99-b1aa-36b8d7b743a1','licence':'Creative Commons Attribution 4.0 International','source_vertical_datum':'Lowest Astronomical Tide (LAT)','attribution':'EMODnet Bathymetry Consortium (2024). EMODnet Digital Bathymetry (DTM 2024). Created by EMODnet, owned by the European Union.'})
 manifest['river_bank_blending']='2-pixel normalized Gaussian bed smoothing; first wet samples at depth 2m, easing into deeper beds over 70m; first dry samples at 20.1m, easing into measured land over 80m; outer limit about 94.2m from water samples; far-field unchanged'
 manifest['shoreline_constraint']='The 2m minimum depth requires a residual 2.1m step between adjacent wet/dry samples. No unapproved 0–2m-deep shoreline apron added.'
 manifest['exr_sha256']=hashlib.sha256(exr.read_bytes()).hexdigest()
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 info={'key':'gdansk','name':'Gdańskie Koleje Dojazdowe','loc':'POLAND','defaultYear':1960,'startPos':[0,0],'sizeAndPos':{'longLat':{'topLeft':[NORTH,WEST],'bottomRight':[SOUTH,EAST]},'rasterSize':[N,N],'rasterOffset':[-1800,-1800]}}
 (ROOT.parent/'jsondata/mapinfo.json').write_text(json.dumps(info,indent=2,ensure_ascii=False)+'\n')
 # Shaded preview only; never an elevation-import file.
 make_preview(terrain,water)
 print(json.dumps(validation,indent=2),flush=True)
if __name__=='__main__':main()
