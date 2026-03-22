import bpy
import sys
import argparse


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--max-tris", type=int, default=8000)
    parser.add_argument("--normalize-scale", type=float, default=1.0)
    parser.add_argument("--center-origin", action="store_true", default=True)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main():
    args = parse_args()
    if args.dry_run:
        print(f"DRY RUN: {args.input} -> {args.output} (max {args.max_tris} tris)")
        return

    bpy.ops.wm.read_factory_settings(use_empty=True)

    bpy.ops.import_scene.gltf(filepath=args.input)

    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue

        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)

        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)

        if tris > args.max_tris:
            ratio = args.max_tris / tris
            mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
            mod.ratio = max(0.1, ratio)
            bpy.ops.object.modifier_apply(modifier=mod.name)

        if args.center_origin:
            bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")

        obj.select_set(False)

    if args.normalize_scale > 0:
        for obj in bpy.data.objects:
            if obj.type == "MESH":
                max_dim = max(obj.dimensions)
                if max_dim > 0:
                    scale_factor = args.normalize_scale / max_dim
                    obj.scale *= scale_factor
                    bpy.context.view_layer.objects.active = obj
                    obj.select_set(True)
                    bpy.ops.object.transform_apply(scale=True)
                    obj.select_set(False)

    bpy.ops.export_scene.gltf(
        filepath=args.output,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
    )
    print(f"Exported: {args.output}")


if __name__ == "__main__":
    main()
