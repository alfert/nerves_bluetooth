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
# ERL_HOME      path to Erlang installation
# ERL_H         path to Erlang C Header files
# ERL_LIB       path to Erlang C libs
ERL_HOME = /usr/local/lib/erlang
ERL_H = $(ERL_HOME)/lib/erl_interface-3.9.1/include
ERL_LIB = -L $(ERL_HOME)/lib/erl_interface-3.9.1/lib -lerl_interface -lei

HCI_DEFINES = -DCONFIG_CTRL_IFACE -DCONFIG_CTRL_IFACE_UNIX

# Linux: LDFLAGS += -lrt $(ERL_LIB)
LDFLAGS += $(ERL_LIB)
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -I $(ERL_H)
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

all: priv/hci_ex

%.o: %.c
	$(CC) -c $(HCI_DEFINES) $(CFLAGS) -o $@ $<

# priv/wpa_ex: src/wpa_ex.o src/wpa_ctrl/os_unix.o src/wpa_ctrl/wpa_ctrl.o
priv/hci_ex: src/hci_ex.o src/hci_module.o src/hci_interface.o
	@mkdir -p priv
	$(CC) $^ $(LDFLAGS) -o $@

clean:
	rm -f priv/hci_ex src/*.o
