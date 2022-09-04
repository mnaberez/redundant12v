PROJECT=redundant12v
MCU=t212
ISPFLAGS=-c atmelice_updi

PROJECT_FLASH = $(PROJECT)_$(MCU)_flash
PROJECT_FUSES = $(PROJECT)_$(MCU)_fuses

ifeq ($(MCU),t212)
# attiny212 flash 0x0000-0x07ff
CRC16ADDR=0x07fe
DEFSFILE=tn212def.asm
else ifeq ($(MCU),t412)
# attiny412 flash 0x0000-0x0fff
CRC16ADDR=0x0ffe
DEFSFILE=tn412def.asm
else
$(error Unrecognized MCU value)
endif

all: $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex

clean:
	rm -f $(PROJECT)_*_flash.*
	rm -f $(PROJECT)_*_fuses.*

program: $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex
	avrdude $(ISPFLAGS) -p $(MCU) -e -U flash:w:$(PROJECT_FLASH).hex:i -U fuses:w:$(PROJECT_FUSES).hex:i

$(PROJECT_FLASH).hex: main.asm
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o $(PROJECT_FLASH) main.asm
	aslink -i $(PROJECT_FLASH)
	# add crc16 (requires srecord 1.64 or later)
	srec_cat $(PROJECT_FLASH).ihx -intel -CRC16_Big_Endian $(CRC16ADDR) -broken -o $(PROJECT_FLASH).hex -intel -line-length=76 -crlf
	rm $(PROJECT_FLASH).hlr $(PROJECT_FLASH).ihx $(PROJECT_FLASH).rel

$(PROJECT_FUSES).hex: fuses.asm
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o $(PROJECT_FUSES) fuses.asm
	aslink -i $(PROJECT_FUSES)
	mv $(PROJECT_FUSES).ihx $(PROJECT_FUSES).hex
	rm $(PROJECT_FUSES).hlr $(PROJECT_FUSES).rel
