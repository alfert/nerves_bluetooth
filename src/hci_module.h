#ifndef HCI_MODULE
#define HCI_MODULE

#define log(s) flog("%s\n", s)
// void flog(char *s);
void flog(const char *s, ...);

int foo(int x);

int bar(int y);


#endif
