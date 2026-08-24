; Snipster for Windows — Inno Setup script
;
; Installs entirely in per-user space (PrivilegesRequired=lowest forces this,
; and {autopf} then resolves to %LOCALAPPDATA%\Programs instead of
; Program Files) so it never prompts for admin/UAC elevation and works for
; any standard user account, including ones without local admin rights.

#define MyAppName "Snipster"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Alan Ramos"
#define MyAppExeName "Snipster.exe"

[Setup]
AppId={{8F1B7A2E-5C3D-4E1A-9B6F-2D4A7C8E1F30}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; The single setting that makes this a no-admin, per-user install: Setup
; never requests elevation, and every {auto*} path below resolves to the
; current user's own profile instead of a machine-wide location.
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=Snipster-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\publish\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// Snipster manages its own "launch at startup" HKCU Run entry from within
// its Preferences window; if it's set, clean it up on uninstall so a
// deleted exe doesn't leave a dangling startup entry behind.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Snipster');
end;
