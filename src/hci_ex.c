/* HCI_EX port main program, based on ei.h for using erlang binary terms */

#include <erl_interface.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/types.h>

#include "global.h"
#include "hci_module.h"
#include "hci_interface.h"

// Function names defined between Elixir and C
#define FOO "foo"
#define HCI_INIT "hci_init"
#define HCI_CLOSE "hci_close"
#define HCI_IS_DEV_UP "hci_is_dev_up"
#define HCI_DEV_ID_FOR "hci_dev_id_for"

void read_from_stdin();

int main() {
  LOG("\n>>>>>>>>>>>>>>>\n");
  // Initialize the Erl_Interface library
  erl_init(NULL, 0);
  LOG("Starting up the hci_ex");

  // Create EPOLLing socket
  int epollfd = epoll_create1(0);
  struct epoll_event event;

  // Add stdin to epolling
  event.events = EPOLLIN|EPOLLPRI|EPOLLERR;
  event.data.fd = STDIN_FILENO;
  if (epoll_ctl(epollfd, EPOLL_CTL_ADD, STDIN_FILENO, &event) != 0) {
      LOG("epoll_ctl add stdin failed.");
      return 1;
  }

  for (;;) {
     int number_of_events = epoll_wait(epollfd, &event, 1, -1);
     if (number_of_events < 0) {
        LOG("epoll_wait failed.");
        return 2;
     }
     if (number_of_events == 0) {
         continue;
     }

     if (event.data.fd == STDIN_FILENO) {
         // read input line
         read_from_stdin();
         if (errno != EAGAIN) {
           // no more data available on stdin: the file is closed
           // therefore, we exit here.
           break;
         }
      } 
      /* else if (event.data.fd == sockfd) {
         // accept client
         struct sockaddr_in client_addr;
         socklen_t addrlen = sizeof (client_addr);
         int clientfd = accept(sockfd, (struct sockaddr*) &client_addr, &addrlen);
         if (clientfd == -1) {
             LOG("could not accept");
             return 4;
         }
         send(clientfd, "Bye", 3, 0);
         close(clientfd);
     } */
     else {
         // cannot happen™
         LOG("Bad fd: %d\n", event.data.fd);
         return 5;
     }
  }

  close(epollfd);
  
  LOG("Stopping hci_ex");
}

void read_from_stdin() {
  ETERM *tuplep, *return_val_p;
  ETERM *fnp, *argp, *refp, *fun_tuple_p;
  // the array of ETERM pointer for the result
  ETERM *resultp[2];
  int res = 0;
  // the resulting pair as an ETERM
  ETERM *result_pair;

  byte buf[100];
  // long allocated, freed;

  int read_count = -1;

  /****
   * Condition must be different: If a failure exists, then 
   * errno must be asked for EWOULDBLOCK and give up in this case.
   ****
   */

  while ((read_count = read_cmd(buf)) > 0) {
    LOG("read command successful, read %d bytes\n", read_count);
    /***************************
    * Decode the protocol between Elixir and C:
    * {ref, {func_atom, [args]}}
    ****************************/
    tuplep = erl_decode(buf);
    refp = erl_element(1, tuplep);
    fun_tuple_p = erl_element(2, tuplep);
    fnp = erl_element(1, fun_tuple_p);
    argp = erl_element(2, fun_tuple_p);

    LOG("Got a call to do: %s\n", ERL_ATOM_PTR(fnp));

    /* =======================================
     * TODO: Add the next two functions, beware 
     * several parameters and types! 
     * =======================================
     */

    if (strncmp(ERL_ATOM_PTR(fnp), HCI_INIT, strlen(HCI_INIT)) == 0) {
      if (hci_init()) {
        return_val_p = erl_mk_atom("ok");
      } else {
        return_val_p = erl_mk_atom("error");
      }
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_DEV_ID_FOR, strlen(HCI_DEV_ID_FOR)) == 0) {
      // int device_id = -1; // currently no used.
      bool is_up = false;
      LOG("found HCI_DEV_ID_FOR");
      // the parameter is the first element in the list
      ETERM *param = ERL_CONS_HEAD(argp);
      if (strncmp(ERL_ATOM_PTR(param), "true", 4) == 0) {
        is_up = true;
        LOG("enter hci_dev_id_for(true)");
      } else {
        LOG("enter hci_dev_id_for(false)");
      }
      // first parameter == NULL means that hci_dev_up searches for first 
      // device with state of `is_up`
      res = hci_dev_id_for(NULL, is_up);
      if (res > -1) {
        return_val_p = erl_mk_int(res);
      } else {
        return_val_p = erl_mk_atom("nil");
      }
      erl_free_term(param);
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_IS_DEV_UP, strlen(HCI_IS_DEV_UP)) == 0) {
      if (hci_is_dev_up()) {
        return_val_p = erl_mk_atom("true");
      } else {
        return_val_p = erl_mk_atom("false");
      }
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_CLOSE, strlen(HCI_CLOSE)) == 0) {
      res = hci_close();
      return_val_p = erl_mk_int(res);

    }
    else if (strncmp(ERL_ATOM_PTR(fnp), FOO, strlen(FOO)) == 0) {
      // the parameter is the first element in the list
      ETERM *param = ERL_CONS_HEAD(argp);
      int i = ERL_INT_VALUE(param);
      res = hci_foo(i);
      return_val_p = erl_mk_int(res);
      erl_free_term(param);
    } else return_val_p = NULL;
    LOG("Assemble result");
    
    // construct the resulting pair of reference and value
    resultp[0] = refp;
    resultp[1] = return_val_p;
    result_pair = erl_mk_tuple(resultp, 2);

    LOG("Encode result of %d\n", res);
    erl_encode(result_pair, buf);
    LOG("Write result");
    write_cmd(buf, erl_term_len(result_pair));

    LOG("Free erlang term variables");
    erl_free_compound(tuplep);
    erl_free_term(fnp);
    erl_free_term(argp);
    erl_free_term(return_val_p);
    erl_free_compound(result_pair);
    erl_free_term(refp);
  }
   LOG("could only read %d bytes\n", read_count);
 
}