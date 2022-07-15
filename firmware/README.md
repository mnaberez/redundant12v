# Firmware

The firmware runs on an [Attiny212](https://web.archive.org/web/20220715022600/https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/ATtiny212-14-412-14-Automotive-DS40002229A.pdf).  It configures the UART for 9600-N81 and then waits for a carriage return (`\r`).  Anything else is ignored.  When a `\r` is received, a status line ending with `\r\n` is printed:

```
PS0=OK,PS1=FAIL
```

Each supply is shown as either `OK` or `FAIL`.  

Note that while the firmware has the ability to report a simultaneous failure of both supplies, this won't work in practice, because the MCU itself will lose power.  If the MCU does not respond, it indicates a failure of both supplies or a failure of the MCU.  

## Design

The firmware consists of less than 500 bytes of AVR assembly.  Since the MCU is installed in an enclosure with no way to power it off or reset it, and will hopefully run for years, the firmware has been designed to be as simple and resilient as possible.  

There is a single loop (no interrupts).  When a `\r` is received, the two input lines are read and the status line is sent.  While it is idle, the firmware continuously runs RAM and ROM tests.  The ROM test is done by the CRCSCAN peripheral.  If any error is detected, a reset will be performed using the RSTCTRL peripheral.  If the firmware gets stuck somehow, the watchdog peripheral will reset the MCU.

A hardware failure in the MCU will cause it to become unresponsive.  The two LEDs are not controlled by the MCU, so they will continue to reflect the state of the supplies if the MCU fails.

## Build

Building requires:

- ASAVR (part of the [ASxxxx](https://shop-pdp.net/ashtml/) cross-assemblers package)
- [SRecord](http://srecord.sourceforge.net/) version 1.64 or later
- GNU [Make](https://www.gnu.org/software/make/)
- A Unix-like operating system (e.g. Linux, macOS)

Run `make` to build the firmware.  It will produce two files in Intel hex format: one for the Attiny212 flash and one for the fuses.  See the [`Makefile`](./Makefile) and the [GitHub workflow](../.github/workflows/main.yml).

## Flash

Flashing requires:

- [AVRDUDE](https://github.com/avrdudes/avrdude)
- An [Atmel-ICE](https://www.microchip.com/en-us/development-tool/ATATMEL-ICE) device programmer

Run `make program` to flash the Attiny212.  This will completely program a blank part so that it is ready to use.

## Test

[Minicom](https://salsa.debian.org/minicom-team/minicom/) can be used to test:

```text
$ minicom -b 9600 -D /dev/ttyS0
```

The status line should be displayed when the enter key is pressed.

## References

- [Attiny212 Datasheet](https://web.archive.org/web/20220715022600/https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/ATtiny212-14-412-14-Automotive-DS40002229A.pdf)
- [AVR Instruction Set Manual](https://web.archive.org/web/20211122051203/http://ww1.microchip.com/downloads/en/devicedoc/atmel-0856-avr-instruction-set-manual.pdf)
