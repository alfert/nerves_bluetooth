/**
 * Function for reading and writing data from stdin and stdout
 * to communicate with the Erlang VM.
 *
 * The functions are taken from the Erlang Interoperability Tutorial Guide.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "hci_interface.h"
#include "hci_module.h"

int read_exact(byte *buf, const int len) {
  int i, got=0;

  do {
    if ((i = read(0, buf+got, len-got)) <= 0)
      return(i);
    got += i;
  } while (got<len);

  return(len);
}

int read_cmd(byte *buf) {
  int len;

  int read_count = -1;
  // read 2 bytes for package length
  if ((read_count = read_exact(buf, 2)) != 2) {
    log("did not get 2 bytes from the buffer");
    return(-1);
  }
  len = (buf[0] << 8) | buf[1];
  flog("Length: %d\n", len);
  // read exactly that many bytes as the packet size is.
  return read_exact(buf, len);
}


int write_exact(byte *buf, int len) {
  int i, wrote = 0;

  do {
    if ((i = write(1, buf+wrote, len-wrote)) <= 0)
      return (i);
    wrote += i;
  } while (wrote<len);

  return (len);
}

int write_cmd(byte *buf, int len) {
  byte li;

  li = (len >> 8) & 0xff;
  write_exact(&li, 1);

  li = len & 0xff;
  write_exact(&li, 1);

  return write_exact(buf, len);
}
