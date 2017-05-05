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
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
// we do not include hci_lib.h, because the functions defined there are
// implemented in Elixir instead.

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


// TODO: Where does ATT_CID come from?
#define ATT_CID 4

/* =========================================*/

int _mode;
int _socket = -1;
int _devId;

/* =========================================*/


int hci_init() {
  _socket = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BTPROTO_HCI);
  return _socket != -1;
}

int hci_close() {
  close(_socket);
  _socket = -1;
  return 0;
}

 bool hci_is_dev_up() {
  struct hci_dev_info di;
  bool is_up = false;

  memset(&di, 0x00, sizeof(di));
  di.dev_id = _devId;

  if (ioctl(_socket, HCIGETDEVINFO, (void *)&di) > -1) {
    is_up = (di.flags & (1 << HCI_UP)) != 0;
  }

  return is_up;
}

int hci_dev_id_for(int* p_dev_id, bool is_up) {
  int dev_id = 0; // default

  if (p_dev_id == NULL) {
    struct hci_dev_list_req *dl;
    struct hci_dev_req *dr;

    dl = (struct hci_dev_list_req*)calloc(HCI_MAX_DEV * sizeof(*dr) + sizeof(*dl), 1);
    dr = dl->dev_req;

    dl->dev_num = HCI_MAX_DEV;

    if (ioctl(_socket, HCIGETDEVLIST, dl) > -1) {
      for (int i = 0; i < dl->dev_num; i++, dr++) {
        bool dev_up = dr->dev_opt & (1 << HCI_UP);
        bool match = is_up ? dev_up : !dev_up;

        if (match) {
          // choose the first device that is match
          // later on, it would be good to also HCIGETDEVINFO and check the HCI_RAW flag
          dev_id = dr->dev_id;
          break;
        }
      }
    }

    free(dl);
  } else {
    dev_id = *p_dev_id;
  }

  return dev_id;
}


/** Simple test functions */
int foo(int x) {
  return x+1;
}

int bar(int y) {
  return y*2;
}
