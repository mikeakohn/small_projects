#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <linux/if.h>
#include <linux/if_tun.h>

#include "tun.h"

static int tun_alloc(char *dev, int flags)
{
  struct ifreq ifr;
  int fd, err;
  char *tundev = "/dev/net/tun";

  if( (fd = open(tundev, O_RDWR)) < 0 )
  {
    printf("This won't work.\n");
    return fd;
  }

  memset(&ifr, 0, sizeof(ifr));

  ifr.ifr_flags = flags;

  if (*dev)
  {
    strncpy(ifr.ifr_name, dev, IFNAMSIZ);
  }

  if ((err = ioctl(fd, TUNSETIFF, (void *) &ifr)) < 0)
  {
    printf("tun: Could not create device.\n");

    close(fd);
    return err;
  }

  strcpy(dev, ifr.ifr_name);

  return fd;
}

int tun_open()
{
  char tun_name[] = "laser0";
  //int fd = tun_alloc(tun_name, IFF_TUN);
  int fd = tun_alloc(tun_name, IFF_TUN | IFF_NO_PI);

  if (fd < 0)
  {
    printf("tun: Problem getting %s\n", tun_name);
    exit(1);
  }

  return fd;
}

void tun_close(int fd)
{
  close(fd);
}

int tun_send(int fd, const uint8_t *buffer, int length)
{
  int count = 0;
  int n;

  while (count < length)
  {
    n = write(fd, buffer + count, length - count);

    if (n <= 0)
    {
      printf("tun: Couldn't send all bytes n=%d (%d)\n", n, length - count);
      exit(1);
    }

    count += n;
  }

  return 0;
}

int tun_read(int fd, uint8_t *buffer, int length)
{
  int n = read(fd, buffer, length);

  if (n == -1)
  {
    perror("wtf\n");
    exit(0);
  }

  return n;
}

int tun_has_bytes(int fd)
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
    perror("tun select()");
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

