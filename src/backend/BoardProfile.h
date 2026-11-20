#pragma once

#include <QMap>
#include <QObject>
#include <QString>

class BoardProfile : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name    READ name    NOTIFY profileChanged)
    Q_PROPERTY(bool    loaded  READ loaded  NOTIFY profileChanged)
    Q_PROPERTY(int     revision READ revision NOTIFY labelsChanged)

public:
    explicit BoardProfile(QObject *parent = nullptr);

    QString name()     const { return m_name; }
    bool    loaded()   const { return !m_filePath.isEmpty(); }
    int     revision() const { return m_revision; }

    // fileUrl may be a file:// URL or a plain path
    Q_INVOKABLE bool load(const QString &fileUrl);
    Q_INVOKABLE bool save(const QString &fileUrl = {});

    Q_INVOKABLE QString label(const QString &pinId) const;
    Q_INVOKABLE void setLabel(const QString &pinId, const QString &label);
    Q_INVOKABLE void clearLabel(const QString &pinId);

    // Returns [{pinId, label}, …] sorted by pin ID — for QML Repeaters
    Q_INVOKABLE QVariantList labelList() const;

signals:
    void profileChanged();
    void labelsChanged();

private:
    static QString toLocalPath(const QString &fileUrl);

    QString m_name;
    QString m_filePath;
    QMap<QString, QString> m_labels;
    int m_revision = 0;
};
