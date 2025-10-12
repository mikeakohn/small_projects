
PROGRAM=edible_midi

default: $(PROGRAM).hex

$(PROGRAM).hex: $(PROGRAM).asm
	naken_asm -l -I/usbdisk/devkits/atmel -o $(PROGRAM).hex $(PROGRAM).asm

program:
	minipro -p ATTINY2313A@DIP20 -w $(PROGRAM).hex
	minipro -p ATTINY2313A@DIP20 -w config.txt -c config
	minipro -p ATTINY2313A@DIP20 -r config.new -c config

program_avr_dude:
	avrdude -c stk500 -p t2313 -P /dev/ttyUSB0 -U flash:w:$(PROGRAM).hex

setfuse:
	avrdude -c stk500 -p t2313 -P /dev/ttyUSB0 -U lfuse:w:0x8f:m

install:
	cp $(PROGRAM).hex /storage/samba/hexfiles/

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

