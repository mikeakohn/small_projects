
PROGRAM=atmel_vga

atmel_vga.hex: $(PROGRAM).asm image.inc
	tavrasm -c -I /mnt/devkits/atmel $(PROGRAM).asm

parse_bmp: parse_bmp.c
	gcc -o parse_bmp parse_bmp.c -Wall -O2 -DDEBUG

clean:
	@rm -f *.gen
	@rm -f *.hex
	@echo "Clean!"

