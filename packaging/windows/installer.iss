; installer.iss — Inno Setup script for WatchBoard.
; Tokens __VERSION__, __STAGE__ and __ICON__ are substituted by deploy.ps1.
#define AppName    "WatchBoard"
#define AppVersion "__VERSION__"
#define AppPublisher "Adjamilton Junior"
#define AppURL     "https://github.com/ajunior/watchboard"
#define AppExeName "watchboard.exe"
#define StageDir   "__STAGE__"
; Absolute, because deploy.ps1 compiles this script from the temp directory and
; a relative path would be resolved against that.
#define IconFile   "__ICON__"

[Setup]
AppId={{A964B1D0-0EB1-4AD8-82B4-6CB5A17590A6}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputBaseFilename=WatchBoard-{#AppVersion}-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
