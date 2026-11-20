#include "DeviceProtocol.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

ParsedMessage DeviceProtocol::parseMessage(const QString &line) {
    ParsedMessage result;
    const QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8());
    if (!doc.isObject())
        return result;

    const QJsonObject obj = doc.object();
    const QString type = obj.value("type").toString();

    if (type == "hello") {
        result.type = MessageType::Hello;
        result.hello.boardName = obj.value("board").toString("Unknown");
        result.hello.analogBits = obj.value("analogBits").toInt(10);
        result.hello.analogMax = obj.value("analogMax").toInt(1023);
        result.hello.cpuMhz = obj.value("cpuMhz").toInt(0);
        result.hello.simulated = obj.value("simulated").toBool(false);
        result.hello.cores = obj.value("cores").toInt(1);
        result.hello.flashSize = obj.value("flashSize").toInt(0);
        result.hello.sketchSize = obj.value("sketchSize").toInt(0);
        result.hello.resetReason = obj.value("resetReason").toString();
        return result;
    }

    if (type == "state") {
        result.type = MessageType::State;
        result.state.uptimeMs = static_cast<qint64>(obj.value("uptime").toDouble(0));
        result.state.freeRam = obj.value("freeRam").toInt(0);
        result.state.minFreeRam = obj.value("minFreeRam").toInt(0);

        for (const QJsonValue &v : obj.value("pins").toArray()) {
            const QJsonObject p = v.toObject();
            PinData pin;
            pin.id = p.value("id").toVariant().toString();
            pin.mode = p.value("mode").toString();
            pin.value = p.value("value").toInt();
            pin.isAnalog = pin.mode == "INPUT_ANALOG";
            result.state.pins << pin;
        }

        const QJsonObject watchObj = obj.value("watch").toObject();
        for (auto it = watchObj.begin(); it != watchObj.end(); ++it)
            result.state.watch.insert(it.key(), it.value().toVariant());

        return result;
    }

    return result;
}

QByteArray DeviceProtocol::buildSetCommand(const QString &pinId, int value) {
    QJsonObject obj;
    obj["cmd"] = "set";
    obj["pin"] = pinId;
    obj["value"] = value;
    return QJsonDocument(obj).toJson(QJsonDocument::Compact);
}
