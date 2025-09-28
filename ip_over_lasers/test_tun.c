#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "hexdump.h"
#include "tun.h"

int main(int argc, char *argv[])
{
  int fd;
  uint8_t buffer[8192];

  fd = tun_open();

  while (1)
  {
    if (tun_has_bytes(fd) == 1)
    {
      int count = tun_read(fd, buffer, sizeof(buffer));

      hexdump(buffer, count);
    }
  }

  tun_close(fd);

  return 0;
}

