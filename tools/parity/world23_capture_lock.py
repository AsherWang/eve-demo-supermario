"""Serialize offline graphical captures with the other level workers."""
from contextlib import contextmanager
from pathlib import Path
import json
import os
import subprocess
import uuid
import time

ROOT = Path(__file__).resolve().parents[2]

def lock_directory():
    override = os.environ.get('SMB_GPU_CAPTURE_LOCK')
    if override:
        return Path(override).resolve()
    common = Path(subprocess.check_output(['git','rev-parse','--git-common-dir'],
        cwd=ROOT,text=True).strip())
    if not common.is_absolute(): common = ROOT / common
    return common.resolve().parent / 'local-parity/gpu-capture.lock'

@contextmanager
def capture_lock(task, wait_seconds=120):
    lock = lock_directory()
    token = str(uuid.uuid4())
    deadline = time.monotonic() + wait_seconds
    lock.parent.mkdir(parents=True,exist_ok=True)
    announced = False
    while True:
        try:
            lock.mkdir()
            break
        except FileExistsError:
            if time.monotonic() >= deadline:
                raise RuntimeError(f'Capture occupied: {lock}; owner retained after {wait_seconds}s')
            if not announced:
                print(f'Waiting for capture owner: {lock}', flush=True)
                announced = True
            time.sleep(min(1, max(0, deadline-time.monotonic())))
    owner = lock / 'owner.json'
    try:
        owner.write_text(json.dumps(dict(token=token, task=task, pid=os.getpid())), encoding='utf-8', newline='\n')
        yield
    finally:
        if owner.exists() and json.loads(owner.read_text(encoding='utf-8')).get('token') == token:
            owner.unlink()
            lock.rmdir()
