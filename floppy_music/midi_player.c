#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

#include "midi.h"
#include "fileio.h"
#include "serialio.h"

#define getb(a) a->ptr<a->len ? a->data[a->ptr++] : 0;
#define getba(a) a.ptr<a.len ? a.data[a.ptr++] : 0;
// #define POKE(a,b) packet[1]=a&0x1f; packet[2]=b; send_packet(meta_events->fd,packet);

int MThd_parse(FILE *in, struct _header_chunk *header_chunk, int n)
{
  header_chunk->header_length=n;
  header_chunk->format=read_short(in);
  header_chunk->tracks=read_short(in);
  header_chunk->division=read_short(in);

  return 0;
}

int parse_meta_event(struct _midi_track *track, struct _meta_events *meta_events, struct _header_chunk *header_chunk)
{
int ch,v_length,t;

  ch=getb(track);
  v_length=read_var(track);

#ifdef DEBUG
  printf("v_length=%d\n",v_length);
#endif

  if (ch==0x00)
  { 
    printf("Sequence Number: "); 
    t=read_count(track,v_length);
    meta_events->sequence_number=t;
    printf("%d\n",t);
    return 0;
  }
    else
  if (ch==0x01)
  { 
    printf("Text Event: "); 
    print_string(track,v_length);
    return 0;
  }
    else
  if (ch==0x02)
  { 
    printf("Copyright Notice: "); 
    print_string(track,v_length);
    return 0;
  }
    else
  if (ch==0x03)
  { 
    printf("Track Name: "); 
    print_string(track,v_length);
    return 0;
  }
    else
  if (ch==0x04)
  { 
    printf("Instrument Name: "); 
    print_string(track, v_length);
    return 0;
  }
    else
  if (ch==0x05)
  { 
    printf("Lyric Text: "); 
    print_string(track,v_length);
    return 0;
  }
    else
  if (ch==0x06)
  { 
    printf("Marker Text: "); 
    print_string(track,v_length);
    return 0;
  }
    else
  if (ch==0x07)
  {
    printf("Cue Point: ");
  }
    else
  if (ch==0x20)
  {
    printf("MIDI Channel Prefix: ");
  }
    else
  if (ch==0x2f)
  { 
    printf("End Of Track\n"); 
    return -1;
  }
    else
  if (ch==0x51)
  { 
    t=read_count(track,v_length);
    meta_events->tempo=t;
    meta_events->division_usecs=meta_events->tempo/header_chunk->division;
    printf("Tempo Setting: %d\n",t); 
    return 0;
  }
    else
  if (ch==0x54)
  { 
    printf("SMPTE Offset: ");
    read_string(track,meta_events->smpte_offset,5);
    for (t=0; t<5; t++)
    {
      printf("%d ",meta_events->smpte_offset[t]);
    }

    printf("\n");

    return 0;
  }
    else
  if (ch==0x58)
  {
    printf("Time Signature: ");
    read_string(track,meta_events->time_signature,4);
    for (t=0; t<4; t++)
    {
      printf("%d ",meta_events->time_signature[t]);
    }

    printf("\n");
    return 0;
  }
    else
  if (ch==0x59)
  {
    printf("Key Signature: ");
    read_string(track,meta_events->key_signature,2);
    for (t=0; t<2; t++)
    {
      printf("%d ",meta_events->key_signature[t]);
    }
    printf("\n");
    return 0;
  }
    else
  if (ch==0x7F)
  {
    printf("Sequencer Specific Event: ");
  }
    else
  {
    printf("\nUnknown Event: ");
  }

  for (t=0; t<v_length; t++)
  {
    ch=getb(track);
    printf("%02x ",ch);
  }

  printf("\n");

  return 0;
}

int midi_command(struct _midi_track *track, int n, struct _meta_events *meta_events, int v_time, struct _header_chunk *header_chunk, int track_num)
{
unsigned char packet[3]={ 0xff, 0x00, 0x00 };
int command,channel;
int ch,tone;

  if (n<0x80)
  {
    track->ptr--;
    n=track->running_status;
  }

  command=n&0xf0;
  channel=n&0x0f;

  /* if (command==0x90 && v_time==0) command=0x80; */

  if (command==0x80)
  {
    /* Sound Off */
    tone=getb(track);
    ch=getb(track);

    if (v_time!=0)
    {
#ifdef DEBUG
printf("Sound Off [ %02x %d %d ] track %d\n",n,v_time,tone,track_num);
#endif
    }

    if (channel==0)
    {
      packet[0]=0x80;
      packet[1]=0x00;
      packet[2]=0x00;
      send_packet(meta_events->fd,packet);
    }
      else
    if (channel==1)
    {
      packet[0]=0x81;
      packet[1]=0x00;
      packet[2]=0x00;
      send_packet(meta_events->fd,packet);
    }
      else
    if (channel==2)
    {
      packet[0]=0x82;
      packet[1]=0x00;
      packet[2]=0x00;
      send_packet(meta_events->fd,packet);
    }
  }
    else
  if (command==0x90)
  {
    /* Sound On */
    tone=getb(track);
    ch=getb(track);

    if (v_time!=0)
    {
#ifdef DEBUG
printf("Sound On [ %02x %d %d ] track %d\n",n,v_time,tone,track_num);
#endif
    }

    // I don't think this is needed here
    // if (tone>96) channel=100;

    if (channel==0)
    {
      // POKE(54272,sid_freqs[tone]&255)
      // POKE(54273,sid_freqs[tone]>>8)
      // POKE(54276,17)
      tone-=12;
      packet[0]=0x90;
      packet[1]=tone;
      packet[2]=127;
      if (tone<70) send_packet(meta_events->fd,packet);
    }
      else
    if (channel==1)
    {
/*
      packet[0]=0x91;
      packet[1]=tone;
      packet[2]=127;
      send_packet(meta_events->fd,packet);
*/
    }
      else
    if (channel==2)
    {
/*
      packet[0]=0x92;
      packet[1]=tone;
      packet[2]=127;
      send_packet(meta_events->fd,packet);
*/
    }
  }
    else
  if (command==0xa0)
  {
    printf("Aftertouch\n");
    ch=getb(track);
    ch=getb(track);
  }
    else
  if (command==0xb0)
  {
    printf("Controller\n");
    ch=getb(track);
    ch=getb(track);
  }
    else
  if (command==0xc0)
  {
    printf("Program Change\n");
    ch=getb(track);
  }
    else
  if (command==0xd0)
  {
    printf("Channel Pressure\n");
    ch=getb(track);
  }
    else
  if (command==0xe0)
  {
    printf("Pitch Wheel\n");
    ch=getb(track);
    ch=getb(track);
  }
    else
  if (command==0xf0)
  {
    parse_extras(track,channel);
  }
    else
  {
    printf("Unknown MIDI code.  Please email Michael Kohn (mike@mikekohn.net)\n");
    printf("Code: %02x\n",n);
  }

  track->running_status=n;

  return 0;
}

int MTrk_parse(struct _midi_track *tracks, struct _header_chunk *header_chunk, struct _meta_events *meta_events, int num_tracks)
{
struct timeval tv,tvd;
//useconds_t diff;
int ch;
int v_time=0;
int division=0;
int channels_playing=3;
int c,t;

  gettimeofday(&tvd,NULL);

  while(channels_playing>0)
  {
    channels_playing=0;

    for (t=0; t<num_tracks; t++)
    {
      /* Check EOF */
      if (tracks[t].ptr>=tracks[t].len) continue;

      channels_playing++;

      while(tracks[t].division<=division)
      {
        if (tracks[t].state==0)
        {
          v_time=read_var(&tracks[t]);
          tracks[t].division+=v_time;
          tracks[t].state=1;
        }

        if (tracks[t].division>division) continue;

        ch=getba(tracks[t]);
        tracks[t].state=0;

        printf("MTrk_parse read in: v_time=%d %02x track=%d\n",v_time,ch,t);

        if (ch==0xff)
        {
          if (parse_meta_event(&tracks[t],meta_events,header_chunk)==-1) break;
        }
          else
        if (ch==0xf0 || ch==0xf7)
        {
          printf("System Exclusive 0x%x v_time=%d\n",ch,v_time);

          for (c=0; c<v_time; c++)
          {
            ch=getba(tracks[t]);
            printf("%c(0x%x)",ch,ch);
            if (ch==0xf7) break;
          }
        }
          else
        {
          midi_command(&tracks[t],ch,meta_events,v_time,header_chunk,t);
        }
      }
    }

    gettimeofday(&tv,NULL);
    tv.tv_sec-=tvd.tv_sec;
    if (tv.tv_sec>0) tv.tv_usec+=1000000;
    tv.tv_usec-=tvd.tv_usec;
    usleep(meta_events->division_usecs-tv.tv_usec);
    gettimeofday(&tvd,NULL);
    division++;
  }

  return 0;
}

int main(int argc, char *argv[])
{
FILE *in;
unsigned char packet[3]={ 0xff, 0x00, 0x00 };
struct _header_chunk header_chunk;
struct _meta_events meta_events;
int track_num;
char header[5];
struct _midi_track tracks[4];
int t;

  if (argc!=2)
  {
    printf("%s - Copyright 2008-2009 by Michael Kohn\n",argv[0]);
    printf("http://www.mikekohn.net/\n");
    printf("mike@mikekohn.net\n");
    printf("\nUsage: %s <infile.mid>\n\n",argv[0]);
    exit(0);
  }

  in=fopen(argv[1],"rb");
  if (in==0)
  {
    printf("Could not open file %s.\n",argv[1]);
    exit(0);
  }


  // Set up Mr. Atmel
  meta_events.fd=open_serial("/dev/ttyUSB0");
  reset_midi(meta_events.fd);
  setup_midi(meta_events.fd);

  memset(tracks,0,sizeof(tracks));

  track_num=0;
  meta_events.sequence_number=0;
  meta_events.tempo=500000;
  meta_events.time_signature[0]=4;
  meta_events.time_signature[1]=2;
  meta_events.time_signature[2]=0;
  meta_events.time_signature[3]=0;
  meta_events.key_signature[0]=0;
  meta_events.key_signature[1]=0;
  meta_events.division_usecs=meta_events.tempo/100;

  while(1)
  {
    if (track_num>=4) break;

    if (read_string_f(in,header,4)==-1)
    { break; }

    if (strcasecmp(header,"MThd")==0)
    {
      MThd_parse(in,&header_chunk,read_int(in));

      printf("\n--------------------------------------------\n");
      printf("   Header length: %d\n",header_chunk.header_length);
      printf("          Format: %d\n",header_chunk.format);
      printf("Number of Tracks: %d\n",header_chunk.tracks);
      printf("        Division: %d\n",header_chunk.division);
      printf("--------------------------------------------\n");

      meta_events.division_usecs=meta_events.tempo/header_chunk.division;
    }
      else
    if (strcasecmp(header,"MTrk")==0)
    {
      tracks[track_num].len=read_int(in);
      tracks[track_num].data=malloc(tracks[track_num].len);
      if (tracks[track_num].data==0)
      {
        printf("Could not allocate memory for track %d\n",track_num);

        track_num=-1;
        break;
      }

      fread(tracks[track_num].data,1,tracks[track_num].len,in);
      printf("\n--------------------------------------------\n");
      printf("Track: %d\n",track_num);
      printf("  Len: %d\n",tracks[track_num].len);
      printf("--------------------------------------------\n");

      track_num++;
    }
      else
    {
      printf("Unknown track type: %s\n",header);
    }
  }

  fclose(in);

  if (track_num>0)
  {
    MTrk_parse(tracks, &header_chunk, &meta_events, track_num);
  }

  for (t=0; t<4; t++)
  {
    if (tracks[t].data!=0) free(tracks[t].data);
  }

  sleep(1);
  packet[0]=0x80;
  packet[1]=0x00;
  packet[2]=0x00;
  send_packet(meta_events.fd,packet);
  reset_midi(meta_events.fd);
  close_serial(meta_events.fd);

  return 0;
}

