!define APP_NAME "EduTrek_School_Management_System"
!define APP_VERSION "1.0.0"
!define APP_EXECUTABLE "Edutrek (2).exe"

Function CheckPreviousVersion
    ReadRegStr $0 HKLM "Software\${APP_NAME}" "Version"
    StrCmp $0 "${APP_VERSION}" 0 install
    MessageBox MB_OK "${APP_NAME} is already up-to-date."
    Abort
install:
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"
FunctionEnd

SetCompressor lzma

Name "${APP_NAME}"
OutFile "installer_${APP_NAME}_${APP_VERSION}.exe" ; Include version in the installer name
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin

LicenseData "InstallerFiles\user_agreement.txt" ; Bundled license file
Page license
Page directory
Page instfiles

Section "Install or Update"
    ; Set installation directory
    SetOutPath "$INSTDIR"

    ; Copy app files
    File /r "C:\Users\mano\3D Objects\softwares\New folder\zitf_system\build\windows\x64\runner\Release\*.*"

    ; Preserve user data
   ; IfFileExists "$INSTDIR\data\*.*" skipData
    ;    File /r "C:\Users\mano\3D Objects\softwares\New folder\zitf_system\lib\NSIS SCRIPTS\InstallerFiles\Data*.*"
;skipData:

    ; Create desktop shortcut
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXECUTABLE}"

    ; Update registry
    WriteRegStr HKLM "Software\${APP_NAME}" "Version" "${APP_VERSION}"
SectionEnd

Section "Uninstall"
    ; Remove app executable
    Delete "$INSTDIR\${APP_EXECUTABLE}"

    ; Optionally preserve user data
    ; RMDir /r "$INSTDIR\data" ; Uncomment to delete user data

    ; Remove installation directory
    RMDir /r "$INSTDIR"

    ; Delete desktop shortcut
    Delete "$DESKTOP\${APP_NAME}.lnk"
SectionEnd
