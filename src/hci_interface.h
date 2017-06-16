#ifndef HCI_INTERFACE
#define HCI_INTERFACE

#include "global.h"

int read_cmd(byte *buf);
int write_cmd(byte *buf, int len);


#endif
