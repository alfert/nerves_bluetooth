# Variables to override
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# LDFLAGS	linker flags for linking all binaries
# MIX		path to mix
# SUDO_ASKPASS  path to ssh-askpass when modifying ownership of net_basic
# SUDO          path to SUDO. If you don't want the privileged parts to run, set to "true"
#
# ERL_INTERFACE  path to Erlang Interface application directory inside OTP_ROOT
# ERL_H         path to Erlang C Header files
# ERL_LIB       path to Erlang C libs

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning Elixir Bluetooth currently only works on Linux, but crosscompilion)
        $(warning is supported by defining $$CROSSCOMPILE, $$ERL_EI_INCLUDE_DIR,)
        $(warning and $$ERL_EI_LIBDIR. See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping C compilation unless targets explicitly passed to make.)
DEFAULT_TARGETS = priv
    endif
		ifeq ($(TRAVIS),true)
DEFAULT_TARGETS = priv
		endif
endif
DEFAULT_TARGETS ?= priv priv/hci_ex

# Look for the EI library and header files
# For crosscompiled builds, ERL_EI_INCLUDE_DIR and ERL_EI_LIBDIR must be
# passed into the Makefile and this is what Nerves does.
ifeq ($(ERL_EI_INCLUDE_DIR),)
ERL_ROOT_DIR = $(shell erl -eval "io:format(\"~s~n\", [code:root_dir()])" -s init stop -noshell)
ifeq ($(ERL_ROOT_DIR),)
   $(error Could not find the Erlang installation. Check to see that 'erl' is in your PATH)
endif
ERL_EI_INCLUDE_DIR = "$(ERL_ROOT_DIR)/usr/include"
ERL_EI_LIBDIR = "$(ERL_ROOT_DIR)/usr/lib"
endif

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lerl_interface -lei

# ERL_H = $(ERL_INTERFACE)/include
# ERL_LIB = -L $(ERL_INTERFACE)/lib -lerl_interface -lei

HCI_DEFINES = -DCONFIG_CTRL_IFACE -DCONFIG_CTRL_IFACE_UNIX

# Linux: LDFLAGS += -lrt $(ERL_LIB)
LDFLAGS += $(ERL_LDFLAGS)
LDFLAGS += -lrt -pthread -g
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pthread -std=c99
CFLAGS += $(EXTRA_CFLAGS) $(ERL_CFLAGS) -g
# CLFAGS += $(ERL_CFLAGS)
CC ?= $(CROSSCOMPILE)gcc

# If not cross-compiling, then run sudo by default
ifeq ($(origin CROSSCOMPILE), undefined)
SUDO_ASKPASS ?= /usr/bin/ssh-askpass
SUDO ?= sudo
else
# If cross-compiling, then permissions need to be set some build system-dependent way
SUDO ?= true
endif

.PHONY: all clean

all: $(DEFAULT_TARGETS)

%.o: %.c
	env | sort
	$(CC) -c $(HCI_DEFINES) $(CFLAGS) -o $@ $<

priv:
	@mkdir -p priv

# priv/wpa_ex: src/wpa_ex.o src/wpa_ctrl/os_unix.o src/wpa_ctrl/wpa_ctrl.o
priv/hci_ex: src/hci_ex.o src/hci_module.o src/hci_interface.o
	$(CC) $^ $(LDFLAGS) -o $@

clean:
	rm -f priv/hci_ex src/*.o
