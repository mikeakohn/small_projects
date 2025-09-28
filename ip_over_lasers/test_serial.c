#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hexdump.h"
#include "serialio.h"

int main(int argc, char *argv[])
{
  int fd;
  uint8_t buffer[8192];

  fd = serial_open("/dev/ttyUSB0");

  while (1)
  {
    if (serial_has_bytes(fd) == 1)
    {
      int count = serial_read(fd, buffer, sizeof(buffer));

      hexdump(buffer, count);
    }
  }

  serial_close(fd);

  return 0;
}

