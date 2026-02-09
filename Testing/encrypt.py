#!/usr/bin/env python3

import os
import time
import shutil
import secrets

OUTPUT_DIR = "/tmp/rw_test"
NUM_FILES = 5
FILE_SIZE = 65536
CLEANUP_DELAY = 10

os.makedirs(OUTPUT_DIR, exist_ok=True)

for i in range(NUM_FILES):
    data = secrets.token_bytes(FILE_SIZE)
    path = os.path.join(OUTPUT_DIR, f"test_file_{i}.enc")
    with open(path, "wb") as f:
        f.write(data)
    print(f"created: {path}")

print(f"\ndone - {NUM_FILES} encrypted files in {OUTPUT_DIR}")
print(f"cleaning up in {CLEANUP_DELAY} seconds...")

time.sleep(CLEANUP_DELAY)
shutil.rmtree(OUTPUT_DIR)
print("cleaned up")
