/*
  ======================================================================
  BreadboarD GeniuS Programmable Logic Gate — Firmware v1.0.0
  Date: 2025-09-21

  WHAT THIS DOES
  --------------
  • Programs the BreadboarD Genius programmable logic gate into a universal logic gate
  • Optional SSD1306 OLED shows a D-shaped gate symbol with inputs/outputs.
  • WS2812 LEDs show input rows and outputs; center LED shows family color.
  • Gate family (AND/NAND, OR/NOR, XOR/XNOR, MAJ/MIN, Dual NOT) persists in EEPROM.

  MODES
  -----
  • With OLED connected (detected at boot):
      - Use 3-input logic (rows 1..3).
      - IN_4A acts as a MODE button (short press cycles gate family; saved to EEPROM).
  • Without OLED:
      - Use 4-input logic (rows 1..4); row 4 = IN_4A/B/C.
      - No button; IN_4A remains a normal input pin.

  LED COLOR POLICY
  ----------------
  • GREEN = true for non-inverted outputs (Y).
  • RED   = true for inverted outputs (NAND/NOR/XNOR/NOT).
  • In Dual NOT, both outputs are inverters -> both RED when high.
  
  Gate Identification LED
  • AND/NAND → Green (G=64)
  • OR/NOR → Amber (R=48, G=24)
  • XOR/XNOR → Magenta-ish (R=32, B=48)
  • MAJORITY/MINORITY → Yellow (R=48, G=48)
  • Dual NOT → Cyan-ish (G=32, B=48)

  TIMING / ROBUSTNESS
  -------------------
  • 1-second startup delay before OLED probe (many modules need ~>500 ms).
  • During I²C probe, PB1/PB0 are pulled up internally to fight the 100 kΩ pulldowns.
  • WS2812 updates respect latch timing (ledsShowSafe()).

  TUNE ME QUICKLY
  ----------------
  • Startup delay: see the 1 s loop in setup().
  • Center LED colors per family: setCenterColorByGate().
  • OLED layout (left/right shift, labels): renderOLED() constants (x0/x1/...).
  • Debounce/read stability: readStable() (3 samples @ 80 µs spacing now).
  • Gate families: enum GateFamily and the switch statements in loop().

  HARDWARE EXPECTATIONS
  ---------------------
  • BreadboarD GeniuS Logic Gate Module V2
  • WS2812 chain (7 pixels) on PA4.
  • Optional SSD1306 128x64 I2C @ 0x3C (or 0x3D).
  • UPDI programmer (CH340, part of the main storage case) to flash the 1616.

  LICENSE
  -------
  This project is licensed under the MIT License - see the LICENSE file for details.

  ======================================================================
*/

#define FW_VERSION   "1.0.0"
#define FW_BUILDDATE "2025-09-21"

#include <tinyNeoPixel.h>
#include <EEPROM.h>
#include <avr/pgmspace.h>
#include <string.h>

// ========================= Pin aliases =========================
// These aliases map MCU pins to the board’s labeled rows/IO.
// If you change the PCB, update these defines, and the rest should “just work”.

#define IN_1A PIN_PA1
#define IN_1B PIN_PA2
#define IN_1C PIN_PA3

#define IN_2A PIN_PA5
#define IN_2B PIN_PA6

#define IN_3A PIN_PA7
#define IN_3B PIN_PB5

#define IN_4A PIN_PB4   // Becomes MODE button if OLED is detected
#define IN_4B PIN_PB1   // SDA when OLED present, otherwise row-4 input
#define IN_4C PIN_PB0   // SCL when OLED present, otherwise row-4 input

// Output buses: Three duplicate pins per output so you can header out conveniently.
// O1* = Y (non-inverted), O2* = /Y (inverted) OR Y2 in Dual NOT (also inverted flavor).
#define O1A PIN_PB2
#define O1B PIN_PC2
#define O1C PIN_PC3

#define O2A PIN_PB3
#define O2B PIN_PC0
#define O2C PIN_PC1

// =========================
// Factory default gate family
// Change this value to select which gate type new devices boot into
// (used if EEPROM has no valid saved gate yet).
// Options: GF_ANDNAND, GF_ORNOR, GF_XORXNOR, GF_MAJMIN, GF_DUALNOT
// =========================
#define FACTORY_DEFAULT_GATE GF_ORNOR   // <--- user can change here

// ========================= WS2812 LEDs =========================
// 7 pixels total: 0..3 inputs, 4 center (family color), 5=Y, 6=/Y
#define LED_PIN   PIN_PA4
#define LED_COUNT 7
tinyNeoPixel leds(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

enum { LED_IN1=0, LED_IN2=1, LED_IN3=2, LED_IN4=3, LED_CENTER=4, LED_Y=5, LED_YBAR=6 };

// ========================= Gate families =========================
// To add another family, extend this enum AND update both switch() trees in loop().
enum GateFamily : uint8_t { GF_ANDNAND=0, GF_ORNOR, GF_XORXNOR, GF_MAJMIN, GF_DUALNOT, GF__COUNT };

// EEPROM storage locations (expand if you save more state later)
#define EE_GATE_FAMILY 0

// ========================= I2C (bit-banged) =========================
// We roll our own to ensure the lines can double as inputs when no OLED is present.
#define SDA_PIN IN_4B
#define SCL_PIN IN_4C

static bool    g_hasOLED  = false; // set true after successful probe
static uint8_t g_oledAddr = 0x3C;  // default, 0x3D as fallback
static uint8_t g_gateFamily = FACTORY_DEFAULT_GATE;

// ========================= Input reading helpers =========================

// Read a pin as a boolean. Separated out so you can add inversion if needed.
static inline bool readPinLogical(uint8_t pin) { return digitalRead(pin); }

// Take 3 quick samples with small spacing to avoid single-sample glitches.
// • If you want stronger debounce, increase samples or spacing.
// • If your edges are slow and you care about speed, *reduce* spacing.
static inline bool readStable(uint8_t pin) {
  uint8_t s = 0;
  s += readPinLogical(pin);
  delayMicroseconds(80);
  s += readPinLogical(pin);
  delayMicroseconds(80);
  s += readPinLogical(pin);
  return s >= 2; // majority vote (2/3)
}

// OR a small set of pins to build a “row” (any asserted pin makes the row true).
static inline bool rowOR_arr(const uint8_t* pins, uint8_t n) {
  for (uint8_t i = 0; i < n; ++i) {
    if (readStable(pins[i])) return true;
  }
  return false;
}

// ========================= Output + LED helpers =========================

// Drive the three pins of a bus in one call (keeps them coherent).
static inline void setBus(uint8_t p1, uint8_t p2, uint8_t p3, bool val) {
  digitalWrite(p1, val);
  digitalWrite(p2, val);
  digitalWrite(p3, val);
}

// WS2812 requires a ~50 µs latch between updates. This enforces a minimum gap.
// If you push more pixels, increase the guard a touch.
static inline void ledsShowSafe() {
  static uint32_t last = 0;
  uint32_t now = micros();
  if ((uint32_t)(now - last) < 300) {               // 300 µs is conservative & safe
    delayMicroseconds(300 - (now - last));
  }
  leds.show();
  last = micros();
}

// Family color for the center LED (steady after boot)
// Tweak colors here if you want a different palette.
static inline void setCenterColorByGate(uint8_t gf){
  uint8_t r=0,g=0,b=0;
  switch(gf){
    case GF_ANDNAND: g=64; break;          // green
    case GF_ORNOR:   r=48; g=24; break;    // amber
    case GF_XORXNOR: r=32; b=48; break;    // magenta-ish
    case GF_MAJMIN:  r=48; g=48; break;    // yellow
    case GF_DUALNOT: g=32; b=48; break;    // cyan-ish
  }
  leds.setPixelColor(LED_CENTER, leds.Color(r,g,b));
}

// Input LEDs are dim green when active to keep current modest.
static inline void showInputLED(uint8_t idx,bool on){
  leds.setPixelColor(idx, on ? leds.Color(0, 48, 0) : 0);
}

// ========================= Bit-bang I2C (SSD1306) =========================
// If SSD1306 probe fails, SDA/SCL revert to INPUT so they can be used as logic inputs.

static inline void i2c_delay() { delayMicroseconds(8); } // ~100 kHz-ish with our toggles

// Open-drain emulation: INPUT_PULLUP for High (let line float up), OUTPUT-LOW for Low.
static inline void sdaHigh() { pinMode(SDA_PIN, INPUT_PULLUP); }
static inline void sdaLow()  { pinMode(SDA_PIN, OUTPUT); digitalWrite(SDA_PIN, LOW); }
static inline void sclHigh() { pinMode(SCL_PIN, INPUT_PULLUP); }
static inline void sclLow()  { pinMode(SCL_PIN, OUTPUT); digitalWrite(SCL_PIN, LOW); }
static inline bool readSDA() { return digitalRead(SDA_PIN); }

static void i2c_start() { sdaHigh(); sclHigh(); i2c_delay(); sdaLow(); i2c_delay(); sclLow(); i2c_delay(); }
static void i2c_stop()  { sdaLow(); i2c_delay(); sclHigh(); i2c_delay(); sdaHigh(); i2c_delay(); }

// Returns true if slave ACKed (pulls SDA low on 9th clock)
static bool i2c_write(uint8_t b) {
  for (uint8_t i = 0; i < 8; ++i) {
    if (b & 0x80) sdaHigh(); else sdaLow();
    i2c_delay();
    sclHigh(); i2c_delay();
    sclLow();  i2c_delay();
    b <<= 1;
  }
  sdaHigh(); i2c_delay();    // release for ACK bit
  sclHigh(); i2c_delay();
  bool ack = !readSDA();
  sclLow();  i2c_delay();
  return ack;
}

// Try both common SSD1306 addresses. If none ACK, release pins for logic input use.
static bool probeOLED() {
  sdaHigh();
  sclHigh();
  bool found = false;
  const uint8_t addrs[2] = { 0x3C, 0x3D };
  for (uint8_t i = 0; i < 2; ++i) {
    i2c_start();
    bool ok = i2c_write((addrs[i] << 1) | 0); // write bit
    i2c_stop();
    if (ok) { g_oledAddr = addrs[i]; found = true; break; }
  }
  if (!found) {
    // IMPORTANT: return lines to high-impedance so they can be used as inputs.
    pinMode(SDA_PIN, INPUT);
    pinMode(SCL_PIN, INPUT);
  }
  return found;
}

// ========================= Minimal SSD1306 driver =========================
// Framebuffer is 128x64 / 8 = 1024 bytes. We blast full buffer on flush (simple & robust).

static uint8_t oledFB[1024];

static void oled_cmd(uint8_t c) { i2c_start(); i2c_write((g_oledAddr<<1)|0); i2c_write(0x00); i2c_write(c); i2c_stop(); }

// Basic init sequence (horizontal addressing)
static void oled_begin(){
  oled_cmd(0xAE);                       // display off
  oled_cmd(0x20); oled_cmd(0x00);       // horizontal addressing mode
  oled_cmd(0x40);                       // set display start line
  oled_cmd(0xA1);                       // segment remap (mirror X)
  oled_cmd(0xC8);                       // COM scan direction (mirror Y)
  oled_cmd(0x81); oled_cmd(0x7F);       // contrast
  oled_cmd(0xA4);                       // resume to RAM content
  oled_cmd(0xA6);                       // normal (not inverted)
  oled_cmd(0xD5); oled_cmd(0x80);       // clock divide
  oled_cmd(0xD9); oled_cmd(0xF1);       // pre-charge
  oled_cmd(0xDA); oled_cmd(0x12);       // COM pins
  oled_cmd(0xDB); oled_cmd(0x40);       // VCOM detect
  oled_cmd(0x8D); oled_cmd(0x14);       // charge pump on
  oled_cmd(0xAF);                       // display on
}

static void oled_clear(){ memset(oledFB,0,sizeof(oledFB)); }

static void oled_flush(){
  oled_cmd(0x21); oled_cmd(0); oled_cmd(127); // columns
  oled_cmd(0x22); oled_cmd(0); oled_cmd(7);   // pages
  i2c_start(); i2c_write((g_oledAddr<<1)|0); i2c_write(0x40);
  for (uint16_t i=0;i<1024;i++) i2c_write(oledFB[i]);
  i2c_stop();
}

static inline void oled_pixel(uint8_t x,uint8_t y,bool on){
  if(x>127||y>63) return;
  uint16_t i=(y>>3)*128 + x;
  uint8_t  m=1<<(y&7);
  if(on) oledFB[i]|=m; else oledFB[i]&=~m;
}

// Simple line primitives (slow-but-simple: per-pixel loop)
static void oled_hline(uint8_t x0,uint8_t x1,uint8_t y,bool on){
  if(x1<x0) {uint8_t t=x0;x0=x1;x1=t;}
  for(uint8_t x=x0;x<=x1;x++) oled_pixel(x,y,on);
}
static void oled_vline(uint8_t x,uint8_t y0,uint8_t y1,bool on){
  if(y1<y0){uint8_t t=y0;y0=y1;y1=t;}
  for(uint8_t y=y0;y<=y1;y++) oled_pixel(x,y,on);
}

// ========================= 5x7 font (subset) =========================
// Add missing characters here as needed. Each glyph is 5 columns x 7 rows (LSB = top).
struct G5x7 { char c; uint8_t col[5]; };
static const G5x7 FONT_5x7[] PROGMEM = {
  {' ',{0,0,0,0,0}}, {'/',{0x02,0x04,0x08,0x10,0x20}},
  {'0',{0x3E,0x51,0x49,0x45,0x3E}}, {'1',{0x00,0x42,0x7F,0x40,0x00}},
  {'A',{0x7E,0x11,0x11,0x11,0x7E}}, {'D',{0x7F,0x41,0x41,0x22,0x1C}},
  {'I',{0x00,0x41,0x7F,0x41,0x00}}, {'J',{0x20,0x40,0x41,0x3F,0x01}},
  {'M',{0x7F,0x04,0x18,0x04,0x7F}}, {'N',{0x7F,0x08,0x10,0x20,0x7F}},
  {'O',{0x3E,0x41,0x41,0x41,0x3E}}, {'R',{0x7F,0x09,0x19,0x29,0x46}},
  {'T',{0x01,0x01,0x7F,0x01,0x01}}, {'X',{0x63,0x14,0x08,0x14,0x63}},
  {'Y',{0x00,0x42,0x7F,0x40,0x00}}
};

// Draw text scaled by k (k=2 for labels inside the gate). Top-left at (x,y).
static void text57_scaled(uint8_t x, uint8_t y, const char* s, uint8_t k){
  for (; *s; s++){
    char ch = *s; const uint8_t* g = 0; uint8_t i;
    for (i=0;i<sizeof(FONT_5x7)/sizeof(FONT_5x7[0]);i++){
      if (pgm_read_byte(&FONT_5x7[i].c)==ch){ g = FONT_5x7[i].col; break; }
    }
    if (!g){ x += 6*k; continue; } // unknown char: skip width
    for (uint8_t cx=0; cx<5; cx++){
      uint8_t col = pgm_read_byte(&g[cx]);
      for (uint8_t ry=0; ry<7; ry++){
        if (col & (1<<ry)){
          for (uint8_t dx=0; dx<k; dx++)
            for (uint8_t dy=0; dy<k; dy++)
              oled_pixel(x + cx*k + dx, y + ry*k + dy, true);
        }
      }
    }
    x += 6*k; // 5px glyph + 1px space, scaled
  }
}

// ========================= Gate drawing on OLED =========================

// Draw a D-shaped gate body between (x0,y0) and (x1,y1).
// If you want a wider/shorter body, tweak the loop that draws the curved end.
static void drawDGateBody(uint8_t x0,uint8_t y0,uint8_t x1,uint8_t y1){
  oled_hline(x0,x1-8,y0,true);
  oled_hline(x0,x1-8,y1,true);
  oled_vline(x0,y0,y1,true);
  for(uint8_t i=0;i<14;i++){ // crude curve: a stack of short verticals
    oled_vline(x1-8+i, y0+3+i/3, y1-3-i/3, true);
  }
}

// Helper to draw a single-bit "0/1" at (x,y)
static inline void drawBit(uint8_t x,uint8_t y,bool v){
  if(v) text57_scaled(x,y,"1",1); else text57_scaled(x,y,"0",1);
}

// Layout + labels. Adjust x0/x1 (and offsets) if you want to nudge things.
// In Dual NOT mode, only two input legs are drawn, aligned with outputs.
static void renderOLED(uint8_t gf, bool in1, bool in2, bool in3, bool /*in4_unused*/, bool Y, bool Yb){
  oled_clear();

  // --- Main geometry (nudge these to shift the whole drawing)
  const uint8_t x0 = 30;   // gate left edge
  const uint8_t x1 = 98;   // gate right edge
  const uint8_t y0 = 10;   // top line
  const uint8_t y1 = 54;   // bottom line

  drawDGateBody(x0, y0, x1, y1);

  // --- 4-char gate labels (padded with spaces), nudged left
  const char* top="    ";
  const char* bot="    ";
  switch(gf){
    case GF_ANDNAND: top = "AND "; bot = "NAND"; break;
    case GF_ORNOR:   top = "OR  "; bot = "NOR "; break;
    case GF_XORXNOR: top = "XOR "; bot = "XNOR"; break;
    case GF_MAJMIN:  top = "MAJ "; bot = "MIN "; break;
    case GF_DUALNOT: top = "NOT "; bot = "NOT "; break;
  }
  text57_scaled(x0 + 8, 18, top, 2);  // move left/right by changing +8
  text57_scaled(x0 + 8, 36, bot, 2);

  // --- Outputs (right side). Keep these < 128 to stay on-screen.
  const uint8_t oy1 = 26, oy2 = 38;
  const uint8_t outLineEnd = x1 + 12; // line length
  const uint8_t outLblX    = x1 + 14; // label position
  const uint8_t outBitX    = x1 + 20; // bit position ("0/1")

  oled_hline(x1, outLineEnd, oy1, true);
  oled_hline(x1, outLineEnd, oy2, true);

  if (gf == GF_DUALNOT) {
    text57_scaled(outLblX, oy1-2, "Y1", 1);
    text57_scaled(outLblX, oy2-2, "Y2", 1);
  } else {
    text57_scaled(outLblX, oy1-2, "Y",  1);
    text57_scaled(outLblX, oy2-2, "/Y", 1);
  }
  drawBit(outBitX, oy1-2, Y);
  drawBit(outBitX, oy2-2, Yb);

  // --- Inputs (left side)
  const uint8_t inStart = 14;           // where the legs begin
  const uint8_t inEnd   = x0 - 3;       // stop just before gate body
  const uint8_t bitX    = inEnd - 16;   // "0/1" indicator left of line end (avoid overlap)

  if (gf == GF_DUALNOT) {
    // Only two legs, aligned horizontally with outputs
    const uint8_t iy2[2] = { oy1, oy2 };
    for (uint8_t k=0; k<2; k++) oled_hline(inStart, inEnd, iy2[k], true);
    drawBit(bitX, oy1-3, in1);
    drawBit(bitX, oy2-3, in2);
  } else {
    // Standard 3-input layout
    const uint8_t iy3[3] = { 18, 32, 46 };
    for (uint8_t k=0; k<3; k++) oled_hline(inStart, inEnd, iy3[k], true);
    drawBit(bitX, iy3[0]-3, in1);
    drawBit(bitX, iy3[1]-3, in2);
    drawBit(bitX, iy3[2]-3, in3);
  }

  oled_flush();
}

// ========================= Logic helpers for 4-input mode =========================
// These are factored so you can swap in different logic later if you want (e.g. threshold k-of-n).
static inline bool evalY_AND(bool a,bool b,bool c,bool d){ return a & b & c & d; }
static inline bool evalY_OR (bool a,bool b,bool c,bool d){ return a | b | c | d; }
static inline bool evalY_XOR(bool a,bool b,bool c,bool d){ return (a ^ b ^ c ^ d); }
static inline bool evalY_MAJ(bool a,bool b,bool c,bool d){ uint8_t s=a+b+c+d; return s >= 3; } // majority of 4

// ========================= EEPROM helpers =========================

static inline void loadSettings(){
  uint8_t v = EEPROM.read(EE_GATE_FAMILY);
	if (v >= GF__COUNT) v = FACTORY_DEFAULT_GATE;
  g_gateFamily = v;
}

static inline void saveSettings(){
  EEPROM.update(EE_GATE_FAMILY, g_gateFamily);
}

// ========================= Setup =========================

void setup() {
  // Inputs are plain INPUT (external 100 kΩ pulldowns take care of idle=LOW).
  pinMode(IN_1A, INPUT); pinMode(IN_1B, INPUT); pinMode(IN_1C, INPUT);
  pinMode(IN_2A, INPUT); pinMode(IN_2B, INPUT);
  pinMode(IN_3A, INPUT); pinMode(IN_3B, INPUT);
  pinMode(IN_4A, INPUT); pinMode(IN_4B, INPUT); pinMode(IN_4C, INPUT);

  // Outputs
  pinMode(O1A, OUTPUT); pinMode(O1B, OUTPUT); pinMode(O1C, OUTPUT);
  pinMode(O2A, OUTPUT); pinMode(O2B, OUTPUT); pinMode(O2C, OUTPUT);

  // WS2812 init
  leds.begin();
  leds.clear();
  ledsShowSafe();

  // ----- 1 s startup animation -----
  // Purpose: give OLED modules time to power up; also “I’m alive” indicator.
  // Change 1000 below to shorten/lengthen; change +200 step to alter color dwell.
  uint32_t t0 = millis();
  while (millis() - t0 < 1000) {
    uint8_t phase = ((millis() - t0) / 200) % 5; // five families ~200ms each
    setCenterColorByGate(phase);
    ledsShowSafe();
    delay(10);
  }

  // Restore last family (defaults to AND/NAND on first boot)
  loadSettings();

  // Probe OLED after the wait (using pull-ups on I2C lines)
  g_hasOLED = probeOLED();
  if (g_hasOLED) {
    oled_begin();
  }
}

// ========================= Main loop =========================

void loop() {
  // ----- Read inputs and aggregate rows -----
  // Rows: OR across pins in that row (any active pin makes that row=1).
  const uint8_t row1[] = {IN_1A, IN_1B, IN_1C}; bool in1 = rowOR_arr(row1, 3);
  const uint8_t row2[] = {IN_2A, IN_2B};        bool in2 = rowOR_arr(row2, 2);
  const uint8_t row3[] = {IN_3A, IN_3B};        bool in3 = rowOR_arr(row3, 2);
  bool in4 = false;

  if (!g_hasOLED) {
    // Only use row-4 when OLED is NOT present (pins are free).
    const uint8_t row4[] = {IN_4A, IN_4B, IN_4C};
    in4 = rowOR_arr(row4, 3);
  }

  // ----- Mode button (only when OLED present) -----
  // IN_4A acts as a simple mode-cycle button (edge detect).
  static bool lastBtn = false;
  if (g_hasOLED) {
    bool btn = readStable(IN_4A);
    if (btn && !lastBtn) {
      g_gateFamily = (g_gateFamily + 1) % GF__COUNT;
      saveSettings(); // persists across power cycles
    }
    lastBtn = btn;
  }

  // ----- Evaluate logic -----
  // Two branches: 3-input mode (OLED present) vs. 4-input mode (no OLED).
  bool Y=false, Yb=false;
  if (g_hasOLED) {
    // 3-input: rows 1..3 only
    bool a=in1, b=in2, c=in3;
    switch (g_gateFamily) {
      case GF_ANDNAND: Y = (a & b & c);     Yb = !Y; break;
      case GF_ORNOR:   Y = (a | b | c);     Yb = !Y; break;
      case GF_XORXNOR: Y = (a ^ b ^ c);     Yb = !Y; break;
      case GF_MAJMIN:  Y = ((a+b+c) >= 2);  Yb = !Y; break; // majority of 3
      case GF_DUALNOT: Y = !b;              Yb = !c; break; // two independent NOTs on rows 1 and 2
    }
  } else {
    // 4-input: rows 1..4
    bool a=in1, b=in2, c=in3, d=in4;
    switch (g_gateFamily) {
      case GF_ANDNAND: Y = evalY_AND(a,b,c,d);  Yb = !Y; break;
      case GF_ORNOR:   Y = evalY_OR(a,b,c,d);   Yb = !Y; break;
      case GF_XORXNOR: Y = evalY_XOR(a,b,c,d);  Yb = !Y; break;
      case GF_MAJMIN:  Y = evalY_MAJ(a,b,c,d);  Yb = !Y; break; // majority of 4 (>=3)
      case GF_DUALNOT: Y = !b;                  Yb = !c; break; // two independent NOTs on rows 1 and 2
    }
  }

  // ----- Drive output buses -----
  setBus(O1A, O1B, O1C, Y);
  setBus(O2A, O2B, O2C, Yb);

  // ----- Update LEDs -----
  showInputLED(LED_IN1, in1);
  showInputLED(LED_IN2, in2);
  showInputLED(LED_IN3, in3);
  if (!g_hasOLED) showInputLED(LED_IN4, in4); else leds.setPixelColor(LED_IN4, 0);

  if (g_gateFamily == GF_DUALNOT) {
    // Policy: NOT outputs are inverted functions -> RED when high (both)
    leds.setPixelColor(LED_Y,    Y  ? leds.Color(64, 0, 0) : 0);
    leds.setPixelColor(LED_YBAR, Yb ? leds.Color(64, 0, 0) : 0);
  } else {
    // Normal paired outputs: Y green, /Y red
    leds.setPixelColor(LED_Y,    Y  ? leds.Color(0, 64, 0) : 0);
    leds.setPixelColor(LED_YBAR, Yb ? leds.Color(64, 0, 0) : 0);
  }

  // Center LED = family color (steady after boot)
  setCenterColorByGate(g_gateFamily);

  // ----- OLED UI (if present) -----
  if (g_hasOLED) {
    renderOLED(g_gateFamily, in1,in2,in3,false, Y, Yb);
  }

  // ----- Push pixels (respecting latch time) -----
  ledsShowSafe();
}

/* ========================= Developer Notes =========================

1) Faster/slower input feel?
   - readStable() currently samples 3x with 80 µs spacing (total ~160 µs).
   - Reduce spacing to ~20–40 µs for snappier response; increase for noise immunity.
   - Or change majority threshold (e.g., 2-of-3) to be stricter/looser.

2) OLED tweaks:
   - Move the gate: change x0/x1 in renderOLED().
   - Longer/shorter legs: inStart, inEnd.
   - Move labels: the x0 + 8 offsets for text57_scaled().
   - Want bigger labels? Change the scale factor from 2 to 3 (and re-space).

3) Add a new gate family:
   - Append to GateFamily enum; bump GF__COUNT.
   - Add color in setCenterColorByGate().
   - Add label text in renderOLED()’s switch.
   - Add logic in both switch blocks in loop() (3-input and 4-input paths).

4) WS2812 current + brightness:
   - We drive modest intensities (64 max channel) to keep current reasonable.
   - If you raise these, ensure your 5 V rail + decoupling can handle it.

5) Startup delay:
   - 1 s is safe for common SSD1306 modules. If your OLEDs are faster,
     shorten the loop in setup().

6) EEPROM wear:
   - We only write when family changes (EEPROM.update avoids redundant writes).

==================================================================== */
