#include "SerialManager.h"
#include <QSerialPortInfo>

SerialManager::SerialManager(QObject *parent) : QObject(parent) {
    connect(&m_port, &QSerialPort::readyRead, this, &SerialManager::onReadyRead);
    connect(&m_port, &QSerialPort::errorOccurred, this, &SerialManager::onErrorOccurred);
    refreshPorts();
}

void SerialManager::refreshPorts() {
    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts())
        ports << info.portName();
    if (ports != m_portList) {
        m_portList = ports;
        emit portListChanged();
    }
}

void SerialManager::connectToPort(const QString &portName) {
    if (m_port.isOpen())
        m_port.close();

    m_port.setPortName(portName);
    m_port.setBaudRate(QSerialPort::Baud115200);
    m_port.setDataBits(QSerialPort::Data8);
    m_port.setParity(QSerialPort::NoParity);
    m_port.setStopBits(QSerialPort::OneStop);

    setState(ConnectionState::Connecting);

    if (m_port.open(QIODevice::ReadWrite)) {
        setState(ConnectionState::Connected);
    } else {
        setState(ConnectionState::Error);
        emit errorOccurred(m_port.errorString());
    }
}

void SerialManager::disconnectPort() {
    if (m_port.isOpen())
        m_port.close();
    m_readBuffer.clear();
    setState(ConnectionState::Disconnected);
}

void SerialManager::sendCommand(const QByteArray &data) {
    if (!m_port.isOpen())
        return;
    m_port.write(data);
    m_port.write("\n");
    emit commandSent(data);
}

void SerialManager::onReadyRead() {
    m_readBuffer += m_port.readAll();
    int idx;
    while ((idx = m_readBuffer.indexOf('\n')) != -1) {
        QString line = QString::fromUtf8(m_readBuffer.left(idx)).trimmed();
        m_readBuffer.remove(0, idx + 1);
        if (!line.isEmpty())
            emit lineReceived(line);
    }
}

void SerialManager::onErrorOccurred(QSerialPort::SerialPortError error) {
    if (error == QSerialPort::NoError)
        return;
    if (m_connectionState == ConnectionState::Connected) {
        setState(ConnectionState::Error);
        emit errorOccurred(m_port.errorString());
    }
}

void SerialManager::setState(ConnectionState state) {
    if (m_connectionState == state)
        return;
    m_connectionState = state;
    emit connectionStateChanged();
}
