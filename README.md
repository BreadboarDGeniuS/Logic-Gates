# BreadboarD GeniuS Logic Gates and Binary Counters
## Built around the ATTiny1616 and ATMega4809 MCU

## Description
This project implements various logic gates (AND/NAND, OR/NOR, XOR/XNOR, Dual NOT, MAJORITY/MINORITY) using the ATTiny1616 microcontroller. The code is designed for educational purposes and to demonstrate the implementation of basic digital logic in embedded systems.
The logic gates will be available to buy on:

TINDIE https://www.tindie.com/stores/breadboardgenius/
ETSY https://breadboardgenius.etsy.com
EBAY https://www.ebay.co.uk/usr/electrode101
AMAZON https://www.amazon.co.uk/stores/BreadboarDGeniuS/page/55A0FDEC-4DBA-4672-864A-B47951250643?ref_=ast_bln

To purchase the gate kits and better support the project it's best to buy on TINDIE as they don't charge any fees. the order they are listed above is from the lowest fees to the highest fees

## Features
- Implements AND/NAND, OR/NOR, XOR/XNOR, NOT, and MAJORITY/MINORITY gates.
- Configurable input pins.
- Easily expandable for additional logic gates.
- Written in C++ for use with ATTiny1616 & ATMega4809 MCU.

## Installation
1. Clone the repository: `git clone https://github.com/BreadBoardGeniuS/logic-gates.git`
2. Open the project in your preferred IDE (e.g., Atmel Studio, VSCode).
3. Compile and upload the code to your ATTiny1616 MCU.

## Usage
The kit comes with 22 Logic gate units(ATTiny1616) and 1 Binary/Decimal Counter(ATMega4809) (Virtualised LS161 and LS145)
The gates are preconfigured when delivered in the following combination

7 x AND/NAND Gates
6 x OR/NOR Gates
3 x XOR/XNOR Gates
3 x Dual NOT Gates
3 x Majority/Minority Gates

This means the kit is useful immediately out of the box and can be plugged straight into a breadboard and used like traditional logic gates, you can However change what each gate is, and each gate has a small cap that shows what the gate is programmed for, an additional 18 caps of each logic type come with the kits so you can change the symbol once you reprogram the gate, this means you can use all the gates as AND/NAND for example.

In essence, you get 22 breadboard pluggable MCUs with 5 x input/output ports with 5 port indicators and 1 gate indicator(ATTiny1616). And 1 breadboard pluggable MCU with 23 input/output ports with 23 port indicators and 1 gate indicator(ATMega4809). you can program the device to be or do whatever you can imagine, so you are not limited to gates. the purpose of this git repository is to keep hold of and make available the basic programs required to reset your gate to the desired gate, and to allow collaboration for more exciting things that the gates can be programmed to do.

## MCU inputs/outputs
### ATTiny1616 Digital Pin Layout:
0 = INPUT 3,

1 = INPUT LED 1,

2 = INPUT LED 2,

3 = INPUT LED 3,

5 = GATE LED,

6 = OUTPUT LED 2,

7 = OUTPUT LED 1,

8 = OUTPUT 2,

9 = OUTPUT 1,

15 = INPUT 2,

16 = INPUT 1,

### ATTiny1616 direct Manipulation port layout:
PORTA 

2 = Input 1 = SDA,

3 = Input 2 = SCL,

4 = Input 3 ,

5 = Input LED 1,

6 = Input LED 2,

7 = Input LED 3,

PORTB

0 = Output 1 = SCL,

1 = Output 2 = SDA,

2 = Output LED 1,

3 = Output LED 2,

4 = Gate LED,

### ATMega4809 Digital Pin Layout

0 = BI4,

1 = LEDR1,

2 = D3.

3 = D4.

4 = CLK,

5 = ENP,

6 = ENT,

7 = RCO,

8 = LEDR2,

9 = LEDR3,

10 = NC,

11 = NC,

12 = NC,

13 = NC,

14 = D10,

15 = D9,

16 = D8,

17 = D7,

18 = BI3,

19 = BI2,

20 = NC,

21 = LEDR4,

22 = LEDC1,

23 = LEDC2,

24 = LEDC3,

25 = LEDC4,

26 = LEDC5,

27 = LEDC6.

28 = NC,

29 = BI1,

30 = BO1,

31 = BO2,

32 = BO3,

33 = BO4,

34 = D2,

35 = D1,

36 = D5,

37 = D6,

38 = NC,

39 = NC,

40 = CLR,

### ATTMega4809 direct Manipulation port layout:
PORTA

PA0 = BI4 = EXTCLK,

PA1 = LEDR1,

PA2 = D3 = TWI = SDA,

PA3 = D4 = TWI = SCL,

PA4 = CLK = MOSI,

PA5 = ENP = MISO,

PA6 = ENP = SCK,

PA7 = RCO = CLKOUT = SS,

PORTB

PB0 = LEDR2,

PB1 = LEDR3,

PB2 = NC,

PB3 = NC,

PB4 = NC,

PB5 = NC,


PORTC

PC0 = D10 = MOSI (3),

PC1 = D9 = MISO (3),

PC2 = D8 = TWI = SCK (3),

PC3 = B7 = TWI = SS (3),

PC4 = BI3,

PC5 = BI2,

PC6 = NC,

PC7 = LEDR4,

PORTD

PD0 = LEDC1,

PD1 = LEDC2,

PD2 = LEDC3,

PD3 = LEDC4,

PD4 = LEDC5,

PD5 = LEDC6,

PD6 = NC,

PD7 = BI1 = VREFA,


PORTE

PE0 =  BO1 = MOSI (3),

PE1 =  BO2 = MISO (3),

PE2 =  BO3 = SCK (3),

PE3 = BO4 = SS (3),

 
PORTF

PF0 = D2 = TOSC1 = TxD,

PF1 = D1 = TOSC2 = RxD,

PF2 = D5 = TWI = XCK,

PF3 = D6 = TWI = XDIR,

PF4 = NC,

PF5 = NC,

PF6 = CLR = RESET,

## Contributing
Contributions are welcome! Please feel free to submit issues, fix the project, and create pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
You can reach me at [support@breadboardgenius.com](mailto:support@breadboardgenius.com) for any questions or suggestions.




This is a brand new project and even this readme isn't complete, it might not even be correct. please check back for updates.

