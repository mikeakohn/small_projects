#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "hexdump.h"

void hexdump(uint8_t *buffer, int length)
{
  char text[24];
  int ptr = 0;
  int n;

  printf(" -- hexdump %d --\n", length);

  for (n = 0; n < length; n++)
  {
    char ch = buffer[n] >= 32 && buffer[n] < 127 ? buffer[n] : '.';
    text[ptr++] = ch;

    printf(" %02x", buffer[n]);

    if ((n + 1) % 8 == 0)
    {
      text[ptr] = 0;
      printf(" %s\n", text);
      ptr = 0;
    }
  }

  int extra = 8 - (n % 8);

  if (extra != 0)
  {
    for (n = 0; n < extra * 3; n++) { printf(" "); }
    printf("%s\n", text);
  }

  printf("\n");
}

