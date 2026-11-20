# deploy.ps1 — Deploy and package WatchBoard for Windows (x64 MSVC).
# Run from the project root after building in ./build/.
# Requires Qt's windeployqt (on PATH or under QT_ROOT_DIR) and Inno Setup's ISCC on PATH.
param(
    [string]$BuildDir = "build",
    [string]$OutDir   = "dist"
)
$ErrorActionPreference = "Stop"

# Anchored on the project() line: an unanchored \d+\.\d+\.\d+ takes whatever
# three-part number comes first in the file, which need not be the version.
$Version = (Select-String -Path CMakeLists.txt `
    -Pattern 'project\(\s*\w+\s+VERSION\s+(\d+\.\d+\.\d+)' |
    Select-Object -First 1).Matches[0].Groups[1].Value
if (-not $Version) { throw "Could not read the version out of CMakeLists.txt" }

# Qt names its Windows tools with and without the 6 depending on how it was
# installed, and CI may not have them on PATH at all — hence QT_ROOT_DIR.
function Find-QtTool([string[]]$Names) {
    foreach ($n in $Names) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    if ($env:QT_ROOT_DIR) {
        foreach ($n in $Names) {
            $path = Join-Path $env:QT_ROOT_DIR "bin\$n.exe"
            if (Test-Path $path) { return $path }
        }
    }
    throw "None of these are on PATH or under QT_ROOT_DIR: $($Names -join ', ')"
}

function Get-CacheDir([string]$Name) {
    $m = Select-String -Path "$BuildDir\CMakeCache.txt" -Pattern "^${Name}:STATIC=(.*)$" |
         Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
    return $null
}

$WinDeployQt = Find-QtTool @("windeployqt6", "windeployqt")

$StageDir = "$env:TEMP\watchboard-stage"
Remove-Item -Recurse -Force $StageDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $StageDir, $OutDir | Out-Null

# ── Copy executable ──────────────────────────────────────────────────────────
# Release\ is where a multi-config generator puts it; Ninja and NMake, which are
# single-config, put it straight in the build directory.
$Exe = @("$BuildDir\watchboard.exe", "$BuildDir\Release\watchboard.exe") |
       Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Exe) { throw "watchboard.exe not found under $BuildDir" }
Copy-Item $Exe "$StageDir\watchboard.exe"

# ── windeployqt ─────────────────────────────────────────────────────────────
# Mahina's QML is scanned along with the app's own: it imports modules
# (QtQuick.Effects, QtQml.Models, Dialogs) that nothing under src\qml does.
# Mahina itself is linked statically and served from qrc, so its build
# directory is only there to resolve `import Mahina`; the copy windeployqt
# makes from it is removed afterwards.
$MahinaSrc = Get-CacheDir "Mahina_SOURCE_DIR"
$MahinaBin = Get-CacheDir "Mahina_BINARY_DIR"
if (-not $MahinaSrc -or -not (Test-Path "$MahinaSrc\qml") -or
    -not $MahinaBin -or -not (Test-Path "$MahinaBin\Mahina\qmldir")) {
    throw "Mahina's sources or build not found via $BuildDir\CMakeCache.txt"
}

& $WinDeployQt `
    --release `
    --no-translations `
    --no-system-d3d-compiler `
    --no-opengl-sw `
    --qmldir src\qml `
    --qmldir "$MahinaSrc\qml" `
    --qmlimport "$MahinaBin" `
    "$StageDir\watchboard.exe"
if ($LASTEXITCODE -ne 0) { throw "windeployqt failed" }
Remove-Item -Recurse -Force "$StageDir\qml\Mahina" -ErrorAction SilentlyContinue

# ── Start what was just staged ───────────────────────────────────────────────
# The staged copy, not the build tree's, so a QML module windeployqt missed
# shows up here and not on a user's machine. It has to still be running after
# five seconds with no QML errors. A GUI-subsystem app logs to the debugger
# rather than to a redirected stderr unless QT_FORCE_STDERR_LOGGING is set.
Write-Host "── smoke test ──"
$env:QT_QPA_PLATFORM = "offscreen"
$env:QT_FORCE_STDERR_LOGGING = "1"
$SmokeErr = "$env:TEMP\watchboard-smoke.err"
$SmokeOut = "$env:TEMP\watchboard-smoke.out"
$p = Start-Process -FilePath "$StageDir\watchboard.exe" -PassThru `
        -RedirectStandardError $SmokeErr -RedirectStandardOutput $SmokeOut
Start-Sleep -Seconds 5
$exited = $p.HasExited
if (-not $exited) { Stop-Process -Id $p.Id -Force; $p.WaitForExit() }
Remove-Item Env:\QT_QPA_PLATFORM, Env:\QT_FORCE_STDERR_LOGGING
$log = (Get-Content $SmokeErr, $SmokeOut -Raw -ErrorAction SilentlyContinue) -join "`n"
if ($exited) {
    throw "the staged app did not stay up (exit $($p.ExitCode)):`n$log"
}
if ($log -match '(?i)qrc:|\.qml:|is not installed|error') {
    throw "the staged app booted but reported errors:`n$log"
}
Write-Host "  watchboard booted from the staging directory and stayed up"

# ── Compile Inno Setup installer ─────────────────────────────────────────────
$iss = (Get-Content packaging\windows\installer.iss -Raw) `
    -replace "__VERSION__", $Version `
    -replace "__STAGE__",   $StageDir.Replace("\", "\\") `
    -replace "__ICON__",    (Get-Item assets\watchboard.ico).FullName.Replace("\", "\\")
$tmpIss = "$env:TEMP\watchboard-installer.iss"
Set-Content -Path $tmpIss -Value $iss

& iscc $tmpIss "/O$((Get-Item $OutDir).FullName)"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed" }

Write-Host "Installer written to $OutDir"
