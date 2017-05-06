#ifndef HCI_INTERFACE
#define HCI_INTERFACE

typedef unsigned char byte;


int read_cmd(byte *buf);
int write_cmd(byte *buf, int len);


#endif
