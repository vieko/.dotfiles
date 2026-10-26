#!/usr/bin/env python3
"""Hold an OS lock while the shell waiter runs, without leaking it to hooks.

The supervisor owns the descriptor. The shell child owns the wait record.
Killing the shell child releases the lock even if a hook left children alive.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--script", required=True)
    parser.add_argument("--pr", required=True)
    parser.add_argument("--repo", default="")
    parser.add_argument("--target", required=True)
    parser.add_argument("--detach", choices=("0", "1"), required=True)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = ["gh", "pr", "view", args.pr, "--json", "number,url"]
    if args.repo:
        command += ["--repo", args.repo]
    resolved = subprocess.run(command, text=True, capture_output=True)
    if resolved.returncode:
        print("error: cannot resolve PR: " + resolved.stderr.strip(), file=sys.stderr)
        return 3
    try:
        pr = json.loads(resolved.stdout)
        match = re.fullmatch(r"https://([^/]+)/([^/]+)/([^/]+)/pull/(\d+)/?", pr["url"])
        if not match or int(match[4]) != pr["number"]:
            raise ValueError("invalid PR URL")
        identity = "/".join(match.groups()).lower()
    except (ValueError, KeyError, TypeError) as error:
        print(f"error: cannot resolve PR: {error}", file=sys.stderr)
        return 3
    target = args.target
    if target.startswith("claude:"):
        target = "claude:" + os.path.realpath(target[len("claude:"):])
    key = hashlib.sha256(json.dumps([identity, target]).encode()).hexdigest()
    directory = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "pr-wait/locks"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Never unlink a lock file: another process may already have it open.
    handle = open(directory / (key + ".lock"), "a+")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.seek(0)
        existing = handle.read().strip() or "starting"
        print(f"pr-wait: {identity} target {args.target} already has waiter {existing}; exiting", file=sys.stderr)
        return 4

    def record(pid):
        handle.seek(0)
        handle.truncate()
        handle.write(f"pid {pid}")
        handle.flush()

    record(os.getpid())
    detached = args.detach == "1"
    ready_fd = None
    log = ""
    if detached:
        safe = re.sub(r"[^A-Za-z0-9._-]", "_", args.pr)
        log = str(Path(os.environ.get("TMPDIR", "/tmp")) /
                  f"pr-wait-{safe}-{time.time_ns()}.log")
        read_fd, write_fd = os.pipe()
        pid = os.fork()
        if pid:
            os.close(write_fd)
            handle.close()  # Child retains the same locked open-file description.
            with os.fdopen(read_fd) as pipe:
                ready = pipe.read()
            os.waitpid(pid, os.WNOHANG)
            if not ready.startswith("pid "):
                print(f"error: waiter failed to start: {ready}; log {log}", file=sys.stderr)
                return 3
            print(f"pr-wait detached: {ready}, log {log}")
            return 0
        os.close(read_fd)
        ready_fd = write_fd
        os.setsid()
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        with open(os.devnull, "rb") as source, open(log, "ab", buffering=0) as output:
            os.dup2(source.fileno(), 0)
            os.dup2(output.fileno(), 1)
            os.dup2(output.fileno(), 2)
    env = dict(os.environ, PR_WAIT_LOCKED="1")
    if detached:
        env.update(AGENT_WAIT_KIND="pr-wait", AGENT_WAIT_TARGET=args.pr, AGENT_WAIT_LOG=log)
    child_args = args.args[1:] if args.args[:1] == ["--"] else args.args
    process = None
    pending_signal = None

    def forward(signum, _frame):
        nonlocal pending_signal
        if process is None:
            pending_signal = signum
        else:
            try:
                os.killpg(process.pid, signum)
            except ProcessLookupError:
                pass

    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(signum, forward)
    try:
        # A separate group lets a normal supervisor termination stop the whole
        # waiter. close_fds keeps the lock out of gh, notifications, and hooks.
        process = subprocess.Popen([args.script, *child_args], env=env,
                                   start_new_session=True, close_fds=True)
        record(process.pid)
        if pending_signal is not None:
            forward(pending_signal, None)
        if ready_fd is not None:
            os.write(ready_fd, f"pid {process.pid}".encode())
            os.close(ready_fd)
            ready_fd = None
        result = process.wait()
        return result if result >= 0 else 128 - result
    finally:
        if ready_fd is not None:
            os.close(ready_fd)
        handle.close()


if __name__ == "__main__":
    try:
        code = main()
    except (OSError, subprocess.SubprocessError) as error:
        print(f"error: lock launcher: {error}", file=sys.stderr)
        code = 3
    sys.exit(code)
