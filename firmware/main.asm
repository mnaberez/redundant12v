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

ps0_ok = SRAM_START+0  ;Power Supply 0 ok status (0=fail, 1=ok)
ps1_ok = SRAM_START+1  ;Power Supply 1 ok status (0=fail, 1=ok)

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

    rcall check_supplies
    rcall send_status_line
    rjmp main_loop

error:
    rcall uart_clear_error    ;Clear the UART error
    rjmp main_loop


;Check power supplies 0 and 1
;Store statuses in ps0_ok and ps1_ok
;Blocks for at least 25ms to debounce
;Destroys R16,R17,R18
check_supplies:
    ldi r18, 25             ;Debounce: PORTA must be the same for N readings

1$:
    lds r16, PORTA_IN       ;Read once
    andi r16, 0b00000110    ;PA2=Power Supply 0, PA1=Power Supply 1

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

    ;Set ps0_ok from R16
    lsr r16                 ;Rotate PA1 (Power Supply 1) into bit 0
    andi r16, #1            ;Mask off PA2
    sts ps0_ok,r16          ;Store as Power Supply 0 ok status (0=fail, 1=ok)

    ;Set ps1_ok from R17
    lsr r17                 ;Rotate PA2 (Power Supply 1) into bit 0
    lsr r17
    sts ps1_ok,r17          ;Store as Power Supply 1 ok status (0=fail, 1=ok)
    ret

;Send status like like "PS0=OK,PS1=OK\r\n"
send_status_line:
    ldi r16, 0              ;Supply number
    lds r17, ps0_ok         ;Supply status
    rcall send_ps_status

    ldi r16, ',
    rcall uart_send_byte

    ldi r16, 1              ;Supply number
    lds r17, ps1_ok         ;Supply status
    rcall send_ps_status

    rjmp uart_send_crlf

;Send "PSn=OK" or "PSn=FAIL"
;R16=power supply number (0-1)
;R17=status (0=fail, 1=ok)
send_ps_status:
    push r17              ;Push status
    push r16              ;Push power supply number

    ldi ZL, <(ps * 2)
    ldi ZH, >(ps * 2)
    rcall uart_send_str   ;Send "PS"

    pop r16               ;Pop power supply number
    ori r16, 0x30         ;Convert to ascii
    rcall uart_send_byte

    pop r16               ;Pop status
    cpi r16, 1
    breq 1$               ;Branch if OK

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
1$: lpm r16, Z            ;Read byte from string
    cpi r16, 0
    breq 2$               ;Branch if end of string
    rcall uart_send_byte

    ldi r16, 1            ;Increment to next byte
    add ZL, r16
    clr r16
    adc ZH, r16
    rjmp 1$
2$: ret


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
