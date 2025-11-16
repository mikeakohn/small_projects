
PROGRAM=vacuum_tube_oven
#PORT=/dev/ttyUSB0
PORT=/dev/ttyACM0
NAKEN_ASM=../naken_asm/naken_asm

default: $(PROGRAM).hex

$(PROGRAM).hex: $(PROGRAM).asm
	${NAKEN_ASM} -l -I/devkits/atmel -o $(PROGRAM).hex $(PROGRAM).asm

program:
	avrdude -c stk500 -p t2313 -P ${PORT} -U flash:w:$(PROGRAM).hex

setfuse:
	avrdude -c stk500 -p t2313 -P ${PORT} -U lfuse:w:0xe4:m
	avrdude -c stk500 -p t2313 -P ${PORT} -U hfuse:w:0xdf:m

getfuse:
	avrdude -c stk500 -p t2313 -P ${PORT} -U lfuse:r:-:h
	avrdude -c stk500 -p t2313 -P ${PORT} -U hfuse:r:-:h

install:
	cp $(PROGRAM).hex /storage/samba/hexfiles/

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

