#!/usr/bin/env python3
"""Repack a .deb and rewrite the Architecture field in its control file.

Usage:
    python3 repack_deb_arch.py <in.deb> <out.deb> <architecture>

Theos generates the Architecture field itself (always iphoneos-arm64 even
for arm64e builds), so building per-arch debs requires rewriting it after
the fact. This script parses the ar archive, rewrites ./control inside
control.tar.*, and reassembles a valid .deb without touching data.tar.*.
"""

import io
import re
import sys
import tarfile


def read_ar(path):
    with open(path, "rb") as f:
        magic = f.read(8)
        if magic != b"!<arch>\n":
            raise ValueError("not an ar archive: %r" % magic)
        members = []
        while True:
            hdr = f.read(60)
            if not hdr:
                break
            if len(hdr) != 60:
                raise ValueError("truncated ar header")
            name = hdr[0:16].decode("ascii", "replace").strip()
            size = int(hdr[48:58].decode().strip() or "0")
            data = f.read(size)
            if len(data) != size:
                raise ValueError("truncated member %r" % name)
            if size % 2 == 1:
                f.read(1)
            members.append((name, data))
        return members


def write_ar(path, members):
    with open(path, "wb") as f:
        f.write(b"!<arch>\n")
        for name, data in members:
            nm = name.encode("ascii")
            if len(nm) > 16:
                raise ValueError("member name too long: %r" % name)
            nm = nm + b" " * (16 - len(nm))
            hdr = (
                nm
                + b"0" * 12  # mtime
                + b"0" * 6   # uid
                + b"0" * 6   # gid
                + b"0100644 "  # mode (8 bytes)
                + ("%d" % len(data)).encode().zfill(10)
                + b"`\n"
            )
            assert len(hdr) == 60, len(hdr)
            f.write(hdr)
            f.write(data)
            if len(data) % 2 == 1:
                f.write(b"\n")


def rewrite_control_tar(ctrl_data, arch):
    """Return a new control.tar.gz whose ./control has the new Architecture."""
    src = tarfile.open(fileobj=io.BytesIO(ctrl_data), mode="r:*")
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode="w:gz", format=tarfile.GNU_FORMAT) as dst:
        for m in src.getmembers():
            data = None
            if not m.isdir():
                data = src.extractfile(m).read()
            if m.name in ("control", "./control") and data is not None:
                text = data.decode("utf-8")
                new_text, n = re.subn(
                    r"(?m)^Architecture:.*$", "Architecture: " + arch, text
                )
                if n == 0:
                    new_text = text.rstrip("\n") + "\nArchitecture: " + arch + "\n"
                data = new_text.encode("utf-8")
            ti = tarfile.TarInfo(m.name)
            ti.mode = m.mode
            ti.uid = m.uid
            ti.gid = m.gid
            ti.mtime = m.mtime
            ti.type = m.type
            if m.issym() or m.islnk():
                ti.linkname = m.linkname
            if not m.isdir() and data is not None:
                ti.size = len(data)
            dst.addfile(ti, io.BytesIO(data) if data is not None else None)
    return out.getvalue()


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    src, dst, arch = sys.argv[1], sys.argv[2], sys.argv[3]

    members = read_ar(src)
    names = [n for n, _ in members]

    ctrl_idx = next(
        (i for i, n in enumerate(names) if n.startswith("control.tar")), None
    )
    data_idx = next((i for i, n in enumerate(names) if n.startswith("data.tar")), None)
    if ctrl_idx is None or data_idx is None:
        raise ValueError("missing control.tar/data.tar in %s" % src)

    ctrl_name, ctrl_data = members[ctrl_idx]
    new_ctrl = rewrite_control_tar(ctrl_data, arch)

    ordered = []
    for n, d in members:
        if n == "debian-binary":
            ordered.append((n, d))
    ordered.append((ctrl_name, new_ctrl))
    ordered.append((members[data_idx][0], members[data_idx][1]))
    # any other members (e.g. _gpgorigin) go last, untouched
    for n, d in members:
        if n != "debian-binary" and n != ctrl_name and n != members[data_idx][0]:
            ordered.append((n, d))

    write_ar(dst, ordered)
    print("wrote %s (Architecture: %s)" % (dst, arch))


if __name__ == "__main__":
    main()
