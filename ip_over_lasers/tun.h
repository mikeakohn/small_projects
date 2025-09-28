#ifndef _TUN_H
#define _TUN_H

#include <stdint.h>

int tun_open();
void tun_close(int fd);
int tun_send(int fd, const uint8_t *buffer, int length);
int tun_read(int fd, uint8_t *buffer, int length);
int tun_has_bytes(int fd);

#endif

