from os import path, walk

__cwd__ = path.dirname(__file__)
__root__ = path.dirname(__cwd__)

dwm_c = path.join(__root__, "dwm.c")
drw_h = path.join(__root__, "drw.h")


def get_declared_funcs(filepath: str, static_only=False) -> list[str]:
    with open(filepath, "r") as f:
        source = f.read()
    static_funcs = []
    for line in source.splitlines():
        if "(" in line and line.endswith(");"):
            if static_only and "static" not in line:
                continue
            line, _ = line.split("(", maxsplit=1)
            if " " not in line:
                continue
            fn = line.rsplit(" ", maxsplit=1)[1]
            fn = fn.removeprefix("*")
            if fn:
                static_funcs.append(fn)
    return static_funcs


c_funcs = get_declared_funcs(drw_h) + get_declared_funcs(dwm_c, static_only=True)

for root, subdirs, files in walk(__cwd__):
    if root.endswith(".zig-cache") or root.endswith("zig-out"):
        subdirs[:] = []
        continue
    files = map(lambda f: path.join(root, f), files)
    files = filter(lambda f: f.endswith(".zig"), files)
    for file in files:
        with open(file, "r") as f:
            text = f.read()
        lines = filter(lambda l: "[dwm]" in l, text.splitlines())
        lines = map(lambda l: l.split("[dwm]", maxsplit=1)[1], lines)
        lines = map(str.strip, lines)
        for line in lines:
            try:
                c_funcs.remove(line)
            except:
                pass

        # for line in text.splitlines():
        #     i = len(c_funcs) - 1;
        #     while i >= 0:

        # print(file)

print(c_funcs)
