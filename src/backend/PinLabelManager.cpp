#include "PinLabelManager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

PinLabelManager::PinLabelManager(QObject *parent) : QObject(parent) {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_filePath = dir + "/pin_labels.json";
    load();
}

QString PinLabelManager::label(const QString &port, const QString &pinId) const {
    return m_labels.value(port).value(pinId);
}

void PinLabelManager::setLabel(const QString &port, const QString &pinId, const QString &label) {
    const QString trimmed = label.trimmed();
    if (trimmed.isEmpty()) {
        clearLabel(port, pinId);
        return;
    }
    m_labels[port][pinId] = trimmed;
    ++m_revision;
    save();
    emit labelsChanged();
}

void PinLabelManager::clearLabel(const QString &port, const QString &pinId) {
    if (!m_labels.contains(port) || !m_labels[port].contains(pinId))
        return;
    m_labels[port].remove(pinId);
    if (m_labels[port].isEmpty())
        m_labels.remove(port);
    ++m_revision;
    save();
    emit labelsChanged();
}

void PinLabelManager::load() {
    QFile f(m_filePath);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    for (auto portIt = root.begin(); portIt != root.end(); ++portIt) {
        const QJsonObject pins = portIt.value().toObject();
        for (auto pinIt = pins.begin(); pinIt != pins.end(); ++pinIt)
            m_labels[portIt.key()][pinIt.key()] = pinIt.value().toString();
    }
}

void PinLabelManager::save() const {
    QDir().mkpath(QFileInfo(m_filePath).absolutePath());
    QJsonObject root;
    for (auto portIt = m_labels.cbegin(); portIt != m_labels.cend(); ++portIt) {
        QJsonObject pins;
        for (auto pinIt = portIt.value().cbegin(); pinIt != portIt.value().cend(); ++pinIt)
            pins[pinIt.key()] = pinIt.value();
        root[portIt.key()] = pins;
    }
    QFile f(m_filePath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(root).toJson());
}
