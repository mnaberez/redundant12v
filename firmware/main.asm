;ATtiny212
;1 VCC
;2 PA6 TX -> MAX232CPE  T1IN 11 -> T1OUT 14 -> DB9 TX 2
;3 PA7 RX <- MAX232CPE R1OUT 12 <-  R1IN 13 <- DB9 RX 3
;4 PA1
;5 PA2
;6 UPDI
;7 EXTCLK
;8 GND    -> DB9 GND 5

    .area code (abs)

    .include "tn212def.asm"

    .org PROGMEM_START
    rjmp reset

    .org PROGMEM_START+INT_VECTORS_SIZE

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

main:
    rcall uart_init

loop:
    rcall uart_chrin
    rcall uart_chrout
    rjmp loop


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


delay_1ms:
    ldi r16, 6
wait2:
    ldi r17, 0xc5
wait:
    dec r17 ; Decrement r17
    brne wait ; Branch if r17<>0
    dec r16
    brne wait2
    ret
