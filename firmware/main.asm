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

loop:
    rcall uart_chrin
    cpi r16, '\r            ;received '\r'?
    brne loop               ;no: ignore and wait for next char

    rcall check_supplies

    ;send status like "ps0_ok=OK,ps1_ok=OK\r\n"
    rcall send_ps0_status
    ldi r16, ',
    rcall uart_chrout
    rcall send_ps1_status
    ldi r16, '\r
    rcall uart_chrout
    ldi r16, '\n
    rcall uart_chrout

    rjmp loop

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

send_ps0_status:
    ldi r16, 0
    lds r17, ps0_ok
    rjmp send_ps_status

send_ps1_status:
    ldi r16, 1
    lds r17, ps1_ok
    ;fall through

;Send "PSn=OK" or "PSn=FAIL"
;R16=power supply number (0-1)
;R17=status (0=fail, 1=ok)
send_ps_status:
    push r17            ;push status
    push r16            ;push power supply number

    ldi r16, 'P
    rcall uart_chrout
    ldi r16, 'S
    rcall uart_chrout
    pop r16             ;pop power supply number
    ori r16, 0x30       ;convert to ascii
    rcall uart_chrout
    ldi r16, '=
    rcall uart_chrout

    pop r16             ;pop status
    rcall send_ok_fail  ;send "OK" if 0, else send "FAIL"
    ret

;Send "OK" if R16=1, else send "FAIL"
;Destroys R16
send_ok_fail:
    cpi r16, 1
    breq 1$

    ldi r16, 'F
    rcall uart_chrout
    ldi r16, 'A
    rcall uart_chrout
    ldi r16, 'I
    rcall uart_chrout
    ldi r16, 'L
    rcall uart_chrout
    ret

1$:
    ldi r16, 'O
    rcall uart_chrout
    ldi r16, 'K
    rcall uart_chrout
    ret

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


uart_chrin:
    ;while (!(USART0.STATUS & USART_RXCIF_bm)) {}
    lds r16, USART0_STATUS
    sbrs r16, USART_RXCIF_bp
    rjmp uart_chrin
    ;return USART0.RXDATAL;
    lds r16, USART0_RXDATAL
    ret


uart_chrout:
    ;while (!(USART0.STATUS & USART_DREIF_bm)) {}
    lds r17, USART0_STATUS
    sbrs r17, USART_DREIF_bp
    rjmp uart_chrout
    ;USART0.TXDATAL = c;
    sts USART0_TXDATAL, r16
    ret


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
