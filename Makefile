MAKEFILE_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(realpath $(dir $(MAKEFILE_PATH)))

ZIG_OUT := $(MAKEFILE_DIR)/zig-out
LOG_DIR := $(ZIG_OUT)

quick: x quick-make-command

x:
	rg 'X\.' --glob '!*x_tutorial*' --stats

build:
	zig build

test:
	zig build test

install:
	zig build --prefix /usr/local -Doptimize=ReleaseFast install

# ====================================================================
# Development
# ====================================================================

run: debug-run log

# Runs kopiwm in debug mode, and logs the stderr to a log file.
debug-run: debug-install
	mkdir -p $(LOG_DIR)
	-XINITRC=./scripts/.xinitrc startx -- -keeptty \
		>$(LOG_DIR)/Xorg.0.log \
		2>$(LOG_DIR)/kopiwm.log

debug-install:
	zig build --prefix ~/.local install

log:
	nvim $(LOG_DIR)/kopiwm.log

# If ever, for whatever reason, X shows an error like "No screens
# found" or "Screens found but not usable", try this fix.
recovery:
	Xorg -configure
	dpkg --configure -a # might require root.
	# and then reboot (logging out is not enough for some reason).

quick-make-command: build
