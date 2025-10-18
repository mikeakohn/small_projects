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

unsigned char read_char_serial(int fd)
{
unsigned char ch;
int n;

  while(1)
  {
    n=read(fd,&ch,1);
    if (n==1)
    {
      return ch;
      break;
    }
  }

  return 0;
}

void send_char_serial(int fd, unsigned char ch)
{
char c;

  while (write(fd,&ch,1)!=1);

  c=read_char_serial(fd);
  //if (c!=ch) { printf("Error: no echo %c\n",c); }
  c=read_char_serial(fd);
  if (c!='!') { printf("Error: no '!' %c\n",c); }
}

int main(int argc, char *argv[])
{
int fd;
int ch;
time_t curr_time=time(NULL);
int count=0;

  fd=open_serial("/dev/ttyUSB0");

  while(1)
  {
    ch=getc(stdin);
    if (ch==EOF) break;

    send_char_serial(fd, ch);
    count++;

    if ((count%128)==0)
    {
       printf("%fk transferred (%d bytes per second)\n", ((float)count/1024), (int)(count/(time(NULL)-curr_time)));
    }
  }

  close_serial(fd);

  printf("Total bytes: %d\n", count);
  printf(" Total time: %d\n", (int)(time(NULL)-curr_time));
  printf("  Data Rate: %d bytes/second\n", (int)(count/(time(NULL)-curr_time)));

  return 0;
}

