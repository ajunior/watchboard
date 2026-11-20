#pragma once

#include <QObject>
#include <QString>

class BoardInfo : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString boardName  READ boardName  NOTIFY boardInfoChanged)
    Q_PROPERTY(int analogMax      READ analogMax  NOTIFY boardInfoChanged)
    Q_PROPERTY(int cpuMhz         READ cpuMhz     NOTIFY boardInfoChanged)
    Q_PROPERTY(int cores          READ cores      NOTIFY boardInfoChanged)
    Q_PROPERTY(int flashSize      READ flashSize  NOTIFY boardInfoChanged)
    Q_PROPERTY(int sketchSize     READ sketchSize NOTIFY boardInfoChanged)
    Q_PROPERTY(QString resetReason READ resetReason NOTIFY boardInfoChanged)
    Q_PROPERTY(qint64 uptimeMs   READ uptimeMs   NOTIFY boardInfoChanged)
    Q_PROPERTY(int freeRam        READ freeRam    NOTIFY boardInfoChanged)
    Q_PROPERTY(int minFreeRam     READ minFreeRam NOTIFY boardInfoChanged)
    Q_PROPERTY(bool simulated     READ simulated  NOTIFY boardInfoChanged)

public:
    explicit BoardInfo(QObject *parent = nullptr);

    QString boardName()  const { return m_boardName; }
    int analogMax()      const { return m_analogMax; }
    int cpuMhz()         const { return m_cpuMhz; }
    int cores()          const { return m_cores; }
    int flashSize()      const { return m_flashSize; }
    int sketchSize()     const { return m_sketchSize; }
    QString resetReason() const { return m_resetReason; }
    qint64 uptimeMs()   const { return m_uptimeMs; }
    int freeRam()        const { return m_freeRam; }
    int minFreeRam()     const { return m_minFreeRam; }
    bool simulated()     const { return m_simulated; }

    void applyHello(const QString &board, int analogMax, int cpuMhz, bool simulated,
                    int cores, int flashSize, int sketchSize, const QString &resetReason);
    void applyState(qint64 uptimeMs, int freeRam, int minFreeRam);
    void reset();

signals:
    void boardInfoChanged();

private:
    QString m_boardName;
    int m_analogMax = 1023;
    int m_cpuMhz = 0;
    int m_cores = 1;
    int m_flashSize = 0;
    int m_sketchSize = 0;
    QString m_resetReason;
    qint64 m_uptimeMs = 0;
    int m_freeRam = 0;
    int m_minFreeRam = 0;
    bool m_simulated = false;
};
