"""Reusable static vehicle exporter, generalized from export_harz_99_23_24.py.

blender -b --python tools/vehicles/export_vehicle.py -- --config CONFIG.json
Sources are appended, never saved. Component meshes/materials stay separate.
Assembly uses Blender XYZ; runtime shift seats treads at Y=0 in Godot and
centres EXPLICIT coupling attachment points, not an asymmetric visual bbox.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bounds(objects):
    points=[o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return [[min(v[i] for v in points),max(v[i] for v in points)] for i in range(3)]

def geometry(obj):
    m=obj.data
    return digest_bytes(repr(([tuple(v.co) for v in m.vertices], [tuple(p.vertices) for p in m.polygons],
             [p.use_smooth for p in m.polygons],[tuple(n.vector) for n in m.corner_normals],
             {uv.name:[tuple(p.uv) for p in uv.data] for uv in m.uv_layers})).encode())

def digest_bytes(data):
    return hashlib.sha256(data).hexdigest()

def export(config_path):
    cfg=json.loads(config_path.read_text())
    dest=ROOT/cfg['destination'];dest.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    components=[];objects=[]
    for c in cfg['components']:
        path=Path(c['source']);sha=digest(path)
        with bpy.data.libraries.load(str(path),link=False) as (src,data):
            assert c['object'] in src.objects, c['object']
            data.objects=[c['object']]
        obj=data.objects[0];scene.collection.objects.link(obj)
        assert obj.type=='MESH' and obj.parent is None and not obj.modifiers
        obj.name=c['name'];obj.location+=Vector(c.get('offset_xyz',[0,0,0]))
        obj.hide_render=False;obj.hide_set(False)
        bpy.context.view_layer.update()
        mesh=obj.data;mesh.calc_loop_triangles()
        assert len(mesh.loop_triangles)==c['triangles']
        assert len(mesh.materials)==1
        atlas=c['atlas_uv'];assert atlas in mesh.uv_layers
        # Explicit UV nodes must reference the same atlas as the export channel.
        for n in mesh.materials[0].node_tree.nodes:
            if n.type=='UVMAP':assert n.uv_map==atlas
            if n.type=='TEX_IMAGE':assert n.image and n.image.packed_file
        components.append(dict(c,sha256=sha,geometry_uv_normals_sha256=geometry(obj),bounds_xyz=bounds([obj])))
        objects.append(obj)
    assert len({m for o in objects for m in o.data.materials})==cfg['material_count']
    assembly_bounds=bounds(objects)
    assembly=Path(cfg['assembly_blend']);assembly.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(assembly))
    bpy.ops.wm.open_mainfile(filepath=str(assembly),use_scripts=False)
    objects=[bpy.data.objects[c['name']] for c in cfg['components']]
    for obj,c in zip(objects,components):assert geometry(obj)==c['geometry_uv_normals_sha256']
    # Strip legacy UV layers only AFTER saving the editable assembly.
    center_y=sum(cfg['coupler_y_metres'])/2
    tread=cfg['tread_z_metres']
    for obj,c in zip(objects,cfg['components']):
        obj.location.y-=center_y;obj.location.z-=tread
        for layer in list(obj.data.uv_layers):
            if layer.name!=c['atlas_uv']:obj.data.uv_layers.remove(layer)
        obj.data.uv_layers.active_index=0;obj.data.uv_layers[0].active_render=True
        triangulate=obj.modifiers.new('Export triangulation','TRIANGULATE')
        if hasattr(triangulate,'keep_custom_normals'):triangulate.keep_custom_normals=True
    bpy.context.view_layer.update()
    runtime_bounds=bounds(objects)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    target=dest/(cfg['key']+'.gltf')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLTF_SEPARATE',use_selection=True,
        export_yup=True,export_apply=True,export_materials='EXPORT',export_texcoords=True,export_normals=True,
        export_tangents=True,export_animations=False,export_cameras=False,export_lights=False,
        export_skins=False,export_morph=False)
    doc=json.loads(target.read_text())
    assert len(doc['meshes'])==len(objects) and len(doc['materials'])==cfg['material_count']
    total=sum(c['triangles'] for c in components)
    assert sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])==total
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            assert 'TEXCOORD_0' in p['attributes'] and 'TEXCOORD_1' not in p['attributes']
            assert 'NORMAL' in p['attributes'] and 'TANGENT' in p['attributes']
    for resource in doc.get('buffers',[])+doc.get('images',[]):
        if 'uri' in resource:assert (dest/resource['uri']).is_file()
    # Re-import the actual staged glTF, then verify mesh/material/UV counts.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(target))
    imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(imported)==len(objects)
    tris=0
    for o in imported:
        o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
        assert len(o.data.uv_layers)==1
    assert tris==total
    # glTF import converts Y-up back to Blender Z-up.
    for expected,actual in zip(runtime_bounds,bounds(imported)):
        assert all(abs(a-b)<.0001 for a,b in zip(expected,actual)),(expected,actual)
    for c in components:assert digest(Path(c['source']))==c['sha256']
    report={'config':str(config_path),'assembly_blend':str(assembly),'components':components,
        'meshes':len(imported),'materials':len(doc['materials']),'triangles':tris,
        'assembly_bounds_xyz':assembly_bounds,'runtime_bounds_xyz':runtime_bounds,
        'coupler_envelope_length_metres':abs(cfg['coupler_y_metres'][1]-cfg['coupler_y_metres'][0]),
        'centering_blender_y':-center_y,'tread_correction_blender_z':-tread,
        'godot_forward':'-Z (Blender +Y)','sources_preserved':True,'assembly_saved_reopened':True,
        'gltf_reimport_verified':True,'atlas_uv_only':True,'gltf':str(target),
        'textures':[i.get('uri') for i in doc.get('images',[])], 'notes':cfg.get('notes',[])}
    (dest.parent/'import_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VEHICLE_EXPORT_OK '+json.dumps(report))

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--config',required=True,type=Path)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);export(args.config.resolve())
