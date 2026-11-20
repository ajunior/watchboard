#pragma once

#include "BoardInfo.h"
#include "BoardProfile.h"
#include "PinModel.h"
#include "SerialLogModel.h"
#include "SerialManager.h"
#include "WatchModel.h"
#include <QObject>
#include <QTimer>

class DeviceController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList portList READ portList NOTIFY portListChanged)
    Q_PROPERTY(int connectionState READ connectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString activePort READ activePort NOTIFY activePortChanged)
    Q_PROPERTY(PinModel* pins READ pins CONSTANT)
    Q_PROPERTY(WatchModel* watches READ watches CONSTANT)
    Q_PROPERTY(BoardInfo* boardInfo READ boardInfo CONSTANT)
    Q_PROPERTY(int messageRate READ messageRate NOTIFY messageRateChanged)

public:
    explicit DeviceController(QObject *parent = nullptr);

    QStringList portList() const;
    int connectionState() const;
    QString lastError() const { return m_lastError; }
    QString activePort() const { return m_activePort; }
    PinModel *pins() { return &m_pinModel; }
    WatchModel *watches() { return &m_watchModel; }
    BoardInfo *boardInfo() { return &m_boardInfo; }
    BoardProfile *profile() { return &m_profile; }
    SerialLogModel *serialLog() { return &m_serialLog; }
    int messageRate() const { return m_messageRate; }

public slots:
    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE void connectToPort(const QString &portName);
    Q_INVOKABLE void disconnectPort();
    // Writes a raw line (newline appended) to the port; logged as TX.
    Q_INVOKABLE bool sendLine(const QString &text);

signals:
    void portListChanged();
    void connectionStateChanged();
    void lastErrorChanged();
    void activePortChanged();
    void messageRateChanged();

private slots:
    void onLineReceived(const QString &line);

private:
    SerialManager m_serial;
    QTimer m_rateTimer;
    int m_messageCount = 0;
    int m_messageRate  = 0;
    BoardProfile m_profile;
    PinModel m_pinModel;
    WatchModel m_watchModel;
    BoardInfo m_boardInfo;
    SerialLogModel m_serialLog;
    QString m_lastError;
    QString m_activePort;
};
