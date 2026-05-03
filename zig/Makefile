GDB_COMMAND_FILE := debug.gdb

current: xrun

xrun: install
	XINITRC=./xinitrc startx

run:
	# zig build run -- -v
	#=============================================================================
	zig build run

build:
	zig build

test:
	zig build test

gdb: build
	gdb --command=$(GDB_COMMAND_FILE) ./zig-out/bin/dwmz

install:
	zig build --prefix /home/khang/.local -Doptimize=ReleaseFast install

log:
	nvim ~/.local/share/xorg/Xorg.0.log
