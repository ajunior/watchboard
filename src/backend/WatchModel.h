#pragma once

#include <QAbstractListModel>
#include <QVariantMap>

class WatchModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int sampleCount READ sampleCount NOTIFY plotDataChanged)

public:
    enum Roles {
        WatchKeyRole = Qt::UserRole + 1,
        WatchValueRole,
    };

    static constexpr int MaxSamples = 300; // 30 s at 100 ms per state message

    explicit WatchModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void updateFromMap(const QVariantMap &map);

    int sampleCount() const { return m_samples.size(); }
    Q_INVOKABLE QVariantList plotSamples() const;
    Q_INVOKABLE QStringList watchKeys() const;

signals:
    void plotDataChanged();

private:
    struct Sample {
        qint64 timestampMs;
        QVariantMap values;
    };

    QList<QPair<QString, QVariant>> m_entries;
    QList<Sample> m_samples;
};
