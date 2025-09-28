#ifndef _SERIALIO_H
#define _SERIALIO_H

#include <stdint.h>

int serial_open(char *device);
void serial_close(int fd);
int serial_send(int fd, const uint8_t *buffer, int length);
int serial_read(int fd, uint8_t *buffer, int length);
int serial_has_bytes(int fd);

#endif

