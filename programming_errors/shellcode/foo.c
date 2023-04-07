#include <string.h>
#include <stdlib.h>

void foobar() {
  volatile register int a;
  a *= 260;
}

int main() {
  foobar();
  return 0;
}
