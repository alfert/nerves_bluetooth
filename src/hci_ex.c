/* HCI_EX port main program, based on ei.h for using erlang binary terms */

#include "erl_interface.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "hci_module.h"
#include "hci_interface.h"


int main() {
  ETERM *tuplep, *intp;
  ETERM *fnp, *argp, *refp;
  // the array of ETERM pointer for the result
  ETERM *resultp[2];
  int res;
  // the resulting pair as an ETERM
  ETERM *result_pair;

  byte buf[100];
  // long allocated, freed;

  LOG("\n>>>>>>>>>>>>>>>\n");
  // Initialize the Erl_Interface library
  erl_init(NULL, 0);

  LOG("Starting up the hci_ex");

  int read_count = -1;
  while ((read_count = read_cmd(buf)) > 0) {
    LOG("read command successful, read %d bytes\n", read_count);
    /***************************
    * Decode the protocol between Elixir and C
    ****************************/
    tuplep = erl_decode(buf);
    fnp = erl_element(1, tuplep);
    refp = erl_element(2, tuplep);
    argp = erl_element(3, tuplep);
    int i = ERL_INT_VALUE(argp);

    LOG("Got a call to do with param: %d\n", i);

    if (strncmp(ERL_ATOM_PTR(fnp), "foo", 3) == 0) {
      res = foo(i);
    } else if (strncmp(ERL_ATOM_PTR(fnp), "bar", 3) == 0) {
      res = bar(i);
    }
    LOG("Assemble result");
    intp = erl_mk_int(res);

    // construct the resulting pair of reference and value
    resultp[0] = refp;
    resultp[1] = intp;
    result_pair = erl_mk_tuple(resultp, 2);

    LOG("Encode result of %d\n", res);
    erl_encode(result_pair, buf);
    LOG("Write result");
    write_cmd(buf, erl_term_len(result_pair));

    LOG("Free erlang term variables");
    erl_free_compound(tuplep);
    erl_free_term(fnp);
    erl_free_term(argp);
    erl_free_term(intp);
    erl_free_compound(result_pair);
    erl_free_term(refp);
  }
  LOG("could only read %d bytes\n", read_count);
  LOG("Stopping hci_ex");
}
