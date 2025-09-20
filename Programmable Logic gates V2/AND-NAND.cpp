#include <tinyNeoPixel.h>

// =========================
// ATtiny1616 Programmable Logic Gate — Shipping Preset: 4-Input AND
// External pulldowns fitted on all inputs. No internal pull-ups used.
// LEDs: [0]=In1, [1]=In2, [2]=In3, [3]=In4, [4]=Center/Status, [5]=AND, [6]=NAND
// =========================

// ---- Pin aliases (from your map, corrected)
#define IN_1A PIN_PA1
#define IN_1B PIN_PA2
#define IN_1C PIN_PA3

#define IN_2A PIN_PA5
#define IN_2B PIN_PA6

#define IN_3A PIN_PA7
#define IN_3B PIN_PB5

#define IN_4A PIN_PB4
#define IN_4B PIN_PB1
#define IN_4C PIN_PB0

// AND bus (O1*)
#define O1A PIN_PB2   // AND
#define O1B PIN_PC2
#define O1C PIN_PC3

// NAND bus (O2*)
#define O2A PIN_PB3   // NAND
#define O2B PIN_PC0
#define O2C PIN_PC1

// WS2812
#define LED_PIN   PIN_PA4
#define LED_COUNT 7

tinyNeoPixel leds(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

enum { LED_IN1=0, LED_IN2=1, LED_IN3=2, LED_IN4=3, LED_CENTER=4, LED_AND=5, LED_NAND=6 };

// ---- Helpers (no pullups; external pulldowns installed)
static inline bool readPinLogical(uint8_t pin) { return digitalRead(pin); }

// Simple majority-of-3 sampler to deglitch bouncy jumpers
static inline bool readStable(uint8_t pin) {
  uint8_t s = 0;
  s += readPinLogical(pin);
  delayMicroseconds(80);
  s += readPinLogical(pin);
  delayMicroseconds(80);
  s += readPinLogical(pin);
  return s >= 2; // majority
}

static inline bool rowOR_arr(const uint8_t* pins, uint8_t n) {
  for (uint8_t i = 0; i < n; ++i) {
    if (readStable(pins[i])) return true;
  }
  return false;
}

static inline void setBus(uint8_t p1, uint8_t p2, uint8_t p3, bool val) {
  digitalWrite(p1, val);
  digitalWrite(p2, val);
  digitalWrite(p3, val);
}

static inline void showInputLed(uint8_t idx, bool on) {
  // dim to keep current low; green for asserted
  leds.setPixelColor(idx, on ? leds.Color(0, 48, 0) : 0);
}

// Guard WS2812 latch time (some batches ~250-300us)
static inline void ledsShowSafe() {
  static uint32_t last = 0;
  uint32_t now = micros();
  if ((uint32_t)(now - last) < 300) {
    delayMicroseconds(300 - (now - last));
  }
  leds.show();
  last = micros();
}

void setup() {
  // Inputs: plain INPUT (external pulldowns provide bias)
  pinMode(IN_1A, INPUT); pinMode(IN_1B, INPUT); pinMode(IN_1C, INPUT);
  pinMode(IN_2A, INPUT); pinMode(IN_2B, INPUT);
  pinMode(IN_3A, INPUT); pinMode(IN_3B, INPUT);
  pinMode(IN_4A, INPUT); pinMode(IN_4B, INPUT); pinMode(IN_4C, INPUT);

  // Outputs
  pinMode(O1A, OUTPUT); pinMode(O1B, OUTPUT); pinMode(O1C, OUTPUT);
  pinMode(O2A, OUTPUT); pinMode(O2B, OUTPUT); pinMode(O2C, OUTPUT);

  // LEDs
  leds.begin();
  leds.clear();
  ledsShowSafe();
}

void loop() {
  // Row aggregation (row = OR of that row's pins)
  const uint8_t row1[] = {IN_1A, IN_1B, IN_1C};
  bool in1 = rowOR_arr(row1, 3);
  const uint8_t row2[] = {IN_2A, IN_2B};
  bool in2 = rowOR_arr(row2, 2);
  const uint8_t row3[] = {IN_3A, IN_3B};
  bool in3 = rowOR_arr(row3, 2);
  const uint8_t row4[] = {IN_4A, IN_4B, IN_4C};
  bool in4 = rowOR_arr(row4, 3);

  bool andOut  = (in1 && in2 && in3 && in4);
  bool nandOut = !andOut;

  // Drive buses
  setBus(O1A, O1B, O1C, andOut);
  setBus(O2A, O2B, O2C, nandOut);

  // LEDs: inputs on 0..3, center 4 heartbeat, AND=5, NAND=6
  showInputLed(LED_IN1, in1);
  showInputLed(LED_IN2, in2);
  showInputLed(LED_IN3, in3);
  showInputLed(LED_IN4, in4);

  // LED5 AND, LED6 NAND
  leds.setPixelColor(LED_AND,  andOut  ? leds.Color(0, 64, 0) : 0);
  leds.setPixelColor(LED_NAND, nandOut ? leds.Color(64, 0, 0) : 0);

  // LED4 heartbeat (slow fade)
  static uint16_t t = 0; t++;
  uint8_t hb = ((t >> 4) & 0x3F); // slowed down by shifting
  leds.setPixelColor(LED_CENTER, leds.Color(0, hb, hb)); // aqua-ish pulse

  ledsShowSafe();
}
