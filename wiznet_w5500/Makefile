
PROGRAM=w5500
INCLUDE=../naken_asm/include
NAKEN_ASM=../naken_asm/naken_asm

default:
	$(NAKEN_ASM) -l -o $(PROGRAM).hex -I$(INCLUDE) $(PROGRAM).asm

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

