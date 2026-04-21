; Inno Setup script for Pensine.
;
; Compiled in CI by `release.yml`'s windows-release job:
;   ISCC /DAppVersion=1.1.3 /DBuildNumber=42 windows\installer\pensine.iss
;
; Produces: build\windows\installer\pensine-v<version>-build<N>-setup.exe
; (See OutputBaseFilename below — same naming pattern as the zip artifact.)
;
; Per-user install (PrivilegesRequired=lowest) — no admin prompt on install
; or uninstall, registry writes go to HKCU. Matches how the zip channel
; behaves today (extract anywhere, no admin).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif

#define AppName        "Pensine"
#define AppPublisher   "Martial Ren"
#define AppURL         "https://frenchcommando.github.io/pensine/site/"
#define AppExeName     "pensine.exe"
#define AppId          "{{A3F7E8D9-4B5C-6A7D-8E9F-1B2C3D4E5F6A}"
#define ProgId         "Pensine.Workspace"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion} (build {#BuildNumber})
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL=https://github.com/FrenchCommando/pensine/issues
AppUpdatesURL=https://github.com/FrenchCommando/pensine/releases/latest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Flutter Windows runtime requires Windows 10 1809 (build 17763) or later.
MinVersion=10.0.17763
; Pensine ships an x64 Flutter build. `x64compatible` accepts x64 native PCs
; and ARM64 Windows 11 PCs (where x64 binaries run under built-in emulation).
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
OutputDir=..\..\build\windows\installer
OutputBaseFilename=pensine-v{#AppVersion}-build{#BuildNumber}-setup
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
; Replaces the cryptic default ("designed for the following processor architectures:
; x64compatible") with something a user can act on.
WindowsVersionNotSupported=Pensine needs Windows 10 (version 1809, build 17763) or later, on an x64 PC or an ARM64 Windows 11 PC. Your system doesn't meet this requirement.

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; Map .pensine -> ProgId
Root: HKA; Subkey: "Software\Classes\.pensine"; ValueType: string; ValueName: ""; ValueData: "{#ProgId}"; Flags: uninsdeletevalue
; ProgId definition
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Pensine Workspace"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""
; Surface in the Explorer "Open with" list
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".pensine"; ValueData: ""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
