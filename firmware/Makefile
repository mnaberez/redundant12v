PROJECT=redundant12v
MMCU=t212
CRC16ADDR=0x07fe
ISPFLAGS=-c atmelice_updi

all: clean $(PROJECT).hex

$(PROJECT).hex: $(PROJECT).bin
	srec_cat $(PROJECT).bin -binary -o $(PROJECT).hex -intel -address-length=2 -line-length=76 -crlf

$(PROJECT).bin: main.asm
	cp -f main.asm $(PROJECT).asm
	asavr -l -p -w -o $(PROJECT).asm
	rm -f $(PROJECT).asm
	aslink -i $(PROJECT)
	# requires srecord 1.64 or later
	srec_cat $(PROJECT).ihx -intel -CRC16_Big_Endian $(CRC16ADDR) -broken -o $(PROJECT).bin -binary
	rm $(PROJECT).hlr $(PROJECT).ihx $(PROJECT).rel

program: $(PROJECT).hex
	avrdude $(ISPFLAGS) -p $(MMCU) -U flash:w:$(PROJECT).hex

clean:
	rm -f $(PROJECT).*
