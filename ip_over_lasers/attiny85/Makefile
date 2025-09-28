
PROGRAM=laser_relay

default: $(PROGRAM).hex

$(PROGRAM).hex: $(PROGRAM).asm
	naken_asm -l -I$(DEVKIT_PATH)/atmel -o $(PROGRAM).hex $(PROGRAM).asm

program:
	avrdude -c usbtiny -p t85 -b19200 -v -U flash:w:$(PROGRAM).hex

setfuse:
	avrdude -c usbtiny -p t85 -b19200 -v -U lfuse:w:0xe2:m

clean:
	@rm -f *.hex
	@rm -f *.lst
	@echo "Clean!"

