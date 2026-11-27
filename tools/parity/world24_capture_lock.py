"""Serialize stage 2-4 graphical evidence with other workers; never evict a lock."""
from contextlib import contextmanager
from pathlib import Path
import json, os, uuid, time
LOCK = Path('D:/workspace/eve-demos/super-mario/local-parity/gpu-capture.lock')
@contextmanager
def world24_capture_lock():
    token = str(uuid.uuid4())
    deadline=time.monotonic()+300
    while True:
        try:
            LOCK.mkdir();break
        except FileExistsError:
            if time.monotonic()>=deadline:raise RuntimeError('GPU capture busy: '+str(LOCK))
            time.sleep(1)
    owner = LOCK / 'world24-owner.json'
    try:
        owner.write_text(json.dumps(dict(stage='2-4', pid=os.getpid(), token=token)), newline="\n")
        yield
    finally:
        if owner.is_file() and json.loads(owner.read_text()).get('token') == token:
            owner.unlink()
            LOCK.rmdir()
