PROJECT=redundant12v
MMCU=t212
CRC16ADDR=0x07fe
ISPFLAGS=-c atmelice_updi

PROJECT_FLASH = $(PROJECT)_flash
PROJECT_FUSES = $(PROJECT)_fuses

all: clean $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex

clean:
	rm -f $(PROJECT_FLASH).* $(PROJECT_FUSES).*

program: $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex
	avrdude $(ISPFLAGS) -p $(MMCU) -U flash:w:$(PROJECT_FLASH).hex:i -U fuses:w:$(PROJECT_FUSES).hex:i

$(PROJECT_FLASH).hex: main.asm
	cp -f main.asm $(PROJECT_FLASH).asm
	asavr -l -p -w -o $(PROJECT_FLASH).asm
	rm -f $(PROJECT_FLASH).asm
	aslink -i $(PROJECT_FLASH)
	# add crc16 (requires srecord 1.64 or later)
	srec_cat $(PROJECT_FLASH).ihx -intel -CRC16_Big_Endian $(CRC16ADDR) -broken -o $(PROJECT_FLASH).hex -intel -line-length=76 -crlf
	rm $(PROJECT_FLASH).hlr $(PROJECT_FLASH).ihx $(PROJECT_FLASH).rel

$(PROJECT_FUSES).hex: fuses.asm
	cp -f fuses.asm $(PROJECT_FUSES).asm
	asavr -l -p -w -o $(PROJECT_FUSES).asm
	rm -f $(PROJECT_FUSES).asm
	aslink -i $(PROJECT_FUSES)
	mv $(PROJECT_FUSES).ihx $(PROJECT_FUSES).hex
	rm $(PROJECT_FUSES).hlr $(PROJECT_FUSES).rel
