#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <termios.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

#include "serialio.h"

// UGH!
struct termios oldtio;

int serial_open(char *device)
{
  struct termios newtio;
  int fd;

  //fd = open(device, O_RDWR|O_NOCTTY|O_NONBLOCK);
  fd = open(device, O_RDWR|O_NOCTTY);
  if (fd == -1)
  {
    printf("Couldn't open serial device.\n");
    exit(1);
  }

  tcgetattr(fd, &oldtio);

  memset(&newtio, 0, sizeof(struct termios));
  newtio.c_cflag = B2400|CS8|CLOCAL|CREAD;
  newtio.c_iflag = IGNPAR;
  newtio.c_oflag = 0;
  newtio.c_lflag = 0;
  newtio.c_cc[VTIME] = 0;
  newtio.c_cc[VMIN] = 1;

  tcflush(fd, TCIFLUSH);
  tcsetattr(fd, TCSANOW, &newtio);

  return fd;
}

void serial_close(int fd)
{
  tcsetattr(fd, TCSANOW, &oldtio);
  close(fd);
}

int serial_send(int fd, const uint8_t *buffer, int length)
{
  int count = 0;
  int n;

  while (count < length)
  {
    n = write(fd, buffer + count, length - count);

    if (n <= 0)
    {
      printf("serial: Couldn't send all bytes n=%d (%d)\n", n, length - count);
      exit(1);
    }

    count += n;
  }

  return 0;
}

int serial_read(int fd, uint8_t *buffer, int length)
{
  int n = read(fd, buffer, length);

  if (n == -1)
  {
    perror("wtf\n");
    exit(0);
  }

  return n;
}

int serial_has_bytes(int fd)
{
  fd_set read_fds;
  FD_ZERO(&read_fds);
  FD_SET(fd, &read_fds);

  struct timeval timeout;
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;

  int n = select(fd + 1, &read_fds, NULL, NULL, &timeout);

  if (n == -1)
  {
    perror("serial select()");
    return 0;
  }
    else
  if (n > 0 && FD_ISSET(fd, &read_fds))
  {
    return 1;
  }
    else
  {
    return 0;
  }
}

