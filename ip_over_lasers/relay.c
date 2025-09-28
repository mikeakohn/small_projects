#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "hexdump.h"
#include "serialio.h"
#include "tun.h"

int main(int argc, char *argv[])
{
  int tun_fd;
  int serial_fd;
  uint8_t buffer[8192];
  uint8_t packet[8192];

  tun_fd = tun_open();
  serial_fd = serial_open("/dev/ttyUSB0");

  while (1)
  {
    if (tun_has_bytes(tun_fd) == 1)
    {
      int count = tun_read(tun_fd, buffer + 4, sizeof(buffer) - 4);

      printf("tun: length=%d\n", count);

      buffer[0] = 0xff;
      buffer[1] = 0xff;
      buffer[2] = count >> 8;
      buffer[3] = count & 0xff;

      hexdump(buffer, count + 4);

      serial_send(serial_fd, buffer, count + 4);
    }

    if (serial_has_bytes(serial_fd) == 1)
    {
      int ptr;
      int total_length;
      int packet_length;

      ptr = 0;
      total_length = 0;
      packet_length = 4;

      while (ptr < packet_length + 4)
      {
        int count = serial_read(serial_fd, packet + ptr, sizeof(packet) - ptr);

        printf("serial: count=%d  packet_length=%d total_length=%d ptr=%d\n",
          count,
          packet_length,
          total_length,
          ptr);

        ptr += count;

        if (ptr >= 4 && packet_length == 4)
        {
          if (packet[0] != 0xff && packet[1] != 0xff)
          {
            printf("Error: Packet missing sync marker 0xff 0xff\n");
            packet_length = 0;
            break;
          }

          packet_length = (packet[2] << 8) | packet[3];

          printf(" -- new packet_length=%d  ptr=%d\n",
             packet_length,
             ptr);
        }

        if (ptr >= 8 && total_length == 0)
        {
          total_length = (packet[6] << 8) | packet[7];

          printf(" -- new total_length=%d ptr=%d\n",
             total_length,
             ptr);
        }
      }

      hexdump(packet, ptr);

      if (packet_length == 0) { continue; }

      printf("serial: relay to tun packet_length=%d\n", ptr);

      tun_send(tun_fd, packet + 4, ptr - 4);
    }
  }

  tun_close(tun_fd);
  serial_close(serial_fd);

  return 0;
}

