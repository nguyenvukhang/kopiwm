from os import path, walk
import re

__cwd__ = path.dirname(__file__)
__root__ = path.dirname(__cwd__)

BLACKLIST = (".zig-cache", "zig-out", ".git")
ALLOW_FOR_NOW = (
    "AnyButton",
    "AnyKey",
    "AnyModifier",
    "BadWindow",
    "ButtonPress",
    "ButtonRelease",
    "CWBackPixmap",
    "CWBorderWidth",
    "CWCursor",
    "CWEventMask",
    "CWHeight",
    "CWOverrideRedirect",
    "CWSibling",
    "CWStackMode",
    "CWWidth",
    "CWX",
    "CWY",
)


uniques = set()

for root, subdirs, files in walk(__root__):
    if any(map(root.endswith, BLACKLIST)):
        subdirs[:] = []
        continue
    files = [path.join(root, fp) for fp in files if "tutorial" not in fp]
    for file in files:
        with open(file, "r") as f:
            text = f.read()

        for x in re.findall("X\\.[A-Za-z0-9_]+", text):
            x = str(x).removeprefix("X.")
            if x == "h":
                continue
            uniques.add(x)

uniques = sorted(x for x in uniques if x not in ALLOW_FOR_NOW)

print("[\x1b[37m" + ", ".join(uniques) + "\x1b[m]")
print(f"({len(uniques)} unique items to go)")
