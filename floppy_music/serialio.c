#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

#include "serialio.h"

// UGH!
struct termios oldtio;

int open_serial(char *device)
{
struct termios newtio;
int fd;

  fd=open(device,O_RDWR|O_NOCTTY|O_NONBLOCK);
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

void send_packet(int fd, unsigned char *packet)
{
int n;
char temp[20];

  printf("MIDI command: %02x %02x %02x\n",packet[0],packet[1],packet[2]);
  n=write(fd,packet,3);
  if (n!=3)
  {
    printf("Couldn't send all bytes n=%d\n",n);
    exit(1);
  }
  n=read(fd,temp,20);
}

void reset_midi(int fd)
{
/*
unsigned char packet[3];
int t;

  packet[0]=0xfe;            // request firmware version
  write(fd,packet,1);
  read_string_serial(fd);
  read_string_serial(fd);
  read_string_serial(fd);

  packet[0]=0xff;
  packet[2]=0x00;

  for (t=0; t<25; t++)
  {
    packet[1]=(unsigned char)t;
    send_packet(fd,packet);
  }
*/
}

void setup_midi(int fd)
{
// unsigned char packet[3];


}

void read_string_serial(int fd)
{
char buffer[1];
int n;

  while(1)
  {
    n=read(fd,buffer,1);
    printf("%c",buffer[0]);
    fflush(stdout);
    if (buffer[0]=='\n') break;
  }
}


