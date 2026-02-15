#!/usr/bin/env python3
"""Simulates ransomware-like file activity for testing heuristic detectors."""

# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "cryptography",
# ]
# ///

import os
import random
import shutil
import signal
import string
import sys
import tempfile
import time
from cryptography.fernet import Fernet

NUM_FILES = 5000
MIN_SIZE = 64          # bytes
MAX_SIZE = 500 * 1024  # 500 KB
REPORT_EVERY = 100

# Realistic file types to seed the directory with before "encrypting"
EXTENSIONS = [".docx", ".pdf", ".xlsx", ".jpg", ".png", ".txt", ".csv", ".pptx"]

LOREM = (
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod "
    "tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, "
    "quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo "
    "consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse "
    "cillum dolore eu fugiat nulla pariatur.\n"
)

workdir = None
count = 0
t0 = None


def cleanup():
    if workdir and os.path.isdir(workdir):
        shutil.rmtree(workdir, ignore_errors=True)
        print(f"Cleaned up: {workdir}")


def on_signal(signum, frame):
    name = signal.Signals(signum).name
    elapsed = time.perf_counter() - t0 if t0 else 0
    print(f"\n*** BLOCKED/KILLED by {name} after {count} files in {elapsed:.2f}s ***")
    cleanup()
    sys.exit(1)


def main():
    global workdir, count, t0

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGHUP, on_signal)

    key = Fernet.generate_key()
    cipher = Fernet(key)

    workdir = tempfile.mkdtemp(prefix="ransomtest_")
    print(f"Writing to: {workdir}")

    # Phase 1: Seed with realistic low-entropy files
    print(f"Phase 1: Seeding {NUM_FILES} realistic files...")
    filenames = []
    for i in range(NUM_FILES):
        frac = i / max(NUM_FILES - 1, 1)
        size = int(MIN_SIZE + frac * (MAX_SIZE - MIN_SIZE))
        ext = random.choice(EXTENSIONS)
        name = f"document_{i:06d}{ext}"
        path = os.path.join(workdir, name)
        # Repeating text = low entropy, like real docs
        plaintext = (LOREM * ((size // len(LOREM)) + 1))[:size].encode()
        with open(path, "wb") as f:
            f.write(plaintext)
        filenames.append(name)
    print(f"  Seeded {len(filenames)} files")

    # Phase 2: Read each file, encrypt it, replace with .enc
    print(f"Phase 2: Encrypting files in-place...")
    t0 = time.perf_counter()
    total_bytes = 0

    try:
        for i, name in enumerate(filenames):
            src = os.path.join(workdir, name)
            dst = os.path.join(workdir, name + ".enc")

            with open(src, "rb") as f:
                plaintext = f.read()

            encrypted = cipher.encrypt(plaintext)

            with open(dst, "wb") as f:
                f.write(encrypted)
            os.remove(src)

            count += 1
            total_bytes += len(encrypted)

            if count % REPORT_EVERY == 0:
                frac = i / max(NUM_FILES - 1, 1)
                size = int(MIN_SIZE + frac * (MAX_SIZE - MIN_SIZE))
                elapsed = time.perf_counter() - t0
                rate = count / elapsed
                mb = total_bytes / (1024 * 1024)
                print(f"  {count} files  |  ~{size // 1024:>3} KB each  |  {mb:.1f} MB total  |  {elapsed:.2f}s  |  {rate:.0f} files/s")

        elapsed = time.perf_counter() - t0
        mb = total_bytes / (1024 * 1024)
        print(f"\nCompleted. {count} files, {mb:.1f} MB in {elapsed:.2f}s ({count/elapsed:.0f} files/s)")
        print("Detector did NOT intervene.")

    except PermissionError as e:
        elapsed = time.perf_counter() - t0
        print(f"\n*** BLOCKED by PermissionError after {count} files in {elapsed:.2f}s ***")
        print(f"  {e}")

    except OSError as e:
        elapsed = time.perf_counter() - t0
        print(f"\n*** BLOCKED by OSError after {count} files in {elapsed:.2f}s ***")
        print(f"  {e}")

    finally:
        cleanup()


if __name__ == "__main__":
    main()
