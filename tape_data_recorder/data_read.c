#include <stdio.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>

// UGH!
struct termios oldtio;

int open_serial(char *device)
{
struct termios newtio;
int fd;

  fd=open(device,O_RDWR|O_NOCTTY);
  if (fd==-1)
  {
    printf("Couldn't open serial device.\n");
    exit(1);
  }

  tcgetattr(fd,&oldtio);

  memset(&newtio,0,sizeof(struct termios));
  newtio.c_cflag=B9600|CS8|CLOCAL|CREAD;
  newtio.c_iflag=IGNPAR;
  newtio.c_oflag=0;
  newtio.c_lflag=0;
  newtio.c_cc[VTIME]=0;
  newtio.c_cc[VMIN]=1;

  tcflush(fd, TCIFLUSH);
  tcsetattr(fd,TCSANOW,&newtio);

  return fd;
}

void close_serial(int fd)
{
  tcsetattr(fd,TCSANOW,&oldtio);
  close(fd);
}

int read_char_serial(int fd)
{
static int count=0;
fd_set readset;
struct timeval tv;
unsigned char ch;
int n;

  while(1)
  {
    FD_ZERO(&readset);
    FD_SET(fd,&readset);
    tv.tv_sec=2;
    tv.tv_usec=0;
    n=select(fd+1,&readset,NULL,NULL,&tv);

    if (n<1)
    {
      if (count==0) continue;
      return -1;
    }

    n=read(fd,&ch,1);
    if (n==1)
    {
      count++;
      return ch;
      break;
    }
  }

  return -1;
}

int main(int argc, char *argv[])
{
int fd;
int ch;

  fd=open_serial("/dev/ttyUSB0");

  while(1)
  {
    ch=read_char_serial(fd);
    if (ch<0) break;
    printf("%c",(unsigned char)ch);
    fflush(stdout);
  }

  close_serial(fd);

  return 0;
}


