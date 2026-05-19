#!/usr/bin/env python3
"""CLI tool สำหรับทดสอบ CMD / ENTRYPOINT / ENV / ARG"""
import os
import sys

VERSION = os.environ.get("APP_VERSION", "1.0")
BUILD_DATE = os.environ.get("BUILD_DATE", "unknown")


def cmd_hello(args):
    name = args[0] if args else "world"
    print(f"Hello, {name}!  (app v{VERSION})")


def cmd_env(args):
    print(f"APP_VERSION  = {VERSION}")
    print(f"BUILD_DATE   = {BUILD_DATE}")
    print(f"USER         = {os.environ.get('USER', '-')}")
    print(f"HOME         = {os.environ.get('HOME', '-')}")


def cmd_whoami(args):
    import pwd
    uid = os.getuid()
    try:
        name = pwd.getpwuid(uid).pw_name
    except KeyError:
        name = "(unknown)"
    print(f"uid={uid} ({name})")


COMMANDS = {"hello": cmd_hello, "env": cmd_env, "whoami": cmd_whoami}

if __name__ == "__main__":
    subcmd = sys.argv[1] if len(sys.argv) > 1 else "hello"
    rest = sys.argv[2:]
    fn = COMMANDS.get(subcmd)
    if fn is None:
        print(f"unknown command: {subcmd}  (choices: {', '.join(COMMANDS)})", file=sys.stderr)
        sys.exit(1)
    fn(rest)
