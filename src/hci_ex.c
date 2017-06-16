/* HCI_EX port main program, based on ei.h for using erlang binary terms */

#include <erl_interface.h>
#include <ei.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/types.h>

#include "global.h"
#include "hci_interface.h"
#include "hci_module.h"

// Function names defined between Elixir and C
#define FOO "foo"
#define HCI_INIT "hci_init"
#define HCI_CLOSE "hci_close"
#define HCI_IS_DEV_UP "hci_is_dev_up"
#define HCI_DEV_ID_FOR "hci_dev_id_for"
#define HCI_BIND_RAW "hci_bind_raw"
#define HCI_SEND_COMMAND "hci_send_command"
#define HCI_SET_FILTER "hci_set_filter"

// Function Prototypes
int read_from_stdin();
void process_hci_data(char *buffer, int length);
void check_for_hci_socket_changes(int epollfd, int *old_hci_socket);
int process_stdin_event();
int process_socket_event();
void report_eterm_usage();

// Constants
#define MAX_EVENTS 64

int main() {
  LOG("\n>>>>>>>>>>>>>>>\n");
  // Initialize the Erl_Interface library
  erl_init(NULL, 0);
  LOG("Starting up the hci_ex");

  // last version of hci_socket to detect changes in the main loop.
  int old_hci_socket = -1;

  // Create EPOLLing socket
  int epollfd = epoll_create1(0);
  struct epoll_event event;
  struct epoll_event *events = calloc(MAX_EVENTS, sizeof(event));

  // Add stdin to epolling
  memset(&event, 0, sizeof(event));
  event.events = EPOLLIN|EPOLLPRI|EPOLLERR;
  event.data.fd = STDIN_FILENO;
  if (epoll_ctl(epollfd, EPOLL_CTL_ADD, STDIN_FILENO, &event) != 0) {
      LOG("epoll_ctl add stdin failed.");
      free(events);
      return 1;
  }

  bool finish = FALSE;

  while (!finish) {
    report_eterm_usage();
    check_for_hci_socket_changes(epollfd, &old_hci_socket);
    int number_of_events = epoll_wait(epollfd, events, MAX_EVENTS, -1);
    if (number_of_events < 0) {
      LOG("epoll_wait failed.");
      free(events);
      return 2;
    }
    if (number_of_events == 0) {
      continue;
    }
    LOG("Iterating over %d epoll events", number_of_events);
    for (int i = 0; i < number_of_events; i++) {
      LOG("Socket No %d is %d", i, events[i].data.fd);
      switch(events[i].data.fd) {
        case 0: 
          if (process_stdin_event() < 0)
            finish = TRUE;
          break;
        default:
          if (events[i].data.fd == hci_socket) {
            if (process_socket_event() < 0)
              finish = TRUE;
          }
          else {
            LOG("Bad fd: %d\n", events[i].data.fd);
            free(events);
            return 5;
          }
      }
    }
  }
  close(epollfd);
  free(events);
  LOG("Stopping hci_ex");
  return 0;
}

int process_stdin_event(void) {
  while(TRUE) {
    if (read_from_stdin() < 0) {
      if (errno != EAGAIN && errno != EWOULDBLOCK) {
        // no more data available on stdin: the file is closed
        // therefore, we exit here.
        return -1;
      } else {
        return 0;
      }
    }
    return 1;

  }
}

int process_socket_event(void) {
  // read from socket. 1kb should be enough
  LOG("Read event from hci_socket");
  int length = 0;
  char data[1024];
  while (TRUE) {
    length = read(hci_socket, data, sizeof(data));
    if (length < 0 ) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        // no more data available. finish the loop.
        return 1;
      }
    } else {
      process_hci_data(data, length);
      // We only use RAW HCI Sockets, therefore call this function.
      // kernelDisconnectWorkArounds(length, data);
      if (length < (int) sizeof(data))
        return 0;
    }
  }
}

int read_from_stdin() {
  ETERM *tuplep, *return_val_p;
  ETERM *fnp, *argp, *refp, *fun_tuple_p;
  // the array of ETERM pointer for the result
  ETERM *resultp[2];
  int res = 0;
  // the resulting pair as an ETERM
  ETERM *result_pair;

  byte* buf = calloc(sizeof(byte), 1024);

  int read_count = -1;

  /****
   * Condition must be different: If a failure exists, then
   * errno must be asked for EWOULDBLOCK and give up in this case.
   ****
   */

  // do not use a while loop, the looping occurs outside. 
  if ((read_count = read_cmd(buf)) > 0) {
    LOG("read command successful, read %d bytes\n", read_count);
    
    #ifdef DEBUG
    char hex[1 + read_count * 2]; 
    for(int i = 0; i < read_count; i++) {
      int v = (int) buf[i];
      sprintf(hex+2*i, "%.2x", v);
    }
    hex[read_count * 2 - 1] = 0;
    LOG("Input: %s", hex);
    #endif

    /***************************
    * Decode the protocol between Elixir and C:
    * {ref, {func_atom, [args]}}
    ****************************/
    tuplep = erl_decode(buf);
    LOG("tuplep created");
    refp = erl_element(1, tuplep);
    LOG("refp created");
    fun_tuple_p = erl_element(2, tuplep);
    LOG("fun_tuple_p created");
    fnp = erl_element(1, fun_tuple_p);
    LOG("fnp created");
    argp = erl_element(2, fun_tuple_p);
    LOG("argp created");

    LOG("Got a call to do: %s\n", ERL_ATOM_PTR(fnp));

    if (strncmp(ERL_ATOM_PTR(fnp), HCI_INIT, strlen(HCI_INIT)) == 0) {
      if (hci_init()) {
        return_val_p = erl_mk_atom("ok");
      } else {
        return_val_p = erl_mk_atom("error");
      }
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_BIND_RAW, strlen(HCI_BIND_RAW)) == 0) {
      LOG("found HCI_BIND_RAW for hci_socket %d", hci_socket);
      // the parameter is the first element in the list
      ETERM *param = ERL_CONS_HEAD(argp);
      int dev_id = ERL_INT_VALUE(param);

      res = hci_bind_raw(&dev_id);
      if (res > -1) {
        return_val_p = erl_mk_int(res);
        LOG("hci_socket is open with value %d", hci_socket);
      } else {
        return_val_p = erl_mk_atom("nil");
      }
      erl_free_term(param);
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_SEND_COMMAND, strlen(HCI_SEND_COMMAND)) == 0) {
      LOG("found HCI_SEND_COMMAND");
      // the parameter is the first element in the list
      ETERM *param = ERL_CONS_HEAD(argp);
      byte *cmd = ERL_BIN_PTR(param);
      int size = ERL_BIN_SIZE(param);

      res = hci_write(cmd, size);
      if (res == 0) {
        return_val_p = erl_mk_atom("ok");
      } else {
        return_val_p = erl_mk_atom(strerror(res));
      }
      erl_free_term(param);
    }
    else if (strncmp(ERL_ATOM_PTR(fnp), HCI_SET_FILTER, strlen(HCI_SET_FILTER)) == 0) {
      LOG("found HCI_SET_FILTER");
      // the parameter is the first element in the list
      ETERM *param = ERL_CONS_HEAD(argp);
      byte *data = ERL_BIN_PTR(param);
      int size = ERL_BIN_SIZE(param);

      res = hci_set_filter(data, size);
      if (res == 0) {
        return_val_p = erl_mk_atom("ok");
      } else {
        return_val_p = erl_mk_atom(strerror(res));
      }
      erl_free_term(param);
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
    free(buf);

    return read_count;
  }
  else {
    LOG("could only read %d bytes\n", read_count);
  }
  free(buf);
  return -1;  
}

void process_hci_data(char *buffer, int length) {
  ETERM *result_pair, *event_atom_p, *binary_p;
  // the array of ETERM pointer for the result
  ETERM *resultp[2];
  // IO buffer
  byte buf[2048];

  event_atom_p = erl_mk_atom("event");
  binary_p = erl_mk_binary(buffer, length);

  resultp[0] = event_atom_p;
  resultp[1] = binary_p;
  result_pair = erl_mk_tuple(resultp, 2);

  LOG("Encode event of %d bytes\n", length);
  erl_encode(result_pair, buf);
  LOG("Write event");
  write_cmd(buf, erl_term_len(result_pair));

  LOG("Free erlang term variables");
  erl_free_compound(result_pair);
  erl_free(event_atom_p);
  erl_free(binary_p);

}

// Check for changes of the hci_socket. It may go from non-available (-1) to
// to available (>= 0) and back again.
void check_for_hci_socket_changes(int epollfd, int *old_hci_socket) {
  // Add hci_socket for epolling
  struct epoll_event hci_event;
  memset(&hci_event, 0, sizeof(hci_event));
  // We use Edge triggered polling
  hci_event.events = EPOLLIN | EPOLLET;

  LOG("Checks sockets. hci_socket %d and old_hci_socket %d", hci_socket, *old_hci_socket);
  if (hci_socket != *old_hci_socket) {
    LOG("hci_socket change detected");
    if (hci_socket < 0) {
      hci_event.data.fd = *old_hci_socket;
      LOG("hci_socket is now %d, delete old hci_socket %d from epoll", hci_socket, *old_hci_socket);
      if (epoll_ctl(epollfd, EPOLL_CTL_DEL, *old_hci_socket, &hci_event) != 0) {
        LOG("epoll_ctl delete hci_socket %d failed", *old_hci_socket);
        exit(1);
      }
    } else {
      *old_hci_socket = hci_socket;
      hci_event.data.fd = hci_socket;
      LOG("hci_socket is new: %d - add to epoll set", hci_socket);
      if (epoll_ctl(epollfd, EPOLL_CTL_ADD, hci_socket, &hci_event) != 0) {
        LOG("epoll_ctl add hci_socket %d failed", *old_hci_socket);
        exit(1);
      }
    }
  }

}

void report_eterm_usage() {
  #ifdef DEBUG
  
  long unsigned allocated, freed;

  erl_eterm_statistics(&allocated,&freed);
  LOG("currently allocated blocks: %ld\n",allocated);
  LOG("length of freelist: %ld\n",freed);

  #endif
}