"""Download small GUGiK WCS tiles; run with /usr/bin/python3."""
from pathlib import Path
import concurrent.futures, urllib.request, urllib.parse, time, json, os
from osgeo import gdal
gdal.UseExceptions()
ROOT=Path(__file__).resolve().parent/'originals'/'nmt_tiles'
ROOT.mkdir(exist_ok=True)
BASE='https://mapy.geoportal.gov.pl/wss/service/PZGIK/NMT/GRID1/WCS/DigitalTerrainModelFormatTIFF?'
def fetch(rc):
 r,c=rc;x=477000+c*2500;y=723500-r*2500
 name=ROOT/('nmt_%02d_%02d.tif'%(r,c))
 if name.exists():return r,c,'cached'
 params=dict(SERVICE='WCS',VERSION='1.0.0',REQUEST='GetCoverage',COVERAGE='DTM_PL-KRON86-NH_TIFF',CRS='EPSG:2180',BBOX=','.join(map(str,[x,y-2500,x+2500,y])),WIDTH=250,HEIGHT=250,FORMAT='image/tiff',INTERPOLATION='bilinear')
 u=BASE+urllib.parse.urlencode(params)
 for trial in range(3):
  try:
   data=urllib.request.urlopen(u,timeout=50).read()
   if data[:2] not in [b'II',b'MM']:raise ValueError(data[:250])
   tmp=name.with_suffix('.%s.part.tif'%os.getpid());tmp.write_bytes(data)
   ds=gdal.Open(str(tmp));assert ds.RasterXSize==250 and ds.RasterYSize==250;ds=None
   tmp.rename(name)
   return r,c,len(data)
  except Exception as e:
   if trial==2:return r,c,'ERROR '+str(e)
   time.sleep(1+trial)
START_ROW=int(os.environ.get('NMT_START_ROW','0'))
jobs=[(r,c) for r in range(START_ROW,15) for c in range(15)]
done=[]
with concurrent.futures.ThreadPoolExecutor(3) as pool:
 for result in pool.map(fetch,jobs):
  done.append(result)
  if len(done)%15==0 or isinstance(result[2],str) and result[2].startswith('ERROR'):print(len(done),'/',len(jobs),result,flush=True)
(ROOT/('requests.json' if START_ROW==0 else 'requests_row%d.json'%START_ROW)).write_text(json.dumps({'base':BASE,'coverage':'DTM_PL-KRON86-NH_TIFF','tile_size_m':2500,'output_spacing_m':10,'tile_shape':[250,250],'upper_left_epsg2180':[477000,723500],'results':done},indent=2))
assert not any(isinstance(z[2],str) and z[2].startswith('ERROR') for z in done)
if len(list(ROOT.glob('nmt_*.tif')))==225:
 gdal.BuildVRT(str(ROOT.parent/'poland_nmt_tiled.vrt'),[str(f) for f in sorted(ROOT.glob('nmt_*.tif'))])
 print('Tiled mosaic ready',flush=True)
