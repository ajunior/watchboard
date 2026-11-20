.pragma library

// "hh:mm:ss", or "Nd hh:mm:ss" past a day. Fixed width so it doesn't jitter.
function uptime(ms) {
    if (!(ms > 0)) return "—"
    const s = Math.floor(ms / 1000)
    const d = Math.floor(s / 86400)
    const p = n => String(n).padStart(2, "0")
    const hms = p(Math.floor(s % 86400 / 3600)) + ":" + p(Math.floor(s % 3600 / 60)) + ":" + p(s % 60)
    return d > 0 ? d + "d " + hms : hms
}
