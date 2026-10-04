# Headless: build every machinery collection and export GLBs for the web app.
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy
import fac

OUT = os.path.abspath(os.path.join(HERE, "..", "public", "models"))

# script, collection, glb filename
MACHINES = [
    ("burner_drill.py", "FF_burner_drill", "ff-burner-drill.glb"),
    ("electric_drill.py", "FF_electric_drill", "ff-electric-drill.glb"),
    ("pumpjack.py", "FF_pumpjack", "ff-pumpjack.glb"),
    ("waterpump.py", "FF_waterpump", "ff-waterpump.glb"),
    ("stone_furnace.py", "FF_stone_furnace", "ff-stone-furnace.glb"),
    ("steel_furnace.py", "FF_steel_furnace", "ff-steel-furnace.glb"),
    ("electric_furnace.py", "FF_electric_furnace", "ff-electric-furnace.glb"),
    ("assembler.py", "FF_assembler", "ff-assembler.glb"),
    ("belt.py", "FF_belt", "ff-belt.glb"),
    ("inserter.py", "FF_inserter", "ff-inserter.glb"),
    ("pole.py", "FF_pole", "ff-pole.glb"),
    ("boiler.py", "FF_boiler", "ff-boiler.glb"),
    ("steam_engine.py", "FF_steam_engine", "ff-steam-engine.glb"),
    ("solar.py", "FF_solar", "ff-solar.glb"),
    ("accumulator.py", "FF_accumulator", "ff-accumulator.glb"),
    ("gun_turret.py", "FF_gun_turret", "ff-gun-turret.glb"),
    ("laser_turret.py", "FF_laser_turret", "ff-laser-turret.glb"),
    ("wall.py", "FF_wall", "ff-wall.glb"),
    ("chest.py", "FF_chest", "ff-chest.glb"),
    ("refinery.py", "FF_refinery", "ff-refinery.glb"),
    ("chemplant.py", "FF_chemplant", "ff-chemplant.glb"),
    ("pipe.py", "FF_pipe", "ff-pipe.glb"),
    ("tank.py", "FF_tank", "ff-tank.glb"),
    ("reactor.py", "FF_reactor", "ff-reactor.glb"),
    ("centrifuge.py", "FF_centrifuge", "ff-centrifuge.glb"),
    ("silo.py", "FF_silo", "ff-silo.glb"),
    ("lab.py", "FF_lab", "ff-lab.glb"),
]


def _reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # factory empty still has a collection; keep it simple
    fac._MATERIALS_READY = False
    fac.ensure_base_materials()


def _run_script(filename):
    path = os.path.join(HERE, filename)
    g = {"__file__": path, "__name__": "__main__"}
    with open(path, "r", encoding="utf-8") as f:
        code = compile(f.read(), path, "exec")
    exec(code, g, g)


def main():
    only = [a for a in sys.argv[sys.argv.index("--") + 1:]
            if not a.startswith("-")] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    fac.ensure_base_materials()
    failed = []
    for script, collection, glb in MACHINES:
        if only and script not in only and glb not in only and collection not in only:
            continue
        print("=" * 60)
        print("BUILD", script)
        try:
            _run_script(script)
            dest = os.path.join(OUT, glb)
            fac.export_collection(collection, dest)
        except Exception:
            traceback.print_exc()
            failed.append(script)
    characters = [
        ("player.py", [("FF_player", "ff-player.glb")]),
        ("biter.py", [
            ("FF_biter", "ff-biter.glb"),
            ("FF_spitter", "ff-spitter.glb"),
            ("FF_nest", "ff-nest.glb"),
        ]),
    ]
    for script, pairs in characters:
        if only and script not in only and not any(
            g in only or c in only for c, g in pairs
        ):
            continue
        print("=" * 60)
        print("BUILD", script)
        try:
            _run_script(script)
            for collection, glb in pairs:
                dest = os.path.join(OUT, glb)
                fac.export_collection(collection, dest)
        except Exception:
            traceback.print_exc()
            failed.append(script)
    if failed:
        print("FAILED:", ", ".join(failed))
        raise SystemExit(1)
    print("ALL MACHINERY EXPORTED to", OUT)


if __name__ == "__main__":
    main()
