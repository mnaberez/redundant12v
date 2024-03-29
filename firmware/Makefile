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
	# add -i ".list" before -i ".include '$(DEFSFILE)'" to see it in the listing output
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o+$(PROJECT_FLASH) main.asm
	aslink -i $(PROJECT_FLASH)
	# srec_cat adds crc16 (requires srecord 1.64 or later)
	srec_cat $(PROJECT_FLASH).hex -intel -CRC16_Big_Endian $(CRC16ADDR) -broken -o $(PROJECT_FLASH).hex.srec_cat -intel -line-length=76 -crlf
	mv $(PROJECT_FLASH).hex.srec_cat $(PROJECT_FLASH).hex
	rm $(PROJECT_FLASH).hlr $(PROJECT_FLASH).rel

$(PROJECT_FUSES).hex: fuses.asm
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o+$(PROJECT_FUSES) fuses.asm
	aslink -i $(PROJECT_FUSES)
	rm $(PROJECT_FUSES).hlr $(PROJECT_FUSES).rel
