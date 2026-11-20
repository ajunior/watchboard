#include "BoardProfile.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

BoardProfile::BoardProfile(QObject *parent) : QObject(parent) {}

QString BoardProfile::toLocalPath(const QString &fileUrl) {
    const QString local = QUrl(fileUrl).toLocalFile();
    return local.isEmpty() ? fileUrl : local;
}

bool BoardProfile::load(const QString &fileUrl) {
    const QString path = toLocalPath(fileUrl);
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return false;

    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

    m_filePath = path;
    m_name     = root.value("board").toString();
    m_labels.clear();

    const QJsonObject labels = root.value("labels").toObject();
    for (auto it = labels.begin(); it != labels.end(); ++it)
        m_labels[it.key()] = it.value().toString();

    ++m_revision;
    emit profileChanged();
    emit labelsChanged();
    return true;
}

bool BoardProfile::save(const QString &fileUrl) {
    if (!fileUrl.isEmpty()) {
        const QString path = toLocalPath(fileUrl);
        m_filePath = path;
        if (!m_name.isEmpty())
            m_name = m_name; // preserve existing name
    }
    if (m_filePath.isEmpty())
        return false;

    QJsonObject labels;
    for (auto it = m_labels.cbegin(); it != m_labels.cend(); ++it)
        labels[it.key()] = it.value();

    QJsonObject root;
    if (!m_name.isEmpty())
        root["board"] = m_name;
    root["labels"] = labels;

    QFile f(m_filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;

    f.write(QJsonDocument(root).toJson());
    emit profileChanged(); // loaded state may have changed
    return true;
}

QString BoardProfile::label(const QString &pinId) const {
    return m_labels.value(pinId);
}

void BoardProfile::setLabel(const QString &pinId, const QString &label) {
    const QString trimmed = label.trimmed();
    if (trimmed.isEmpty()) {
        clearLabel(pinId);
        return;
    }
    m_labels[pinId] = trimmed;
    ++m_revision;
    emit labelsChanged();
}

void BoardProfile::clearLabel(const QString &pinId) {
    if (!m_labels.remove(pinId))
        return;
    ++m_revision;
    emit labelsChanged();
}

QVariantList BoardProfile::labelList() const {
    QVariantList result;
    result.reserve(m_labels.size());
    for (auto it = m_labels.cbegin(); it != m_labels.cend(); ++it) {
        QVariantMap entry;
        entry[QStringLiteral("pinId")] = it.key();
        entry[QStringLiteral("label")] = it.value();
        result.append(entry);
    }
    return result;
}
