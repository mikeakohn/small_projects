CFLAGS=-O3 -Wall

default:
	gcc -c hexdump.c $(CFLAGS)
	gcc -c serialio.c $(CFLAGS)
	gcc -c tun.c $(CFLAGS)
	gcc -o test_tun test_tun.c hexdump.o tun.o $(CFLAGS)
	gcc -o test_serial test_serial.c hexdump.o serialio.o $(CFLAGS)
	gcc -o relay relay.c hexdump.o serialio.o tun.o $(CFLAGS)

clean:
	@rm -f *.o test_tun test_serial relay
	@echo "Clean!"

