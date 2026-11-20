#include "SerialLogModel.h"
#include <QDateTime>
#include <QFile>
#include <QTextStream>
#include <QUrl>

SerialLogModel::SerialLogModel(QObject *parent) : QAbstractListModel(parent) {}

int SerialLogModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QVariant SerialLogModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_entries.size()) return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case TimestampRole: return e.timestamp;
    case DirectionRole: return e.direction;
    case ContentRole:   return e.content;
    }
    return {};
}

QHash<int, QByteArray> SerialLogModel::roleNames() const {
    return {
        {TimestampRole, "timestamp"},
        {DirectionRole, "direction"},
        {ContentRole,   "content"},
    };
}

void SerialLogModel::addEntry(int direction, const QString &content) {
    if (m_entries.size() >= MaxEntries) {
        beginRemoveRows({}, 0, 0);
        m_entries.removeFirst();
        endRemoveRows();
    }
    const QString ts = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
    beginInsertRows({}, m_entries.size(), m_entries.size());
    m_entries.append({ts, direction, content});
    endInsertRows();
}

void SerialLogModel::clear() {
    if (m_entries.isEmpty()) return;
    beginResetModel();
    m_entries.clear();
    endResetModel();
}

bool SerialLogModel::saveLog(const QString &fileUrl) const {
    const QString path = QUrl(fileUrl).toLocalFile();
    QFile f(path.isEmpty() ? fileUrl : path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    QTextStream out(&f);
    out << "WatchBoard Serial Log — "
        << QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss") << "\n"
        << QString(60, '-') << "\n";
    for (const Entry &e : m_entries) {
        out << e.timestamp
            << (e.direction == 0 ? "  ←  " : "  →  ")
            << e.content << "\n";
    }
    return true;
}
