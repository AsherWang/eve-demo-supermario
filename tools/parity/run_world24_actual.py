"""Native World 2-4 capture using unchanged shared producer and strict stage selection."""
import run_actual
from world24_capture_lock import world24_capture_lock

def require_world24(movie):
    if (movie.get('world'),movie.get('level'))!=(2,4):
        raise ValueError('World 2-4 only')
    return 2,4
if __name__=='__main__':
    run_actual.require_supported_stage=require_world24
    with world24_capture_lock():
        raise SystemExit(run_actual.main())
