PROJECT=redundant12v
MMCU=t212
ISPFLAGS=-c atmelice_updi

all: clean $(PROJECT).hex

$(PROJECT).hex: $(PROJECT).bin
	srec_cat $(PROJECT).bin -binary -o $(PROJECT).hex -intel -address-length=2 -line-length=76 -crlf

$(PROJECT).bin: main.asm
	cp -f main.asm $(PROJECT).asm
	asavr -l -o $(PROJECT).asm
	rm -f $(PROJECT).asm
	aslink -i $(PROJECT)
	srec_cat $(PROJECT).ihx -intel -o $(PROJECT).bin -binary
	rm $(PROJECT).hlr $(PROJECT).ihx $(PROJECT).rel
	python3 checksum.py update $(PROJECT).bin

program: $(PROJECT).hex
	avrdude $(ISPFLAGS) -p $(MMCU) -U flash:w:$(PROJECT).hex

clean:
	rm -f $(PROJECT).*
