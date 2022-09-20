/*******************************************************************************
 Rue's "is it alive" program for avr processors
  also makes a good skel to build your programs form.
*******************************************************************************/
 
/*

5 PB0   timer 0  1 MHz out     0C0A
6 PB1   
7 PB2  /RESET out
8     (VCC)
4     (GND) 
2 PB3    
3 PB4     
1 PB5 (RESET)   



                            +-----U-----+    
               RESET    PB5 | o         | VCC
               ADC3     PB3 |           | PB2 ADC1 
               ADC2     PB4 |   Tiny13  | PB1 OC0B
                        GND |           | PB0 OC0A
                            +-----------+    


AVR needs to be held in reset from a fresh power cycle to reflash firmware!


*/


#include <avr/io.h>
#include <avr/sleep.h>
#include "avrcommon.h"

#define OUTPUT             1
#define INPUT              0


void Delay(unsigned long delay);
void ConfigTimers( void ) ;


int main (void) {


  // Set clock prescaler: 0 gives full 9.6 MHz from internal oscillator.
  CLKPR = (1 << CLKPCE);
  CLKPR = 0;  

  // set up directions 

  DDRB  = (OUTPUT << PB0 | INPUT << PB1 |OUTPUT << PB2 |INPUT << PB3 |INPUT << PB4 |INPUT << PB5 );
  ClearBit( 2, PORTB ); // establish reset state
 
  OSCCAL -= 0x08;
  ConfigTimers();
  
  Delay(300); // reset delay
    
  
  SetBit  ( 2, PORTB );  // reset out high


  
  sleep_mode();  
    
 
  while(1) {        
    NOP();       // well its not like there is anything else going on to take up the memory
    NOP(); 
    NOP(); 
    NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();    
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); 
    NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();        
  }     
  
}

void ConfigTimers( void ) {

  // timer 0   9.6 MHz in
  // toggle on compare match (COM0A1 = 0, COM0A0 = 1)
  // fast pwm ( WGM02 = 1, WGM01 = 1, WGM00 = 1 )
  // clksrc/1 ( CS02 = 0, CS01 = 0, CS00 = 1 )
  // TOP = 0
  
  
 
  
  TCCR0B = ( 1 << WGM02 );                                                   // WGM02 = 1, CS02 = 0, CS01 = 0, CS00 = 1
  TCCR0A = (( 1 << COM0A0 ) | ( 1 << WGM01 ) | ( 1 << WGM00 ));              // COM0A1 = 0, COM0A0 = 1, WGM01 = 1, WGM00 = 1
  OCR0A  = 3;                                                                // immediate toggle
  TCCR0B |=   ( 1 << CS00 );                                                 // enable
  

}


void Delay(unsigned long delay) {
  unsigned long x;
  for (x = delay; x != 0; x--) {
    asm volatile ("nop"::); 
  }
}













































