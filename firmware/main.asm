;ATtiny212 or ATtiny412
;1 VCC
;2 PA6 TX to MAX232
;3 PA7 RX from MAX232
;4 PA1 Digital Input: Power Supply 0 failed (0=ok, 1=failed)
;5 PA2 Digital Input: Power Supply 1 failed (0=ok, 1=failed)
;6 UPDI
;7 EXTCLK (from 1.8432 MHz oscillator)
;8 GND

    ;Definitions file "tn212.def.asm" or "tn412.def.asm"
    ;will be included first by the Makefile.

    .area code (abs)
    .list (me)

    .org PROGMEM_START/2  ;/2 because PROGMEM_START constant is byte-addressed
                          ;but ASAVR treats program space as word-addressed.
    rjmp reset

    ;All interrupt vectors jump to fatal error (interrupts are not used)
    .rept INT_VECTORS_SIZE - 1
    rjmp fatal
    .endm

    ;Code starts at first location after vectors
    .assume . - ((PROGMEM_START/2) + INT_VECTORS_SIZE)

reset:
    ;Clear RAM
    ldi ZL, <INTERNAL_SRAM_START
    ldi ZH, >INTERNAL_SRAM_START
    clr r16
1$: st Z, r16                 ;Store 0 at Z
    ld r16, Z+                ;Read it back, increment Z
    tst r16                   ;Did it read back as 0?
    breq 2$                   ;Yes: continue clearing
    rjmp fatal                ;No: hardware failure, jump to fatal
2$: cpi ZL, <(INTERNAL_SRAM_END+1)
    brne 1$
    cpi ZH, >(INTERNAL_SRAM_END+1)
    brne 1$

    ;Initialize stack pointer
    ldi r16, <INTERNAL_SRAM_END
    out CPU_SPL, r16
    ldi r16, >INTERNAL_SRAM_END
    out CPU_SPH, r16

    rcall wdog_init
    rcall osci_init
    rcall gpio_init
    rcall uart_init

main_loop:
    wdr                       ;Keep watchdog happy

    rcall self_test           ;Self-test each iteration (jumps to fatal if failed)

    rcall uart_has_error      ;UART error occurred?
    brcc 1$                   ;No: keep going
    rjmp fatal                ;Yes: reset to ensure UART fully recovers

1$: rcall uart_has_byte       ;Byte received?
    brcc main_loop            ;No: keep waiting

    rcall uart_read_byte
    cpi r16, '\r              ;Byte received = '\r'?
    brne main_loop            ;No: keep waiting

    rcall check_supplies
    rcall send_status_line
    rjmp main_loop

;Check power supplies 0 and 1
;Blocks for at least 25ms to debounce
;Returns R16 = Bitfield of power supply failed statuses
;              Bit 7..2 Unused
;              Bit    1 Power Supply 1 failed (0=ok, 1=failed)
;              Bit    0 Power Supply 0 failed (0=ok, 1=failed)
;Destroys R16,R17,R18
check_supplies:
    ldi r18, 25             ;Debounce: PORTA must be the same for N readings

1$: lds r16, PORTA_IN       ;Read once
    andi r16, 0b00000110    ;PA2=Power Supply 1, PA1=Power Supply 0

    push r16
    rcall delay_1ms         ;Delay 1ms
    pop r16

    lds r17, PORTA_IN       ;Read again
    andi r17, 0b00000110

    cp r16, r17
    brne check_supplies     ;Start over if readings are different

    dec r18
    brne 1$                 ;Loop until all required readings are the same

    ;R16 and R17 both contain the debounced and masked PORTA
    lsr r16                 ;Rotate right once so bit 1 = Supply 1, bit 0 = Supply 0
    ret

;Send status line like "PS0=OK,PS1=OK\r\n"
;Call with R16=statuses bitfield from check_supplies
send_status_line:
    push r16                ;Push supply statuses bitfield
    andi r16, 1             ;Mask off to leave only bit 0 (supply 0 status)
    ldi r17, '0             ;Supply number to display in ASCII = '0'
    rcall send_ps_status

    ldi r16, ',
    rcall uart_send_byte

    pop r16                 ;Pop supplies bitfield
    lsr r16                 ;Rotate bit 0 (supply 1 status) into bit 0
    ldi r17, '1             ;Supply number to display in ASCII = '1'
    rcall send_ps_status

    rjmp uart_send_crlf

;Send "PSn=OK" or "PSn=FAIL"
;Call with R16=failed status in bit 0 (0=ok, 1=failed)
;          R17=power supply number in ASCII ('0' or '1')
send_ps_status:
    push r16              ;Push status in bit 0
    push r17              ;Push power supply number

    ldi ZL, <(ps * 2)
    ldi ZH, >(ps * 2)
    rcall uart_send_str   ;Send "PS"

    pop r16               ;Pop power supply number in ASCII
    rcall uart_send_byte

    pop r16               ;Pop status in bit 0
    sbrc r16, 0           ;Skip branch if bit 0 is clear (clear = supply is ok)
    breq 1$               ;Branch to show failed

    ldi ZL, <(equals_ok * 2)
    ldi ZH, >(equals_ok * 2)
    rjmp uart_send_str    ;Send "=OK"

1$: ldi ZL, <(equals_fail * 2)
    ldi ZH, >(equals_fail * 2)
    rjmp uart_send_str    ;Send "=FAIL"

.nval ps,.
    .ascii "PS"
    .byte 0

.nval equals_fail,.
    .ascii "=FAIL"
    .byte 0

.nval equals_ok,.
    .ascii "=OK"
    .byte 0

;Ensure the watchdog was started by the fuses and reset the timer.
;The WDR instruction must be executed at least once every 4 seconds
;or the watchdog will reset the system.
wdog_init:
    ;Ensure watchdog period has been configured
    lds r16, WDT_CTRLA
    andi r16, WDT_PERIOD_gm
    cpi r16, WDT_PERIOD_4KCLK_gc      ;Watchdog period set by the fuses?
    breq 1$                           ;Yes: continue
    rjmp fatal                        ;No: bad fuses, jump to fatal

    ;Ensure watchdog is locked so it can't be stopped
1$: lds r16, WDT_STATUS
    sbrs r16, WDT_LOCK_bp             ;Skip fatal if locked
    rjmp fatal

    wdr                               ;Reset watchdog timer
    ret

;Switch to the external oscillator.
;Interrupts must be disabled before calling.
osci_init:
    ldi r16, CPU_CCP_IOREG_gc

    ;Disable clock prescaler
    clr r17                           ;No prescaler
    out CPU_CCP, r16                  ;Unlock Protected I/O Registers
    sts CLKCTRL_MCLKCTRLB, r17        ;Disable clock prescaler

    ;Switch to external 1.8432 MHz oscillator
    ldi r17, CLKCTRL_CLKSEL_EXTCLK_gc ;EXTCLK 1.8432 MHz external clock
    out CPU_CCP, r16                  ;Unlock Protected I/O Registers
    sts CLKCTRL_MCLKCTRLA, r17        ;Use EXTCLK for main clock
    ret

;Set up GPIO directions (UART pin directions are set in uart_init)
gpio_init:
    ldi r16, 1<<2 | 1<<1    ;PA2, PA1 = input
    sts PORTA_DIRCLR, r16
    ret

;Initialize the UART
uart_init:
    ;Set baud rate to 9600 bps for 1.8432 MHz crystal
    ;#define F_CPU 1843200
    ;#define USART0_BAUD_RATE(BAUD_RATE) ((float)(F_CPU * 64 / (16 * (float)BAUD_RATE)) + 0.5)
    ;USART0.BAUD = (uint16_t)USART0_BAUD_RATE(9600);
    ldi r16, 0x00
    sts USART0_BAUDL, r16
    ldi r16, 0x03
    sts USART0_BAUDH, r16

    ;8N1
    ldi r16, USART_NORMAL_CMODE_ASYNCHRONOUS_gc | USART_NORMAL_CHSIZE_8BIT_gc | USART_NORMAL_PMODE_DISABLED_gc | USART_NORMAL_SBMODE_1BIT_gc
    sts USART0_CTRLC, r16

    ;Set pin directions
    ldi r16, 1<<7           ;pa7 = rx (input)
    sts PORTA_DIRCLR, r16
    ldi r16, 1<<6           ;pa6 = tx (output)
    sts PORTA_DIRSET, r16

    ;Enable transmit and receive
    lds r16, USART0_CTRLB
    ori r16, USART_TXEN_bm | USART_RXEN_bm
    sts USART0_CTRLB, r16
    ret

;Check if one of the UART error flags is set
;Sets carry on error
uart_has_error:
    clc
    lds r16, USART0_RXDATAH
    andi r16, USART_BUFOVF_bm | USART_FERR_bm | USART_PERR_bm
    breq 1$
    sec
1$: ret

;Check if a byte has been received from the UART
;Sets carry if one is available
uart_has_byte:
    lds r16, USART0_STATUS
    .assume 7 - USART_RXCIF_bp  ;RXCIF must be bit 7 for ROL to work
    rol r16                     ;Rotate RXCIF into carry (0=no char, 1=char avail)
    ret

;Read a byte from the UART
;Blocks until a byte has been received
uart_read_byte:
    rcall uart_has_byte
    brcc uart_read_byte
    lds r16, USART0_RXDATAL
    ret

;Write a byte to the UART
;Blocks until the UART accepts the byte
;Destroys R17
uart_send_byte:
    lds r17, USART0_STATUS
    sbrs r17, USART_DREIF_bp  ;Skip next if USART_DREIF=1 (tx ready)
    rjmp uart_send_byte

    sts USART0_TXDATAL, r16
    ret

;Send CRLF to the UART.
;Destroys R16
uart_send_crlf:
    ldi r16, '\r
    rcall uart_send_byte
    ldi r16, '\n
    rjmp uart_send_byte

;Send a null-terminated string to the UART
;Destroys R16 and Z
uart_send_str:
    lpm r16, Z+           ;Read byte from string
    tst r16               ;End of string?
    breq 2$               ;Yes: Branch to return
    rcall uart_send_byte
    rjmp uart_send_str
2$: ret

;Wait 1ms.  Destroy R16,R17
delay_1ms:
    ldi r16, 6
1$: ldi r17, 0xc5
2$: dec r17
    brne 2$
    dec r16
    brne 1$
    ret

;Perform self-test.  Jumps to fatal if the test fails.
self_test:
    rcall test_ram
    rjmp test_rom

;Test the RAM non-destructively.  Jumps to fatal if test the fails.
;Interrupts must be disabled before calling.
;Destroys R20, R21, Z.
test_ram:
    ldi ZL, <INTERNAL_SRAM_START
    ldi ZH, >INTERNAL_SRAM_START

1$: ld r21, Z       ;Save original value in R21

    ldi r20, 0x55
    st Z, r20
    ld r20, Z
    cpi r20, 0x55
    breq 2$
    rjmp fatal      ;Pattern 0x55 failed

2$: ldi r20, 0xaa
    st Z, r20
    ld r20, Z
    cpi r20, 0xaa
    breq 3$
    rjmp fatal      ;Pattern 0xAA failed

3$: st Z+, r21      ;Restore original value, increment Z
    cpi ZL, <(INTERNAL_SRAM_END+1)  ;Keep going until all RAM is tested
    brne 1$
    cpi ZH, >(INTERNAL_SRAM_END+1)
    brne 1$

    ret             ;RAM test passed

;Test the flash ROM by using the CRCSCAN peripheral to compute the
;CRC16 of the flash and compare it to the CRC16 stored in the last
;two bytes of the flash.  Jumps to fatal if they do not match.
;Destroys R16.
test_rom:
    ldi r16, CRCSCAN_ENABLE_bm
    sts CRCSCAN_CTRLA, r16    ;Start CRC scan

1$: lds r16, CRCSCAN_STATUS
    sbrc r16, CRCSCAN_BUSY_bp ;Skip next if busy=0 (scan finished)
    rjmp 1$

    sbrs r16, CRCSCAN_OK_bp   ;Skip next if ok=1 (scan passed)
    rjmp fatal

    ret

;End of code

    ;Fill all unused program words with a nop sled that ends with
    ;a software reset in case the program counter somehow gets here.
    .nval filler_start,.
    .rept ((PROGMEM_END/2) - filler_start - fatal_size)
    nop
    .endm

;Fatal error causes software reset
fatal:
    cli                       ;Disable interrupts
    ldi r16, CPU_CCP_IOREG_gc
    ldi r17, RSTCTRL_SWRE_bm
    out CPU_CCP, r16          ;Unlock Protected I/O Registers
    sts RSTCTRL_SWRR, r17     ;Software Reset

fatal_size = . - fatal

;Last program word (last 2 bytes) will be the CRC16 added by the Makefile
crc16:
    .assume . - (PROGMEM_END/2)
