"""Serialize offline graphical captures with the other level workers."""
from contextlib import contextmanager
from pathlib import Path
import json
import os
import uuid

LOCK = Path('D:/workspace/eve-demos/super-mario/local-parity/gpu-capture.lock')

@contextmanager
def capture_lock(task):
    token = str(uuid.uuid4())
    try:
        LOCK.mkdir()
    except FileExistsError:
        raise RuntimeError(f'Capture occupied: {LOCK}; retry after the owner releases it')
    owner = LOCK / 'owner.json'
    try:
        owner.write_text(json.dumps(dict(token=token, task=task, pid=os.getpid())), encoding='utf-8')
        yield
    finally:
        if owner.exists() and json.loads(owner.read_text(encoding='utf-8')).get('token') == token:
            owner.unlink()
            LOCK.rmdir()
