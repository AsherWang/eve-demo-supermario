"""Share the portable repository-wide capture lock with other level workers."""
from contextlib import contextmanager
from world23_capture_lock import capture_lock

@contextmanager
def world24_capture_lock():
    with capture_lock("world2-native-or-reference"):
        yield
