#ifndef HCI_INTERFACE
#define HCI_INTERFACE

int read_cmd(byte *buf);
int write_cmd(byte *buf, int len);


#endif
