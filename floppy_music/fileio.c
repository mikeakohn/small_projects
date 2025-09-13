#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "midi.h"
#include "fileio.h"

int read_string_f(FILE *in, char *s, int n)
{
int t,ch;

  for(t=0; t<n; t++)
  {
    ch=getc(in);
    if (ch==EOF) return -1;

    s[t]=ch;
  }

  s[t]=0;
  return 0;
}

int read_string(struct _midi_track *track, char *s, int n)
{
int t;

  for(t=0; t<n; t++)
  {
    // ch=getc(in);
    // if (ch==EOF) return -1;
    s[t]=track->data[track->ptr++];
  }

  s[t]=0;
  return 0;
}

int print_string(struct _midi_track *track, int len)
{
int t;

  for(t=0; t<len; t++)
  {
    //ch=getc(in);
    //if (ch==EOF) return -1;
    printf("%c",track->data[track->ptr++]);
  }

  printf("\n");

  return 0;
}

int read_count(struct _midi_track *track, int n)
{
int t,s;

  t=0;

  for (s=0; s<n; s++)
  { t=(t<<8)+track->data[track->ptr++]; }
  // { t=(t<<8)+getc(in); }

  return t;
}

int read_var(struct _midi_track *track)
{
int t,ch;

  t=0;

  while(1)
  {
    // ch=getc(in);
    ch=track->data[track->ptr++];

    if (ch==EOF) return -1;

    t=(t<<7)+(ch&127);
    if ((ch&128)==0) break;
  }

  return t;
}

int parse_extras(struct _midi_track *track, int channel)
{
  if (channel==1)
  { track->ptr++; }
    else
  if (channel==2)
  { track->ptr++; track->ptr++; }
    else
  if (channel==3)
  { track->ptr++; }

  return 0;
}

int read_int(FILE *in)
{
int c;

  c=getc(in);
  c=(c<<8)|getc(in);
  c=(c<<8)|getc(in);
  c=(c<<8)|getc(in);

  return c;
}

int read_short(FILE *in)
{
int c;

  c=getc(in);
  c=(c<<8)|getc(in);

  return c;
}


