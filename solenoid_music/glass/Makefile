JAVA_GRINDER_PATH=/path/to/java_grinder
JAVA_GRINDER=$(JAVA_GRINDER_PATH)/java_grinder
NAKEN_ASM_PATH=/path/to/naken_asm
INCLUDE=$(NAKEN_ASM_PATH)/naken_asm/include/msp430

default: GlassMusic.class
	$(JAVA_GRINDER) GlassMusic.class glass_music.asm msp430g2452
	naken_asm -I $(INCLUDE) -l -o glass_music.hex glass_music.asm

%.class: %.java
	javac -classpath $(JAVA_GRINDER_PATH)/build/JavaGrinder.jar:. $*.java

clean:
	@rm -f *.lst *.hex *.class *.asm
	@echo "Clean!"


