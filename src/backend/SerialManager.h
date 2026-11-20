#pragma once

#include <QObject>
#include <QSerialPort>
#include <QStringList>

class SerialManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList portList READ portList NOTIFY portListChanged)
    Q_PROPERTY(ConnectionState connectionState READ connectionState NOTIFY connectionStateChanged)

public:
    enum class ConnectionState { Disconnected, Connecting, Connected, Error };
    Q_ENUM(ConnectionState)

    explicit SerialManager(QObject *parent = nullptr);

    QStringList portList() const { return m_portList; }
    ConnectionState connectionState() const { return m_connectionState; }

public slots:
    void refreshPorts();
    void connectToPort(const QString &portName);
    void disconnectPort();
    void sendCommand(const QByteArray &data);

signals:
    void portListChanged();
    void connectionStateChanged();
    void lineReceived(const QString &line);
    void commandSent(const QByteArray &data);
    void errorOccurred(const QString &message);

private slots:
    void onReadyRead();
    void onErrorOccurred(QSerialPort::SerialPortError error);

private:
    void setState(ConnectionState state);

    QSerialPort m_port;
    QByteArray m_readBuffer;
    QStringList m_portList;
    ConnectionState m_connectionState = ConnectionState::Disconnected;
};
