
int open_serial(char *device);
void close_serial(int fd);
void send_packet(int fd, unsigned char *packet);
void reset_sid(int fd);
void setup_sid(int fd);
void read_string_serial(int fd);

