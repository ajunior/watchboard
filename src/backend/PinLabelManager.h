#pragma once

#include <QMap>
#include <QObject>
#include <QString>

class PinLabelManager : public QObject {
    Q_OBJECT
    // revision increments on every change; QML bindings touch it to stay reactive
    Q_PROPERTY(int revision READ revision NOTIFY labelsChanged)

public:
    explicit PinLabelManager(QObject *parent = nullptr);

    int revision() const { return m_revision; }

    Q_INVOKABLE QString label(const QString &port, const QString &pinId) const;
    Q_INVOKABLE void setLabel(const QString &port, const QString &pinId, const QString &label);
    Q_INVOKABLE void clearLabel(const QString &port, const QString &pinId);

signals:
    void labelsChanged();

private:
    void load();
    void save() const;

    QMap<QString, QMap<QString, QString>> m_labels; // port → (pinId → label)
    QString m_filePath;
    int m_revision = 0;
};
