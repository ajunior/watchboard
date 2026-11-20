#pragma once

#include "DeviceProtocol.h"
#include <QAbstractListModel>
#include <QMap>

class BoardProfile;

class PinModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int analogMax READ analogMax NOTIFY analogMaxChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(int totalCount   READ totalCount   NOTIFY countsChanged)
    Q_PROPERTY(int digitalCount READ digitalCount NOTIFY countsChanged)
    Q_PROPERTY(int analogCount  READ analogCount  NOTIFY countsChanged)
    Q_PROPERTY(int outputCount  READ outputCount  NOTIFY countsChanged)

public:
    enum Roles {
        PinIdRole = Qt::UserRole + 1,
        PinModeRole,
        PinValueRole,
        PinIsAnalogRole,
        PinMaxValueRole,
        PinHistoryRole,
        PinLabelRole,
    };

    static constexpr int HistorySize = 60;

    explicit PinModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int analogMax() const { return m_analogMax; }
    void setAnalogMax(int max);

    QString filterText() const { return m_filterText; }
    Q_INVOKABLE void setFilterText(const QString &text);

    int totalCount()   const { return m_pins.size(); }
    int digitalCount() const;
    int analogCount()  const;
    int outputCount()  const;

    void setLabelManager(BoardProfile *mgr);

    void updateFromList(const QList<PinData> &pins);
    Q_INVOKABLE void togglePin(int index);

signals:
    void analogMaxChanged();
    void toggleRequested(const QString &pinId, int value);
    void filterTextChanged();
    void countsChanged();

private:
    void rebuildFilter();
    bool pinPassesFilter(const PinData &pin) const;
    int visibleRowFor(int actualIndex) const;

    QList<PinData> m_pins;
    QList<int> m_visibleIndices;
    QMap<QString, QList<int>> m_history;
    int m_analogMax = 1023;
    QString m_filterText;
    BoardProfile *m_labelMgr = nullptr;
};
