
PROGRAM=nexys2_rs232
PART=xc3s500e-fg320
#PART=xc3s200-ft256

default:
	echo "run -ifn $(PROGRAM).prj -ifmt VHDL -ofn $(PROGRAM) -p $(PART) -opt_mode Speed -opt_level 1" | xst
	ngdbuild -p $(PART) -uc $(PROGRAM).ucf $(PROGRAM).ngc
	map -detail -pr b $(PROGRAM).ngd
	par -w $(PROGRAM).ncd parout.ncd $(PROGRAM).pcf
	bitgen -w -g StartUpClk:JtagClk -g CRC:Enable parout.ncd $(PROGRAM).bit $(PROGRAM).pcf

install:
	djtgcfg -d DOnbUsb prog -i 0 -f $(PROGRAM).bit

clean:
	@rm -rf xst
	@rm -f *.ngc
	@rm -f *.srp
	@rm -f *.xrpt
	@rm -f *.bgn
	@rm -f *.bld
	@rm -f *.drc
	@rm -f *.par
	@rm -f *.pad
	@rm -f *.xpi
	@rm -f *.map
	@rm -f *.mrp
	@rm -f *.ncd
	@rm -f *.ngd
	@rm -f *.ngm
	@rm -f *.bit
	@rm -f *.pcf
	@rm -f *.twr
	@rm -f parout*
	@rm -f *.lst
	@rm -f *.unroutes
	@rm -f *.xml
	@rm -rf xlnx_auto_0_xdb
	@echo "Clean!"

