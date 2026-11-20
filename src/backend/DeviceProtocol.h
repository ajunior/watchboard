#pragma once

#include <QByteArray>
#include <QList>
#include <QString>
#include <QVariantMap>

struct PinData {
    QString id;
    QString mode;
    int value = 0;
    bool isAnalog = false;
};

struct HelloData {
    QString boardName;
    int analogBits = 10;
    int analogMax = 1023;
    int cpuMhz = 0;
    bool simulated = false;
    int cores = 1;
    int flashSize = 0;
    int sketchSize = 0;
    QString resetReason;
};

struct StateMessage {
    qint64 uptimeMs = 0;
    int freeRam = 0;
    int minFreeRam = 0;
    QList<PinData> pins;
    QVariantMap watch;
};

enum class MessageType { Hello, State, Unknown };

struct ParsedMessage {
    MessageType type = MessageType::Unknown;
    HelloData hello;
    StateMessage state;
};

class DeviceProtocol {
public:
    static ParsedMessage parseMessage(const QString &line);
    static QByteArray buildSetCommand(const QString &pinId, int value);
};
