#pragma once

#include <QAbstractListModel>
#include <QList>

class SerialLogModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        TimestampRole = Qt::UserRole + 1,
        DirectionRole,  // 0 = in (device→host), 1 = out (host→device)
        ContentRole,
    };

    static constexpr int MaxEntries = 500;

    explicit SerialLogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void addEntry(int direction, const QString &content);
    Q_INVOKABLE void clear();
    Q_INVOKABLE bool saveLog(const QString &fileUrl) const;

private:
    struct Entry {
        QString timestamp;
        int direction;
        QString content;
    };

    QList<Entry> m_entries;
};
