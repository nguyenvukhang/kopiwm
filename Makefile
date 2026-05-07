GDB_COMMAND_FILE := debug.gdb

current: build

check:
	python3 migrate.py

build:
	zig build

run: install
	-XINITRC=./xinitrc startx -- -keeptty >/home/khang/.local/share/xorg/Xorg.0.log 2>/home/khang/.local/share/xorg/dwm.log
	nvim ~/.local/share/xorg/dwm.log

test:
	zig build test

gdb: build
	gdb --command=$(GDB_COMMAND_FILE) ./zig-out/bin/dwmz

install:
	# zig build --prefix /home/khang/.local -Doptimize=ReleaseFast install
	zig build --prefix /home/khang/.local install

log:
	# nvim ~/.local/share/xorg/Xorg.0.log
	nvim ~/.local/share/xorg/dwm.log

recovery:
	Xorg -configure
	dpkg --configure -a
	# and then reboot (logging out is not enough for some reason)
