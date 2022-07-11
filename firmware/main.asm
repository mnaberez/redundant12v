;ATtiny212
;1 VCC
;2 PA6 TX -> MAX232CPE  T1IN 11 -> T1OUT 14 -> DB9 TX 2
;3 PA7 RX <- MAX232CPE R1OUT 12 <-  R1IN 13 <- DB9 RX 3
;4 PA1 <- Power Supply 0 status (0=fail, 1=ok)
;5 PA2 <- Power Supply 1 status (0=fail, 1=ok)
;6 UPDI
;7 EXTCLK
;8 GND    -> DB9 GND 5

    .area code (abs)
    .list (me)

    .include "tn212def.asm"

ram = SRAM_START
supplies = ram+0x00   ;Bitfield of power supply "ok" statuses (0=fail, 1=ok)
                      ;Bit 7..2 Unused
                      ;Bit    1 Power Supply 1
                      ;Bit    0 Power Supply 0

    .org PROGMEM_START

    ;All vectors jump to reset (this program does not use interrupts)
    .rept INT_VECTORS_SIZE
    rjmp reset
    .endm

    ;Code starts at first location after vectors
    .assume . - (PROGMEM_START + INT_VECTORS_SIZE)

reset:
  	;Initialize stack pointer
    ldi r16, RAMEND & 0xFF
    out CPU_SPL, r16
    ldi r16, RAMEND >> 8
    out CPU_SPH, r16

  	;Disable clock prescaler
  	clr r16
  	ldi r17, CPU_CCP_IOREG_gc
  	sts CPU_CCP, r17					        ;Unlock Protected I/O Registers
  	sts CLKCTRL_MCLKCTRLB, r16			  ;Disable clock prescaler

  	;Switch to external 1.8432 MHz oscillator
  	ldi r16, CLKCTRL_CLKSEL_EXTCLK_gc	;EXTCLK 1.8432 MHz external clock
  	sts CPU_CCP, r17					        ;Unlock Protected I/O Registers
  	sts CLKCTRL_MCLKCTRLA, r16			  ;Use EXTCLK for main clock

    rcall test_rom            ;Never returns if ROM test fails
    rcall gpio_init
    rcall uart_init

main_loop:
    rcall uart_has_error      ;UART error occured?
    brcs error                ;Branch if error

    rcall uart_has_byte       ;Byte received?
    brcc main_loop            ;No: keep waiting

    rcall uart_read_byte
    cpi r16, '\r              ;Byte received = '\r'?
    brne main_loop            ;No: keep waiting

    rcall update_supplies
    rcall send_status_line
    rjmp main_loop

error:
    rcall uart_clear_error    ;Clear the UART error
    rjmp main_loop


;Check power supplies 0 and 1 and update "supplies" bitfield
;Blocks for at least 25ms to debounce
;Destroys R16,R17,R18
update_supplies:
    ldi r18, 25             ;Debounce: PORTA must be the same for N readings

1$:
    lds r16, PORTA_IN       ;Read once
    andi r16, 0b00000110    ;PA2=Power Supply 1, PA1=Power Supply 0

    push r16
    rcall delay_1ms         ;Delay 1ms
    pop r16

    lds r17, PORTA_IN       ;Read again
    andi r17, 0b00000110

    cp r16, r17
    brne update_supplies    ;Start over if readings are different

    dec r18
    brne 1$                 ;Loop until all required readings are the same

    ;R16 and R17 both contain the debounced and masked PORTA

    lsr r16                 ;Rotate right once so bit 1 = Supply 1, bit 0 = Supply 0
    sts supplies,r16        ;Store as new supplies status
    ret

;Send status like like "PS0=OK,PS1=OK\r\n"
send_status_line:
    ldi r16, '0             ;Supply number to display in ASCII = '0'
    lds r17, supplies       ;Get supplies bitfield
    andi r17, 1             ;Mask off to leave only bit 0 (supply 0 status)
    rcall send_ps_status

    ldi r16, ',
    rcall uart_send_byte

    ldi r16, '1             ;Supply number to display in ASCII = '1'
    lds r17, supplies       ;Get supplies bitfield
    lsr r17                 ;Rotate bit 0 (supply 1 status) into bit 0
    rcall send_ps_status

    rjmp uart_send_crlf

;Send "PSn=OK" or "PSn=FAIL"
;R16=power supply number in ASCII ('0' or '1')
;R17=status (0=fail, 1=ok)
send_ps_status:
    push r17              ;Push status
    push r16              ;Push power supply number

    ldi ZL, <(ps * 2)
    ldi ZH, >(ps * 2)
    rcall uart_send_str   ;Send "PS"

    pop r16               ;Pop power supply number in ASCII
    rcall uart_send_byte

    pop r16               ;Pop status
    sbrc r16, 0           ;Skip branch if bit 0 is clear (supply failed)
    breq 1$               ;Branch to show OK

    ldi ZL, <(equals_fail * 2)
    ldi ZH, >(equals_fail * 2)
    rjmp uart_send_str    ;Send "=FAIL"

1$:
    ;Send "=OK"
    ldi ZL, <(equals_ok * 2)
    ldi ZH, >(equals_ok * 2)
    rjmp uart_send_str    ;Send "=OK"

.nval ps,.
    .ascii "PS"
    .byte 0

.nval equals_fail,.
    .ascii "=FAIL"
    .byte 0

.nval equals_ok,.
    .ascii "=OK"
    .byte 0

gpio_init:
    lds r16, PORTA_base + PORT_DIR_offset
    andi r16, 0b11111001 ;pa2, pa1 = input
    sts PORTA_base + PORT_DIR_offset, r16
    ret

uart_init:
    ;#define F_CPU 1843200
    ;#define USART0_BAUD_RATE(BAUD_RATE) ((float)(F_CPU * 64 / (16 * (float)BAUD_RATE)) + 0.5)
    ;USART0.BAUD = (uint16_t)USART0_BAUD_RATE(9600);
    clr r16
    sts USART0_BAUDL, r16
    ldi r16, 0x03
    sts USART0_BAUDH, r16

  	;USART0.CTRLC = USART_CMODE_ASYNCHRONOUS_gc /* Asynchronous Mode */
  	;	 | USART_CHSIZE_8BIT_gc /* Character size: 8 bit */
  	;	 | USART_PMODE_DISABLED_gc /* No Parity */
  	;	 | USART_SBMODE_1BIT_gc; /* 1 stop bit */
    ldi r16, USART_NORMAL_CMODE_ASYNCHRONOUS_gc | USART_NORMAL_CHSIZE_8BIT_gc | USART_NORMAL_PMODE_DISABLED_gc | USART_NORMAL_SBMODE_1BIT_gc
    sts USART0_CTRLC, r16

    ;PORTA.DIR &= ~PIN7_bm;  // pa7 = rx
    ;PORTA.DIR |= PIN6_bm;   // pa6 = tx
    lds r16, PORTA_base + PORT_DIR_offset
    andi r16, 0b01111111 ;pa7 = rx
    ori  r16, 0b01000000 ;pa6 = tx
    sts PORTA_base + PORT_DIR_offset, r16

    ;USART0.CTRLB |= USART_TXEN_bm | USART_TXEN_bm;
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
1$:
    ret

;Clear the UART error status bits
uart_clear_error:
    lds r16, USART0_RXDATAH
    lds r16, USART0_RXDATAL
    ret

;Check if a byte has been received from the UART
;Sets carry if one is available
uart_has_byte:
    clc
    lds r16, USART0_STATUS
    sbrc r16, USART_RXCIF_bp    ;Skip setting carry if no char received
    sec
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
    ;while (!(USART0.STATUS & USART_DREIF_bm)) {}
    lds r17, USART0_STATUS
    sbrs r17, USART_DREIF_bp
    rjmp uart_send_byte
    ;USART0.TXDATAL = c;
    sts USART0_TXDATAL, r16
    ret

;Send a byte as two hexadecimal digits out the UART
;Destroys R17
uart_send_hex_byte:
    push r16
    lsr r16
    lsr r16
    lsr r16
    lsr r16
    rcall nib2asc
    rcall uart_send_byte
    pop r16
    push r16
    andi r16, 0x0f
    rcall nib2asc
    rcall uart_send_byte
    pop r16
    ret

;Convert lower nibble of R16 to hexadecimal digit in ASCII
nib2asc:
    andi r16,0x0f
    cpi r16,0x0a
    brcc 1$
    ldi r17,'0
    add r16,r17             ;Convert to ASCII '0'-'9'
    ret
1$:
    ldi r17,'7
    add r16,r17             ;Convert to ASCII 'A'-'F'
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
1$: lpm r16, Z+           ;Read byte from string
    cpi r16, 0
    breq 2$               ;Branch if end of string
    rcall uart_send_byte
    rjmp 1$
2$: ret

;Test the flash ROM by computing its checksum and comparing
;it to the one in the last two bytes of the ROM.  If they
;do not match, this routine never returns.
test_rom:
    ldi ZL, <(PROGMEM_START)  ;First address of ROM (low)
    ldi ZH, >(PROGMEM_START)  ;  (high)

    ldi r20, 0x55             ;Initial value of checksum (low)
    ldi r21, 0x55             ;  (high)

1$: lpm r16, Z+               ;Add byte from ROM to checksum
    add r20, r16
    clr r16
    adc r21, r16

    cpi ZL, <(PROGMEM_END-1)  ;Keep going until last address before the
    brne 1$                   ;  the checksum (checksum is the last two
    cpi ZH, >(PROGMEM_END-1)  ;  bytes of the ROM).
    brne 1$

    rcall uart_send_crlf
    rcall uart_send_crlf
    rcall uart_send_crlf
    mov r16,r21               ;checksum high
    rcall uart_send_hex_byte
    mov r16,r20               ;checksum low
    rcall uart_send_hex_byte
    rcall uart_send_crlf

    lpm r16, Z+               ;Read low byte of checksum in ROM
    rcall uart_send_hex_byte
    cp r16, r20               ;Compare with calculated low byte
2$: brne 2$                   ;Loop forever if failed

    lpm r16, Z+               ;Read high byte of checksum in ROM
    rcall uart_send_hex_byte
    cp r16, r21               ;Compare with calculated high byte
3$: brne 3$                   ;Loop forever if failed

    ret                       ;Checksum passed

;Wait 1ms.  Destroy R16,R17
delay_1ms:
    ldi r16, 6
1$:
    ldi r17, 0xc5
2$:
    dec r17 ; Decrement r17
    brne 2$ ; Branch if r17<>0
    dec r16
    brne 1$
    ret
