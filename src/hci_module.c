/**
 * This module contains the functions to access the HCI devices
 * on the Kernel level.
 *
 * The functions originate as a port of Bleno's and Noble's
 * node-bluetooth-hci-socket project, providing access from node.js
 * to Bluetooth via HCI sockets.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>


#include "hci_module.h"

#ifdef DEBUG
void vflog(const char *fmt, va_list args)  {
  FILE *f = fopen("./hci_ex.log", "a+");
  vfprintf(f, fmt, args);
  fclose(f);
}

void flog(const char *fmt, ...)  {
  va_list args;
  va_start(args, fmt);
  vflog(fmt, args);
  va_end(args);
}
#else

#endif

int foo(int x) {
  return x+1;
}

int bar(int y) {
  return y*2;
}
