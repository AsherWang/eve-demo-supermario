"""Capture World 2 normal-entrance diagnostics; does not claim ROM origin parity.

The common strict-stage registry remains unchanged. Use stage-specific reference
origins and six-gate reports before declaring strict acceptance.
"""
import run_actual
from world24_capture_lock import world24_capture_lock

def require_world2_normal(movie):
    if movie.get("world") != 2 or movie.get("level") not in (2,3,4):
        raise ValueError("World 2 stages 2..4 only")
    if movie.get("runtime_origin") != "normal-entrance":
        raise ValueError("set runtime_origin=normal-entrance explicitly for gameplay capture")
    if movie.get("checkpoint_page",0):
        raise ValueError("normal entrances only; probes use their own runners")
    return 2,movie["level"]

original_source=run_actual.squirrel_source
def normal_source(movie, output):
    # Normal gameplay verification consumes every input frame, with no saved-ROM
    # origin friction override or skipped first simulation step.
    return original_source(movie,output)+"\nPARITY_NORMAL_ENTRY <- true;\n"

if __name__=="__main__":
    run_actual.require_supported_stage=require_world2_normal
    run_actual.squirrel_source=normal_source
    with world24_capture_lock():
        raise SystemExit(run_actual.main())
