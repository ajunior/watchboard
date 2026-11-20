#include "WatchModel.h"
#include <QDateTime>

WatchModel::WatchModel(QObject *parent) : QAbstractListModel(parent) {}

int WatchModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QVariant WatchModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const auto &entry = m_entries.at(index.row());
    if (role == WatchKeyRole)   return entry.first;
    if (role == WatchValueRole) return entry.second;
    return {};
}

QHash<int, QByteArray> WatchModel::roleNames() const {
    return {
        {WatchKeyRole,   "watchKey"},
        {WatchValueRole, "watchValue"},
    };
}

void WatchModel::updateFromMap(const QVariantMap &map) {
    for (auto it = map.begin(); it != map.end(); ++it) {
        int found = -1;
        for (int i = 0; i < m_entries.size(); ++i) {
            if (m_entries.at(i).first == it.key()) { found = i; break; }
        }
        if (found == -1) {
            beginInsertRows({}, m_entries.size(), m_entries.size());
            m_entries << qMakePair(it.key(), it.value());
            endInsertRows();
        } else if (m_entries.at(found).second != it.value()) {
            m_entries[found].second = it.value();
            const QModelIndex idx = index(found);
            emit dataChanged(idx, idx, {WatchValueRole});
        }
    }

    if (m_samples.size() >= MaxSamples)
        m_samples.removeFirst();
    m_samples.append({QDateTime::currentMSecsSinceEpoch(), map});
    emit plotDataChanged();
}

QVariantList WatchModel::plotSamples() const {
    QVariantList result;
    result.reserve(m_samples.size());
    for (const Sample &s : m_samples) {
        QVariantMap entry;
        entry[QStringLiteral("t")] = s.timestampMs;
        entry[QStringLiteral("v")] = s.values;
        result.append(entry);
    }
    return result;
}

QStringList WatchModel::watchKeys() const {
    QStringList keys;
    keys.reserve(m_entries.size());
    for (const auto &e : m_entries)
        keys << e.first;
    return keys;
}
