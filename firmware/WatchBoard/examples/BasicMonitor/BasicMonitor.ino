#include <WatchBoard.h>

// Pins to monitor — adjust to your board. ESP32 and ESP8266 GPIO 6–11 drive
// the flash chip and must be left alone, and their analog pins differ from
// the Uno's (ESP8266 has only A0; classic ESP32 has no A1/A2).
#if defined(ARDUINO_ARCH_ESP32)
const uint8_t digitalPins[] = {4, 5, 16, 17, 18, 19};
const uint8_t analogPins[]  = {A0, A3, A4};
#elif defined(ARDUINO_ARCH_ESP8266)
const uint8_t digitalPins[] = {4, 5, 12, 13, 14};
const uint8_t analogPins[]  = {A0};
#else
const uint8_t digitalPins[] = {2, 3, 4, 5, 6, 7};
const uint8_t analogPins[]  = {A0, A1, A2};
#endif

float demoCounter = 0;

void setup() {
    for (uint8_t pin : digitalPins) {
        pinMode(pin, INPUT);
        WatchBoard.watchDigital(pin);
    }
    for (uint8_t pin : analogPins) {
        WatchBoard.watchAnalog(pin);
    }

#ifdef LED_BUILTIN
    // An OUTPUT pin gets a switch in the app that drives it from the PC.
    pinMode(LED_BUILTIN, OUTPUT);
    WatchBoard.watchDigital(LED_BUILTIN);
#endif

    WatchBoard.begin(Serial);
}

void loop() {
    demoCounter += 0.1f;
    WatchBoard.watch("counter", demoCounter);
    WatchBoard.watch("a0_raw", (float)analogRead(A0));

    WatchBoard.update();
}
