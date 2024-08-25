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
The kit comes with 22 Logic gate units(ATTiny1616) and 1 Binary/Decimal Counter(ATMega4809)
The gates are preconfigured when delivered in the following combination

7 x AND/NAND Gates
6 x OR/NOR Gates
3 x XOR/XNOR Gates
3 x Dual NOT Gates
3 x Majority/Minority Gates

This means the kit is useful immediately out of the box and can be plugged straight into a breadboard and used like traditional logic gates, you can However change what each gate is, and each gate has a small cap that shows what the gate is programmed for, an additional 18 caps of each logic type come with the kits so you can change the symbol once you reprogram the gate, this means you can use all the gates as AND/NAND for example.

In essence, you get 22 breadboard pluggable MCUs with 5 x input/output ports with 5 port indicators and 1 gate indicator(ATTiny1616). And 1 breadboard pluggable MCU with 23 input/output ports with 23 port indicators and 1 gate indicator(ATMega4809). you can program the device to be or do whatever you can imagine, so you are not limited to gates. the purpose of this git repository is to keep hold of and make available the basic programs required to reset your gate to the desired gate.

## MCU inputs/outputs
### ATTiny1616 Digital Pin Layout:
0 = INPUT 3
1 = INPUT LED 1
2 = INPUT LED 2
3 = INPUT LED 3
5 = GATE LED
6 = OUTPUT LED 2
7 = OUTPUT LED 1
8 = OUTPUT 2
9 = OUTPUT 1
15 = INPUT 2
16 = INPUT 1

### ATTiny1616 direct Manipulation port layout:
PORTA 
2 = Input 1
3 = Input 2
4 = Input 3
5 = Input LED 1
6 = Input LED 2
7 = Input LED 3
PORTB
0 = Output 1
1 = Output 2
2 = Output LED 1
3 = Output LED 2
4 = Gate LED

### ATMega4809 Digital Pin Layout
PA5	1 = LEDR1
PA6	2 = CLR
PA7	3 = CK
PB0	4 = ENP
PB1	5 = ENT
PB2	6 = CO
PB3	7 = N/C
PB4	8 = N/C
PB5	9 = N/C
PC0	10 = BO4
PC1	11 = BO3
PC2	12 = BI2
PC3	13 = BI1
VDD	14 = VDD
GND	15 = GND
PC4	16 = BO2
PC5	17 = BO1
PC6	18 = D10
PC7	19 = LEDC2
PD0	20 = D9
PD1	21 = D8
PD2	22 = D7
PD3	23 = D6
PD4	24 = LEDR3
PD5	25 = D5
PD6	26 = D4
PD7	27 = D3
AVDD 28 = VCC
GND	29 = GND
PE0	30 = LEDC3
PE1	31 = LEDR2
PE2	32 = D2
PE3	33 = D1
PF0	34 = N/C
PF1	35 = N/C
PF2	36 = N/C
PF3	37 = N/C
PF4	38 = N/C
PF5	39 = N/C
PF6	40 = LEDC4
UPDI 41 = UPDI
VDD	42 = VDD
GND	43 = GND
PA0	44 = N/C
PA1	45 = N/C
PA2	46 = BI3
PA3	47 = BI4
PA4	48 = LEDC1


## Contributing
Contributions are welcome! Please feel free to submit issues, fix the project, and create pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
You can reach me at [support@breadboardgenius.com](mailto:support@breadboardgenius.com) for any questions or suggestions.




This is a brand new project and even this readme isn't complete, it might not even be correct. please check back for updates.

