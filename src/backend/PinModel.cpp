#include "PinModel.h"
#include "BoardProfile.h"

PinModel::PinModel(QObject *parent) : QAbstractListModel(parent) {}

int PinModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_visibleIndices.size();
}

QVariant PinModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_visibleIndices.size())
        return {};
    const int actual = m_visibleIndices.at(index.row());
    const PinData &pin = m_pins.at(actual);
    switch (role) {
    case PinIdRole:       return pin.id;
    case PinModeRole:     return pin.mode;
    case PinValueRole:    return pin.value;
    case PinIsAnalogRole: return pin.isAnalog;
    case PinMaxValueRole: return m_analogMax;
    case PinLabelRole:
        return m_labelMgr ? m_labelMgr->label(pin.id) : QString{};
    case PinHistoryRole: {
        if (!pin.isAnalog) return QVariantList{};
        QVariantList list;
        const auto &hist = m_history.value(pin.id);
        list.reserve(hist.size());
        for (int v : hist) list << v;
        return list;
    }
    }
    return {};
}

QHash<int, QByteArray> PinModel::roleNames() const {
    return {
        {PinIdRole,       "pinId"},
        {PinModeRole,     "pinMode"},
        {PinValueRole,    "pinValue"},
        {PinIsAnalogRole, "pinIsAnalog"},
        {PinMaxValueRole, "pinMaxValue"},
        {PinHistoryRole,  "pinHistory"},
        {PinLabelRole,    "pinLabel"},
    };
}

int PinModel::digitalCount() const {
    int n = 0;
    for (const auto &p : m_pins) if (!p.isAnalog) ++n;
    return n;
}

int PinModel::analogCount() const {
    int n = 0;
    for (const auto &p : m_pins) if (p.isAnalog) ++n;
    return n;
}

int PinModel::outputCount() const {
    int n = 0;
    for (const auto &p : m_pins) if (p.mode == "OUTPUT") ++n;
    return n;
}

void PinModel::setAnalogMax(int max) {
    if (m_analogMax == max) return;
    m_analogMax = max;
    emit analogMaxChanged();
    if (!m_visibleIndices.isEmpty())
        emit dataChanged(index(0), index(m_visibleIndices.size() - 1), {PinMaxValueRole});
}

void PinModel::setFilterText(const QString &text) {
    if (m_filterText == text) return;
    m_filterText = text;
    emit filterTextChanged();
    rebuildFilter();
}

void PinModel::setLabelManager(BoardProfile *mgr) {
    m_labelMgr = mgr;
    connect(mgr, &BoardProfile::labelsChanged, this, [this] {
        if (m_filterText.isEmpty()) {
            // Just refresh label text in place — no delegate churn
            if (!m_visibleIndices.isEmpty())
                emit dataChanged(index(0), index(m_visibleIndices.size() - 1), {PinLabelRole});
        } else {
            // Filter may now match/unmatch on label text
            rebuildFilter();
        }
    });
}


void PinModel::rebuildFilter() {
    beginResetModel();
    m_visibleIndices.clear();
    for (int i = 0; i < m_pins.size(); ++i) {
        if (pinPassesFilter(m_pins[i]))
            m_visibleIndices.append(i);
    }
    endResetModel();
}

bool PinModel::pinPassesFilter(const PinData &pin) const {
    if (m_filterText.isEmpty()) return true;
    const QString lower = m_filterText.toLower();
    if (pin.id.toLower().contains(lower)) return true;
    if (m_labelMgr) {
        const QString lbl = m_labelMgr->label(pin.id);
        if (!lbl.isEmpty() && lbl.toLower().contains(lower)) return true;
    }
    return false;
}

int PinModel::visibleRowFor(int actualIndex) const {
    return m_visibleIndices.indexOf(actualIndex);
}

void PinModel::updateFromList(const QList<PinData> &pins) {
    bool countsDirty = false;
    for (const PinData &incoming : pins) {
        int found = -1;
        for (int j = 0; j < m_pins.size(); ++j) {
            if (m_pins.at(j).id == incoming.id) { found = j; break; }
        }

        if (found == -1) {
            countsDirty = true;
            const int actIdx = m_pins.size();
            const bool passes = pinPassesFilter(incoming);
            if (passes) {
                const int visRow = m_visibleIndices.size(); // always appended at end
                beginInsertRows({}, visRow, visRow);
                m_pins.append(incoming);
                if (incoming.isAnalog)
                    m_history[incoming.id].append(incoming.value);
                m_visibleIndices.append(actIdx);
                endInsertRows();
            } else {
                m_pins.append(incoming);
                if (incoming.isAnalog)
                    m_history[incoming.id].append(incoming.value);
            }
        } else {
            if (m_pins[found].mode != incoming.mode) countsDirty = true;
            bool changed = m_pins[found].value != incoming.value
                        || m_pins[found].mode  != incoming.mode;
            m_pins[found] = incoming;

            QList<int> changedRoles = {PinValueRole, PinModeRole};
            if (incoming.isAnalog) {
                auto &hist = m_history[incoming.id];
                hist.append(incoming.value);
                if (hist.size() > HistorySize)
                    hist.removeFirst();
                changedRoles << PinHistoryRole;
                changed = true;
            }

            const int visRow = visibleRowFor(found);
            const bool nowPasses = pinPassesFilter(incoming);

            if (visRow >= 0 && nowPasses) {
                if (changed) {
                    const QModelIndex idx = index(visRow);
                    emit dataChanged(idx, idx, changedRoles);
                }
            } else if (visRow >= 0 && !nowPasses) {
                beginRemoveRows({}, visRow, visRow);
                m_visibleIndices.removeAt(visRow);
                endRemoveRows();
            } else if (visRow < 0 && nowPasses) {
                int insertPos = 0;
                while (insertPos < m_visibleIndices.size() && m_visibleIndices[insertPos] < found)
                    ++insertPos;
                beginInsertRows({}, insertPos, insertPos);
                m_visibleIndices.insert(insertPos, found);
                endInsertRows();
            }
        }
    }
    if (countsDirty)
        emit countsChanged();
}

void PinModel::togglePin(int row) {
    if (row < 0 || row >= m_visibleIndices.size()) return;
    const int actual = m_visibleIndices.at(row);
    const PinData &pin = m_pins.at(actual);
    if (pin.mode != "OUTPUT") return;
    emit toggleRequested(pin.id, pin.value == 0 ? 1 : 0);
}
