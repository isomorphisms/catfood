"""Read-only host evidence. No mailbox content read or mutation."""
import argparse
import os
from pathlib import Path
import pwd
import shutil
import stat
import sys


def probe(source, destination, require_netbsd=False, output=print):
    if sys.version_info < (3, 9):
        raise RuntimeError("Python 3.9 or newer required")
    system = os.uname()
    if require_netbsd and system.sysname != "NetBSD":
        raise RuntimeError("SDF qualification requires an observed NetBSD host")
    output("system\t" + "\t".join(system))
    output("python\t" + sys.version.replace("\n", " "))
    output("account\t" + pwd.getpwuid(os.getuid()).pw_name)
    output("uid\t" + str(os.getuid()))
    output("groups\t" + ",".join(map(str, os.getgroups())))
    source, destination = Path(source), Path(destination)
    if not source.is_absolute() or not destination.is_absolute():
        raise RuntimeError("absolute paths required; expand the account home explicitly")
    for role, path in (("source", source), ("source-directory", source.parent),
                       ("archive", destination), ("archive-directory", destination.parent)):
        output(role + "\t" + str(path))
        try:
            item = os.lstat(path)
            output(role + "-metadata\t" + "\t".join(map(str, (item.st_dev, item.st_ino,
                   item.st_uid, item.st_gid, stat.S_IMODE(item.st_mode), item.st_size))))
            output(role + "-access\tread=" + str(os.access(path, os.R_OK)) + "\twrite=" + str(os.access(path, os.W_OK)))
        except FileNotFoundError:
            output(role + "-metadata\tMISSING")
    for path in (source.parent, destination.parent):
        try:
            output("free-space\t" + str(path) + "\t" + str(shutil.disk_usage(path).free))
        except OSError as error:
            output("free-space\t" + str(path) + "\tUNAVAILABLE " + str(error))
    for tool in ("lockf", "flock", "mail.local", "dotlock", "postconf"):
        output("utility\t" + tool + "\t" + (shutil.which(tool) or "MISSING"))
    output("delivery-lock\tUNKNOWN")
    output("mailbox-mutation\tnone")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--require-netbsd", action="store_true")
    arguments = parser.parse_args()
    try:
        probe(arguments.source, arguments.destination, arguments.require_netbsd)
    except (OSError, RuntimeError) as error:
        print("REFUSED: " + str(error), file=sys.stderr)
        sys.exit(1)
