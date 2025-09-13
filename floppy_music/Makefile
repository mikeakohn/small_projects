
DEBUG=-DDEBUG -g
CFLAGS=-Wall -O2 $(DEBUG)
PROGRAM=floppy_midi

$(PROGRAM).hex: $(PROGRAM).asm
	tavrasm -c -I /mnt/devkits/atmel $(PROGRAM).asm

player:
	gcc -c fileio.c $(CFLAGS)
	gcc -c serialio.c $(CFLAGS)
	gcc -o midi_player midi_player.c fileio.o serialio.o $(CFLAGS)

clean:
	@rm -f *.gen
	@rm -f *.hex
	@rm -f *.o
	@rm -f midi_player
	@rm -f midi_notes.inc
	@echo "Clean!"

