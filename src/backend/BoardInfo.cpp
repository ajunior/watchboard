#include "BoardInfo.h"

BoardInfo::BoardInfo(QObject *parent) : QObject(parent) {}

void BoardInfo::applyHello(const QString &board, int analogMax, int cpuMhz, bool simulated,
                           int cores, int flashSize, int sketchSize, const QString &resetReason) {
    m_boardName = board;
    m_analogMax = analogMax;
    m_cpuMhz = cpuMhz;
    m_simulated = simulated;
    m_cores = cores;
    m_flashSize = flashSize;
    m_sketchSize = sketchSize;
    m_resetReason = resetReason;
    emit boardInfoChanged();
}

void BoardInfo::applyState(qint64 uptimeMs, int freeRam, int minFreeRam) {
    m_uptimeMs = uptimeMs;
    m_freeRam = freeRam;
    m_minFreeRam = minFreeRam;
    emit boardInfoChanged();
}

void BoardInfo::reset() {
    m_boardName.clear();
    m_analogMax = 1023;
    m_cpuMhz = 0;
    m_cores = 1;
    m_flashSize = 0;
    m_sketchSize = 0;
    m_resetReason.clear();
    m_uptimeMs = 0;
    m_freeRam = 0;
    m_minFreeRam = 0;
    m_simulated = false;
    emit boardInfoChanged();
}
