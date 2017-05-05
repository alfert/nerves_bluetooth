#ifndef HCI_MODULE
#define HCI_MODULE

#ifdef DEBUG

#define LOG(fmt, ...) flog(fmt, __VA_ARGS__)

#else

#define LOG(fmt, ...)

#endif

/* Logging function, not part of the API */
void flog(const char *fmt, ...);

int foo(int x);

int bar(int y);


#endif
