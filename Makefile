# include binaries and libraries from ece270 __saas__
export PATH := /home/shay/a/ece270/bin:$(PATH)
export LD_LIBRARY_PATH := /home/shay/a/ece270/lib:$(LD_LIBRARY_PATH)

# binary names
YOSYS=yosys
NEXTPNR=nextpnr-ice40
SHELL=bash

# project vars and filenames
PROJ	= lab04
PINMAP 	= pinmap.pcf
TCLPREF = addwave.gtkw
TB	= tb.sv
SRC	= top.sv vgadriver.sv snakeGrid.sv snakeGame.sv
ICE   	= ice40hx8k.sv
UART	= uart/uart.v uart/uart_tx.v uart/uart_rx.v
FILES   = $(ICE) $(SRC) $(UART)
TRACE	= $(PROJ).vcd
BUILD   = ./build

# fpga specific configuration
DEVICE  = 8k
TIMEDEV = hx8k
FOOTPRINT = ct256


# set default target to cram
all: cram

# this target checks your code and synthesizes it into a netlist
$(BUILD)/$(PROJ).json : $(ICE) $(SRC) $(PINMAP) Makefile
	# lint with Verilator
	verilator --lint-only -Werror-WIDTH -Werror-SELRANGE -Werror-COMBDLY -Werror-LATCH -Werror-MULTIDRIVEN $(SRC)
	# if build folder doesn't exist, create it
	mkdir -p $(BUILD)
	# synthesize using Yosys
	# $(YOSYS) -p "read_verilog -sv -noblackbox $(FILES); synth_ice40 -top ice40hx8k -json $(BUILD)/$(PROJ).json"
	# synthesize using Yosys
	$(YOSYS) -p "read_verilog -sv -noblackbox $(FILES); \
		hierarchy -top ice40hx8k; \
		synth_ice40 -top ice40hx8k; \
		opt_clean -purge; clean -purge; \
		write_json $(BUILD)/$(PROJ).json"




# Place and route using nextpnr
$(BUILD)/$(PROJ).asc : $(BUILD)/$(PROJ).json
	$(NEXTPNR) --hx8k --package ct256 --pcf $(PINMAP) --asc $(BUILD)/$(PROJ).asc --json $(BUILD)/$(PROJ).json 2> >(sed -e 's/^.* 0 errors$$//' -e '/^Info:/d' -e '/^[ ]*$$/d' 1>&2)

# Convert to bitstream using IcePack
$(BUILD)/$(PROJ).bin : $(BUILD)/$(PROJ).asc
	icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin

# generate a waveform file for visual debugging
$(TRACE): $(TB) $(SRC)
	iverilog -g2012 $(TB) $(SRC) -o sim.vvp
	vvp -N sim.vvp 1> >(sed -e 's/^.* 0 errors$$//' -e '/^Info:/d' -e '/^[ ]*$$/d' 1>&2)
	rm -f sim.vvp

# Run GTKWave
verify: $(TRACE)
	gtkwave $(TCLPREF)

# synthesize and flash the FPGA
cram: $(BUILD)/$(PROJ).bin
	iceprog -S $(BUILD)/$(PROJ).bin

# remove intermediate build files
clean:
	rm -rf build/ verilog.log $(PROJ).vcd