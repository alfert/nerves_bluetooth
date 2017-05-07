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

ERL_H = $(ERL_INTERFACE)/include
ERL_LIB = -L $(ERL_INTERFACE)/lib -lerl_interface -lei

HCI_DEFINES = -DCONFIG_CTRL_IFACE -DCONFIG_CTRL_IFACE_UNIX

# Linux: LDFLAGS += -lrt $(ERL_LIB)
LDFLAGS += $(ERL_LIB)
LDFLAGS += -lrt -pthread
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pthread -I $(ERL_H) 
CFLAGS += $(EXTRA_CFLAGS)
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
