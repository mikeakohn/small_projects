
PROGRAM=winbond
INCLUDE=../naken_asm/include

default:
	naken_asm -l -o $(PROGRAM).hex -I$(INCLUDE) $(PROGRAM).asm

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

