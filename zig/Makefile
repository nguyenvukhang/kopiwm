GDB_COMMAND_FILE := debug.gdb

current: run

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
