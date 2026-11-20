#include "WatchBoard.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#if defined(ARDUINO_ARCH_ESP32)
#include "soc/soc.h"
#include "soc/gpio_reg.h"
#endif

WatchBoardClass WatchBoard;

// ── Pin direction ─────────────────────────────────────────────────────────────
// Arduino has no portable "what mode is this pin in?", so read each family's
// direction register. INPUT and INPUT_PULLUP both report as INPUT. On other
// architectures every pin reports as INPUT (the app then shows no switch).
static bool pinIsOutput(uint8_t pin) {
#if defined(__AVR__)
    const uint8_t port = digitalPinToPort(pin);
    if (port == NOT_A_PIN) return false;
    return (*portModeRegister(port) & digitalPinToBitMask(pin)) != 0;
#elif defined(ARDUINO_ARCH_ESP32)
    if (pin < 32) return (REG_READ(GPIO_ENABLE_REG) >> pin) & 1;
  #if defined(GPIO_ENABLE1_REG)
    if (pin < 64) return (REG_READ(GPIO_ENABLE1_REG) >> (pin - 32)) & 1;
  #endif
    return false;
#elif defined(ARDUINO_ARCH_ESP8266)
    if (pin < 16)  return (GPE >> pin) & 1;
    if (pin == 16) return GP16E & 1;
    return false;
#elif defined(ARDUINO_ARCH_SAMD)
    if (pin >= PINS_COUNT) return false;
    const PinDescription &d = g_APinDescription[pin];
    if (d.ulPinType == PIO_NOT_A_PIN) return false;
    return (PORT->Group[d.ulPort].DIR.reg & (1ul << d.ulPin)) != 0;
#else
    (void)pin;
    return false;
#endif
}

// ── Analog pin name ───────────────────────────────────────────────────────────
// The n in "An" for an analog pin, as the app shows it. On AVR, SAMD and
// ESP8266 the A pins are consecutive from A0, and watchAnalog(0) (a channel
// number, which analogRead also accepts) means A0 too. On ESP32 the A names
// don't follow GPIO order (A0 = GPIO36, A4 = GPIO32 …) but they do follow the
// ADC channel (ADC1 → 0–9, ADC2 → 10+), which the core reports per GPIO.
static uint8_t analogIndex(uint8_t pin) {
#if defined(ARDUINO_ARCH_ESP32)
    const int ch = digitalPinToAnalogChannel(pin);
    return ch >= 0 ? (uint8_t)ch : pin;
#else
    return pin >= A0 ? pin - A0 : pin;
#endif
}

void WatchBoardClass::begin(HardwareSerial &serial, unsigned long baud) {
    m_serial = &serial;
    m_serial->begin(baud);
    delay(100); // wait for host to open port
    sendHello();
}

void WatchBoardClass::watchDigital(uint8_t pin) {
    if (m_digitalCount >= WATCHBOARD_MAX_DIGITAL_PINS) return;
    m_digitalPins[m_digitalCount++] = pin;
}

void WatchBoardClass::watchAnalog(uint8_t pin) {
    if (m_analogCount >= WATCHBOARD_MAX_ANALOG_PINS) return;
    m_analogPins[m_analogCount++] = pin;
}

void WatchBoardClass::watch(const char *key, float value) {
    for (uint8_t i = 0; i < m_watchCount; ++i) {
        if (strcmp(m_watchVars[i].key, key) == 0) {
            m_watchVars[i].value = value;
            return;
        }
    }
    if (m_watchCount >= WATCHBOARD_MAX_WATCH_VARS) return;
    m_watchVars[m_watchCount++] = {key, value};
}

bool WatchBoardClass::isWatchedDigital(uint8_t pin) const {
    for (uint8_t i = 0; i < m_digitalCount; ++i)
        if (m_digitalPins[i] == pin) return true;
    return false;
}

void WatchBoardClass::update() {
    if (!m_serial) return;

    // receive commands, one per line; a line too long for the buffer is dropped
    while (m_serial->available()) {
        const char c = (char)m_serial->read();
        if (c == '\n' || c == '\r') {
            if (m_cmdPos > 0 && !m_cmdOverflow) {
                m_cmdBuf[m_cmdPos] = '\0';
                handleCommand(m_cmdBuf);
            }
            m_cmdPos = 0;
            m_cmdOverflow = false;
        } else if (m_cmdPos < sizeof(m_cmdBuf) - 1) {
            m_cmdBuf[m_cmdPos++] = c;
        } else {
            m_cmdOverflow = true;
        }
    }

    // send state periodically
    unsigned long now = millis();
    if (now - m_lastSend >= WATCHBOARD_INTERVAL_MS) {
        m_lastSend = now;
        sendState();
    }
}

void WatchBoardClass::sendHello() {
    if (!m_serial) return;

#if defined(ARDUINO_ARCH_ESP32)
    const char *board = "ESP32";
    int analogBits = 12;
    int analogMax = 4095;
    int cpuMhz = getCpuFrequencyMhz();
    int cores = 2;
    int flashSize = (int)ESP.getFlashChipSize();
    int sketchSize = (int)ESP.getSketchSize();
    const char *resetReason = "";
    switch (esp_reset_reason()) {
        case ESP_RST_POWERON:   resetReason = "Power on";      break;
        case ESP_RST_SW:        resetReason = "Software";      break;
        case ESP_RST_PANIC:     resetReason = "Panic";         break;
        case ESP_RST_INT_WDT:   resetReason = "Int watchdog";  break;
        case ESP_RST_TASK_WDT:  resetReason = "Task watchdog"; break;
        case ESP_RST_WDT:       resetReason = "Watchdog";      break;
        case ESP_RST_DEEPSLEEP: resetReason = "Deep sleep";    break;
        case ESP_RST_BROWNOUT:  resetReason = "Brownout";      break;
        default:                resetReason = "Unknown";       break;
    }
#elif defined(ARDUINO_ARCH_ESP8266)
    const char *board = "ESP8266";
    int analogBits = 10;
    int analogMax = 1023;
    int cpuMhz = ESP.getCpuFreqMHz();
    int cores = 1;
    int flashSize = (int)ESP.getFlashChipSize();
    int sketchSize = (int)ESP.getSketchSize();
    // The String must outlive its c_str(), which snprintf reads below.
    const String resetReasonStr = ESP.getResetReason();
    const char *resetReason = resetReasonStr.c_str();
#elif defined(ARDUINO_ARCH_SAMD)
    const char *board = "SAMD";
    int analogBits = 10;
    int analogMax = 1023;
    int cpuMhz = 48;
    int cores = 1;
    int flashSize = 0;
    int sketchSize = 0;
    const char *resetReason = "";
#else
    const char *board = "Arduino";
    int analogBits = 10;
    int analogMax = 1023;
    int cpuMhz = 16;
    int cores = 1;
    int flashSize = 0;
    int sketchSize = 0;
    const char *resetReason = "";
#endif

    char buf[256];
    snprintf(buf, sizeof(buf),
        "{\"type\":\"hello\",\"board\":\"%s\",\"analogBits\":%d,\"analogMax\":%d"
        ",\"cpuMhz\":%d,\"cores\":%d,\"flashSize\":%d,\"sketchSize\":%d,\"resetReason\":\"%s\"}",
        board, analogBits, analogMax, cpuMhz, cores, flashSize, sketchSize, resetReason);
    m_serial->println(buf);
}

// Two decimals, sign kept, rounded (1.999 → 2.00, -0.5 → -0.50). Done by hand
// because printf's %f is missing or heavy on AVR. Past ±40 million a float has
// no cents left to show, so those print as whole numbers; NaN, infinities and
// anything past ±4 billion go out as JSON null.
void WatchBoardClass::printFloat(float v) {
    Print &out = *m_serial;
    if (isnan(v) || isinf(v) || v >= 4.0e9f || v <= -4.0e9f) {
        out.print(F("null"));
        return;
    }
    const bool negative = v < 0;
    const float mag = negative ? -v : v;

    if (mag >= 4.0e7f) {
        if (negative) out.print('-');
        out.print((unsigned long)(mag + 0.5f));
        return;
    }

    const unsigned long scaled = (unsigned long)(mag * 100.0f + 0.5f);
    const unsigned long whole = scaled / 100;
    const uint8_t frac = (uint8_t)(scaled % 100);
    if (negative && scaled != 0) out.print('-');
    out.print(whole);
    out.print('.');
    if (frac < 10) out.print('0');
    out.print(frac);
}

// Written to the port piece by piece: no message buffer to overflow however
// many pins and variables are registered, and no big stack frame on a 2 KB Uno.
void WatchBoardClass::sendState() {
    Print &out = *m_serial;

#if defined(ARDUINO_ARCH_ESP32)
    const unsigned long freeRam = esp_get_free_heap_size();
    const unsigned long minFreeRam = esp_get_minimum_free_heap_size();
#elif defined(ARDUINO_ARCH_ESP8266)
    const unsigned long freeRam = ESP.getFreeHeap();
    const unsigned long minFreeRam = 0;
#else
    const unsigned long freeRam = 0;
    const unsigned long minFreeRam = 0;
#endif

    out.print(F("{\"type\":\"state\",\"uptime\":"));
    out.print(millis());
    out.print(F(",\"freeRam\":"));
    out.print(freeRam);
    out.print(F(",\"minFreeRam\":"));
    out.print(minFreeRam);
    out.print(F(",\"pins\":["));

    bool first = true;

    for (uint8_t i = 0; i < m_digitalCount; ++i) {
        const uint8_t pin = m_digitalPins[i];
        if (!first) out.print(',');
        first = false;
        out.print(F("{\"id\":"));
        out.print(pin);
        if (pinIsOutput(pin)) out.print(F(",\"mode\":\"OUTPUT\",\"value\":"));
        else                  out.print(F(",\"mode\":\"INPUT\",\"value\":"));
        out.print(digitalRead(pin) == HIGH ? 1 : 0);
        out.print('}');
    }

    for (uint8_t i = 0; i < m_analogCount; ++i) {
        const uint8_t pin = m_analogPins[i];
        if (!first) out.print(',');
        first = false;
        out.print(F("{\"id\":\"A"));
        out.print(analogIndex(pin));
        out.print(F("\",\"mode\":\"INPUT_ANALOG\",\"value\":"));
        out.print(analogRead(pin));
        out.print('}');
    }

    out.print(']');

    if (m_watchCount > 0) {
        out.print(F(",\"watch\":{"));
        for (uint8_t i = 0; i < m_watchCount; ++i) {
            if (i) out.print(',');
            out.print('"');
            out.print(m_watchVars[i].key);
            out.print(F("\":"));
            printFloat(m_watchVars[i].value);
        }
        out.print('}');
    }

    out.println('}');
}

// Non-negative integer after `"key":`, skipping spaces and a quote: the app
// sends the pin as a string ("pin":"13") and the value as a number ("value":1).
static bool readIntField(const char *line, const char *key, long &out) {
    const char *p = strstr(line, key);
    if (!p) return false;
    p += strlen(key);
    while (*p == ' ' || *p == '"') ++p;
    if (*p < '0' || *p > '9') return false;
    out = strtol(p, nullptr, 10);
    return true;
}

// {"cmd":"set","pin":"13","value":1} — acted on only for a watched digital pin
// the sketch has made an OUTPUT, so a stray line can't drive an input or a pin
// WatchBoard isn't showing.
void WatchBoardClass::handleCommand(const char *line) {
    if (!strstr(line, "\"set\"")) return;
    long pin, value;
    if (!readIntField(line, "\"pin\":", pin) || !readIntField(line, "\"value\":", value)) return;
    if (pin > 255 || !isWatchedDigital((uint8_t)pin) || !pinIsOutput((uint8_t)pin)) return;
    digitalWrite((uint8_t)pin, value ? HIGH : LOW);
}
