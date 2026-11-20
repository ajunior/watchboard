#pragma once

#include <Arduino.h>

// Table sizes. Registrations past a limit are ignored. Override with a build
// flag (e.g. -DWATCHBOARD_MAX_WATCH_VARS=24).
#ifndef WATCHBOARD_MAX_DIGITAL_PINS
#define WATCHBOARD_MAX_DIGITAL_PINS 20
#endif
#ifndef WATCHBOARD_MAX_ANALOG_PINS
#define WATCHBOARD_MAX_ANALOG_PINS  8
#endif
#ifndef WATCHBOARD_MAX_WATCH_VARS
#define WATCHBOARD_MAX_WATCH_VARS   16
#endif
#ifndef WATCHBOARD_INTERVAL_MS
#define WATCHBOARD_INTERVAL_MS      100
#endif

struct WBWatchVar {
    const char *key;
    float value;
};

class WatchBoardClass {
public:
    void begin(HardwareSerial &serial, unsigned long baud = 115200);
    void watchDigital(uint8_t pin);
    void watchAnalog(uint8_t pin);
    void watch(const char *key, float value);
    void update();

private:
    void sendHello();
    void sendState();
    void handleCommand(const char *line);
    void printFloat(float v);
    bool isWatchedDigital(uint8_t pin) const;

    HardwareSerial *m_serial = nullptr;
    unsigned long m_lastSend = 0;

    uint8_t m_digitalPins[WATCHBOARD_MAX_DIGITAL_PINS];
    uint8_t m_digitalCount = 0;

    uint8_t m_analogPins[WATCHBOARD_MAX_ANALOG_PINS];
    uint8_t m_analogCount = 0;

    WBWatchVar m_watchVars[WATCHBOARD_MAX_WATCH_VARS];
    uint8_t m_watchCount = 0;

    char m_cmdBuf[64];
    uint8_t m_cmdPos = 0;
    bool m_cmdOverflow = false;
};

extern WatchBoardClass WatchBoard;
