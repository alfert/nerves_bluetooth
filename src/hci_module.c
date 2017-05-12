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

#include "global.h"
#include "hci_module.h"

#ifdef DEBUG
void vflog(const char *fmt, va_list args)  {
  FILE *f = fopen("./hci_ex.log", "a+");
  vfprintf(f, fmt, args);
  if (fmt[strlen(fmt) - 1] != '\n') {
    fprintf(f, "\n");
  }
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
int hci_socket = -1;
int _dev_id;
uint8_t _address[6];
uint8_t _address_type;

/* =========================================*/


bool hci_init() {
  // SOCK__CLOEXEC enables event polling via epoll
  hci_socket = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BTPROTO_HCI);
  LOG("Raw socket is: %d", hci_socket);
  return (hci_socket != -1);
}

int hci_close() {
  close(hci_socket);
  hci_socket = -1;
  return 0;
}

bool hci_is_dev_up() {
  LOG("enter hci_is_dev_up");
  struct hci_dev_info di;
  bool is_up = false;

  memset(&di, 0x00, sizeof(di));
  di.dev_id = _dev_id;

  if (ioctl(hci_socket, HCIGETDEVINFO, (void *)&di) > -1) {
    is_up = (di.flags & (1 << HCI_UP)) != 0;
  } else {
    int error = errno;
    LOG("ioctl returned <= -1, errno is set to %d", error); 
  }

  return is_up;
}

int hci_dev_id_for(int* p_dev_id, bool is_up) {
  LOG("enter hci_dev_id_for is_up=%d", is_up);
  int dev_id = -1; // default would be 0, but makes no sense to detect a dev id with a different state

  if (p_dev_id == NULL) {
    struct hci_dev_list_req *dl;
    struct hci_dev_req *dr;

    dl = (struct hci_dev_list_req*)calloc(HCI_MAX_DEV * sizeof(*dr) + sizeof(*dl), 1);
    dr = dl->dev_req;

    dl->dev_num = HCI_MAX_DEV;

    if (ioctl(hci_socket, HCIGETDEVLIST, dl) > -1) {
      for (int i = 0; i < dl->dev_num; i++, dr++) {
        bool dev_up = dr->dev_opt & (1 << HCI_UP);
        // bool match = is_up ? dev_up : !dev_up;
        bool match = (is_up == dev_up);

        if (match) {
          // choose the first device that is match
          // later on, it would be good to also HCIGETDEVINFO and check the HCI_RAW flag
          dev_id = dr->dev_id;
          LOG("Found matching dev_id %d", dev_id);
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


int hci_bind_raw(int *dev_id) {
  struct sockaddr_hci a;
  struct hci_dev_info di;

  memset(&a, 0, sizeof(a));
  a.hci_family = AF_BLUETOOTH;
  a.hci_dev = hci_dev_id_for(dev_id, true);
  a.hci_channel = HCI_CHANNEL_RAW;

  _dev_id = a.hci_dev;
  _mode = HCI_CHANNEL_RAW;
  
  if (bind(hci_socket, (struct sockaddr *) &a, sizeof(a)) < 0) {
    int error = errno;
    LOG("Bind failed. Reason: %d (%s)", error, strerror(error));
    return -1;
  }

  // get the local address and address type
  memset(&di, 0x00, sizeof(di));
  di.dev_id = _dev_id;
  memset(_address, 0, sizeof(_address));
  _address_type = 0;

  if (ioctl(hci_socket, HCIGETDEVINFO, (void *)&di) > -1) {
    memcpy(_address, &di.bdaddr, sizeof(di.bdaddr));
    _address_type = di.type;

    if (_address_type == 3) {
      // 3 is a weird type, use 1 (public) instead
      _address_type = 1;
    }
  }

  return _dev_id;
}

/** Simple test function */
int hci_foo(int x) {
  return x+1;
}
