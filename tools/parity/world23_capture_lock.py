"""Serialize offline graphical captures with the other level workers."""
from contextlib import contextmanager
from pathlib import Path
import json
import os
import subprocess
import uuid

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
def capture_lock(task):
    lock = lock_directory()
    token = str(uuid.uuid4())
    try:
        lock.parent.mkdir(parents=True,exist_ok=True)
        lock.mkdir()
    except FileExistsError:
        raise RuntimeError(f'Capture occupied: {lock}; retry after the owner releases it')
    owner = lock / 'owner.json'
    try:
        owner.write_text(json.dumps(dict(token=token, task=task, pid=os.getpid())), encoding='utf-8', newline='\n')
        yield
    finally:
        if owner.exists() and json.loads(owner.read_text(encoding='utf-8')).get('token') == token:
            owner.unlink()
            lock.rmdir()
