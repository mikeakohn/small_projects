DEBUG=-DDEBUG -g
CFLAGS=-Wall -O2 $(DEBUG)
PROGRAM=tape_data_recorder

default: $(PROGRAM).hex

$(PROGRAM).hex: $(PROGRAM).asm
	gavrasm /storage/atmel $(PROGRAM).asm

tavrasm:
	~/downloads/tavrasm.122/src/tavrasm -I /storage/atmel $(PROGRAM).asm

install: $(PROGRAM).hex
	cp $(PROGRAM).hex /storage/samba/hexfiles/

recorder:
	gcc -o data_record data_record.c -Wall -O2
	gcc -o data_read data_read.c -Wall -O2

clean:
	@rm -f *.hex
	@rm -f *.lst
	@rm -f data_read
	@rm -f data_record
	@echo "Clean!"

