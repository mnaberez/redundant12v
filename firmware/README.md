# Firmware

The firmware runs on an [Attiny212 or Attiny412](https://web.archive.org/web/20220715022600/https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/ATtiny212-14-412-14-Automotive-DS40002229A.pdf).  It configures the UART for 9600-N81 and then waits for a carriage return (`\r`).  Anything else is ignored.  When a `\r` is received, a status line ending with `\r\n` is printed:

```
PS0=OK,PS1=FAIL
```

Each supply is shown as either `OK` or `FAIL`.  

Note that while the firmware has the ability to report a simultaneous failure of both supplies, this won't work in practice, because the MCU itself will lose power.  If the MCU does not respond, it indicates a failure of both supplies or a failure of the MCU.  

## Design

The firmware consists of less than 500 bytes of AVR assembly.  Since the MCU is installed in an enclosure with no way to power it off or reset it, and will hopefully run for years, the firmware has been designed to be as simple and resilient as possible.  

There is a main loop that continuously polls the UART.  If a `\r` is received, the two digital inputs are read and the status line is sent.  Otherwise, RAM and ROM tests are performed before the next poll.  The intent of this is to use the idle time to try and detect hardware problems that could cause a false status to be reported.  The ROM test is done by the CRCSCAN peripheral, which is also configured to run on reset and block the firmware from starting if the CRC check fails.  If the firmware encounters any error while it runs, it resets the MCU using the RSTCTRL peripheral.  No interrupts are used so execution is more deterministic.  If the program counter somehow wanders into the interrupt vectors or the unused code space, the firmware will reset the MCU.  The watchdog peripheral is also configured to reset the MCU if the firmware gets stuck somehow.  

The two status LEDs on the enclosure are not controlled by the MCU, so they will continue to reflect the state of the supplies if the MCU fails.

## Build

Building requires:

- ASAVR (part of the [ASxxxx](https://shop-pdp.net/ashtml/) cross-assemblers package)
- [SRecord](http://srecord.sourceforge.net/) version 1.64 or later
- GNU [Make](https://www.gnu.org/software/make/)
- A Unix-like operating system (e.g. Linux, macOS)

Run `make` to build the firmware for the Attiny212.  It will produce two files in Intel hex format: one for the Attiny212 flash and one for the fuses.  See the [`Makefile`](./Makefile) and the [GitHub workflow](../.github/workflows/main.yml).

To build for the Attiny412 instead, run `make MCU=t412`.  There's no benefit to using the Attiny412 over the Attiny212 for this project.  Use whichever one has better pricing or availability.

## Flash

Flashing requires:

- [AVRDUDE](https://github.com/avrdudes/avrdude)
- An [Atmel-ICE](https://www.microchip.com/en-us/development-tool/ATATMEL-ICE) device programmer

Run `make program` to flash the MCU.  This will completely program a blank part so that it is ready to use.

## Test

[Minicom](https://salsa.debian.org/minicom-team/minicom/) can be used to test:

```text
$ minicom -b 9600 -D /dev/ttyS0
```

The status line should be displayed when the enter key is pressed.

## References

- [Attiny212 / Attiny412 Datasheet](https://web.archive.org/web/20220715022600/https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/ATtiny212-14-412-14-Automotive-DS40002229A.pdf)
- [AVR Instruction Set Manual](https://web.archive.org/web/20211122051203/http://ww1.microchip.com/downloads/en/devicedoc/atmel-0856-avr-instruction-set-manual.pdf)
