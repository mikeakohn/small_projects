
int read_string_f(FILE *in, char *s, int n);
int read_string(struct _midi_track *track, char *s, int n);
int print_string(struct _midi_track *track, int n);
int read_count(struct _midi_track *track, int n);
int read_var(struct _midi_track *track);
int parse_extras(struct _midi_track *track, int channel);
int read_int(FILE *in);
int read_short(FILE *in);

