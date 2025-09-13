
struct _header_chunk
{
  int header_length;
  int format;
  int tracks;
  int division;
};

struct _meta_events
{
  int sequence_number;
  int tempo;
  char smpte_offset[6];
  char time_signature[5];
  char key_signature[3];
  useconds_t division_usecs;
  int fd;
};

struct _midi_track
{
  unsigned int len;
  unsigned char *data;
  int running_status;
  int ptr;
  int division;
  int state;
};

/*  NOTE TO SELF

cat sid_freqs.txt | grep -v '\-\-' | grep -v NOTE | awk -F'|' '{ print $4 $3 $2 }' | awk -F' ' '{ print "    "$1",  // "$2" "$3 }' > sid_freqs.h 

*/



