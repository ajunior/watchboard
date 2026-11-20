#include "DeviceController.h"
#include "DeviceProtocol.h"

DeviceController::DeviceController(QObject *parent) : QObject(parent) {
    m_pinModel.setLabelManager(&m_profile);
    m_rateTimer.setInterval(1000);
    connect(&m_rateTimer, &QTimer::timeout, this, [this] {
        if (m_messageRate != m_messageCount) {
            m_messageRate = m_messageCount;
            emit messageRateChanged();
        }
        m_messageCount = 0;
    });
    m_rateTimer.start();
    connect(&m_serial, &SerialManager::lineReceived, this, &DeviceController::onLineReceived);
    connect(&m_serial, &SerialManager::lineReceived, this, [this] { ++m_messageCount; });
    connect(&m_serial, &SerialManager::lineReceived, this, [this](const QString &line) {
        m_serialLog.addEntry(0, line);
    });
    connect(&m_serial, &SerialManager::commandSent, this, [this](const QByteArray &data) {
        m_serialLog.addEntry(1, QString::fromUtf8(data).trimmed());
    });
    connect(&m_serial, &SerialManager::portListChanged, this, &DeviceController::portListChanged);
    connect(&m_serial, &SerialManager::connectionStateChanged, this, [this] {
        const auto state = m_serial.connectionState();
        if (state == SerialManager::ConnectionState::Disconnected ||
            state == SerialManager::ConnectionState::Error) {
            m_boardInfo.reset();
        }
        if (state == SerialManager::ConnectionState::Disconnected) {
            m_activePort.clear();
            emit activePortChanged();
        }
        emit connectionStateChanged();
    });
    connect(&m_serial, &SerialManager::errorOccurred, this, [this](const QString &msg) {
        m_lastError = msg;
        emit lastErrorChanged();
    });
    connect(&m_pinModel, &PinModel::toggleRequested, this, [this](const QString &pinId, int value) {
        m_serial.sendCommand(DeviceProtocol::buildSetCommand(pinId, value));
    });
}

QStringList DeviceController::portList() const {
    return m_serial.portList();
}

int DeviceController::connectionState() const {
    return static_cast<int>(m_serial.connectionState());
}

void DeviceController::refreshPorts() {
    m_serial.refreshPorts();
}

void DeviceController::connectToPort(const QString &portName) {
    m_lastError.clear();
    emit lastErrorChanged();
    m_activePort = portName;
    emit activePortChanged();
    m_serial.connectToPort(portName);
}

void DeviceController::disconnectPort() {
    m_serial.disconnectPort();
}

bool DeviceController::sendLine(const QString &text) {
    if (m_serial.connectionState() != SerialManager::ConnectionState::Connected || text.isEmpty())
        return false;
    m_serial.sendCommand(text.toUtf8());
    return true;
}

void DeviceController::onLineReceived(const QString &line) {
    const ParsedMessage msg = DeviceProtocol::parseMessage(line);
    switch (msg.type) {
    case MessageType::Hello:
        m_boardInfo.applyHello(msg.hello.boardName, msg.hello.analogMax, msg.hello.cpuMhz, msg.hello.simulated,
                               msg.hello.cores, msg.hello.flashSize, msg.hello.sketchSize, msg.hello.resetReason);
        m_pinModel.setAnalogMax(msg.hello.analogMax);
        break;
    case MessageType::State:
        m_boardInfo.applyState(msg.state.uptimeMs, msg.state.freeRam, msg.state.minFreeRam);
        m_pinModel.updateFromList(msg.state.pins);
        m_watchModel.updateFromMap(msg.state.watch);
        break;
    default:
        break;
    }
}
