all: clean out.hex

out.hex: out.bin
	srec_cat out.bin -binary -o out.hex -intel -address-length=2 -line-length=76 -crlf

out.bin:
	cp -f main.asm out.asm
	asavr -l -o out.asm
	rm -f out.asm
	aslink -i out
	srec_cat out.ihx -intel -fill 0xff 0x0000 0x0800 -o out.bin -binary
	rm out.hlr out.ihx out.rel

program: out.hex
	avrdude -c atmelice_updi -p t212 -U flash:w:out.hex

clean:
	rm -f out.*
