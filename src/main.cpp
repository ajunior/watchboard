#include "backend/DeviceController.h"
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>
#include <QVariantMap>
#include <QtVersion>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("WatchBoard");
    app.setApplicationVersion(QStringLiteral(WATCHBOARD_VERSION));
    app.setOrganizationName("WatchBoard");

    // Mahina's bundled fonts (Inter, JetBrains Mono, Phosphor icon weights),
    // compiled into the binary as resources of the Mahina QML module. Without
    // the Phosphor ones every Icon renders as a missing-glyph box.
    for (const char *font : { "InterVariable", "JetBrainsMonoVariable",
                              "Phosphor-Regular", "Phosphor-Thin", "Phosphor-Light",
                              "Phosphor-Bold", "Phosphor-Fill", "Phosphor-Duotone" }) {
        QFontDatabase::addApplicationFont(
            QStringLiteral(":/qt/qml/Mahina/assets/fonts/%1.ttf").arg(QLatin1String(font)));
    }
    QFont uiFont(QStringLiteral("Inter Variable"));
    uiFont.setPixelSize(13);
    app.setFont(uiFont);
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/WatchBoard/assets/logo.svg")));

    DeviceController controller;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("DeviceController", &controller);
    engine.rootContext()->setContextProperty("PinModel", controller.pins());
    engine.rootContext()->setContextProperty("WatchModel", controller.watches());
    engine.rootContext()->setContextProperty("BoardInfo", controller.boardInfo());
    engine.rootContext()->setContextProperty("BoardProfile", controller.profile());
    engine.rootContext()->setContextProperty("SerialLog", controller.serialLog());
    engine.rootContext()->setContextProperty("AppInfo", QVariantMap{
        { "version",       QStringLiteral(WATCHBOARD_VERSION) },
        { "qtVersion",     QString::fromLatin1(qVersion()) },
        { "mahinaVersion", QStringLiteral(MAHINA_VERSION) },
        { "repoUrl",       QStringLiteral(WATCHBOARD_REPO_URL) },
    });

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/WatchBoard/src/qml/main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    const QStringList args = app.arguments();
    const int portIdx = args.indexOf("--port");
    if (portIdx != -1 && portIdx + 1 < args.size()) {
        const QString port = args.at(portIdx + 1);
        QTimer::singleShot(200, &controller, [&controller, port] {
            controller.connectToPort(port);
        });
    }

    return app.exec();
}
