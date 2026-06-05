# SDD-005 — Plataformas e Build

Especificidades de **Android TV** e **Windows**, requisitos de runtime e
instruções de build. O alvo de testes inicial é **Windows**.

---

## 1. Windows (alvo de teste inicial)

### 1.1 Requisitos de runtime
- **WebView2 Runtime (Evergreen)** instalado. Já vem no Windows 11 e na maioria
  dos Windows 10 atualizados; caso ausente, instalar o *Evergreen Bootstrapper*
  da Microsoft. Documentar isso no README de distribuição.
- Visual C++ Redistributable (normalmente já presente).

### 1.1.1 Pré-requisitos de build (descobertos na implementação)
Os plugins `flutter_inappwebview_windows` e `flutter_tts` exigem **`nuget.exe`**
no PATH durante o build. Instalação usada:
```powershell
$dir = "$env:LOCALAPPDATA\nuget"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile "$dir\nuget.exe"
# adicionar $dir ao PATH (sessão + usuário)
```
Também é necessário **Developer Mode** do Windows (suporte a symlink dos plugins):
`start ms-settings:developers` (ou habilitar via registro `AppModelUnlock`).

**Correção do prefixo de instalação:** com o CMake 3.20 embutido no VS2019, o
guard `CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT` em `windows/CMakeLists.txt`
não dispara, e o `install` cai em `C:/Program Files/<app>` (exige admin e quebra
o bundle). Ajuste aplicado no projeto força o prefixo para o diretório do runner:
```cmake
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT OR
   CMAKE_INSTALL_PREFIX MATCHES "Program Files")
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()
```
Alternativa de longo prazo: atualizar para VS2022 (CMake mais recente).

### 1.2 Configuração do projeto
- `flutter config --enable-windows-desktop` (geralmente já habilitado).
- `windows/runner` é gerado por `flutter create`.
- **User data folder do WebView2:** definir caminho persistente (ex.:
  `getApplicationSupportDirectory()/webview`) para preservar login (RF-05).
- Janela: `window_manager` para fullscreen/sem moldura (ver SDD-004 §4).

### 1.3 Build de teste
```powershell
flutter pub get
flutter build windows --release
```
Saída: `build\windows\x64\runner\Release\` (contém o `.exe` + DLLs).
Para rodar em modo dev:
```powershell
flutter run -d windows
```

### 1.4 Kiosque "duro" (opcional, nível SO)
Para travar o Windows no app (impedir Alt+Tab, etc.), usar **Assigned Access /
Kiosk Mode** do Windows apontando para o `.exe` gerado, ou *Shell Launcher*.
Isso é configuração de SO, fora do código do app (ver SDD-004 §4).

### 1.5 Empacotamento (futuro)
- MSIX via [`msix`](https://pub.dev/packages/msix) para instalação simples, ou
- Inno Setup / instalador que também garanta o WebView2 Runtime.

---

## 2. Android TV

### 2.1 Manifesto (`android/app/src/main/AndroidManifest.xml`)
Pontos essenciais para um app de TV:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<!-- Manter tela ligada já é coberto por wakelock_plus; opcional WAKE_LOCK -->

<!-- TV não exige touchscreen: -->
<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
<uses-feature android:name="android.software.leanback" android:required="true"/>

<application ...
    android:banner="@drawable/tv_banner">
  <activity ... android:name=".MainActivity">
    <!-- Launcher padrão -->
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    <!-- Launcher de TV (Leanback) -->
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
    </intent-filter>
  </activity>
</application>
```
- **Banner** 320x180 (`tv_banner`) obrigatório para aparecer na home da TV.
- `minSdkVersion`: o `flutter_inappwebview` exige um mínimo recente; usar o
  default do Flutter (atualmente 21+) e validar.

### 2.2 TTS no Android TV
- Depende de um **motor TTS instalado** (ex.: Google TTS / Speech Services).
  Muitas TVs já têm; algumas não. **Validar no dispositivo-alvo.**
- Se não houver motor/idioma pt-BR, oferecer instrução para instalar e tratar
  `fireError` graciosamente.
- A ponte TTS (SDD-003) é o que faz a narração funcionar mesmo sem
  `speechSynthesis` no WebView.

### 2.3 Mídia / autoplay
- `mediaPlaybackRequiresUserGesture: false` (SDD-003 §2).
- Em alguns OEMs, verificar foco de áudio; testar áudio HTML separadamente do TTS.

### 2.4 Navegação por controle remoto
- D-pad e OK conforme SDD-004 §2; sem dependência de toque.

### 2.5 Build (fase posterior à validação Windows)
```bash
flutter build apk --release        # APK para sideload em TV
# ou
flutter build appbundle --release  # AAB para Play Store (faixa Android TV)
```
Sideload em TV: `adb connect <ip>` + `adb install app-release.apk`.

---

## 3. Matriz de capacidades por plataforma

| Capacidade | Android TV | Windows |
|------------|-----------|---------|
| WebView | `flutter_inappwebview` (System WebView) | `flutter_inappwebview` (WebView2) / plano B `webview_windows` |
| `speechSynthesis` nativo no WebView | ❌ frequentemente ausente | ✅ (Chromium) |
| Ponte TTS (flutter_tts) | ✅ **necessária** | ✅ (usada para consistência) |
| Autoplay áudio | ✅ via flag | ✅ via flag |
| localStorage/cookies persistentes | ✅ | ✅ (user data folder) |
| Fullscreen/imersivo | `immersiveSticky` | `window_manager` |
| Kiosque "duro" no SO | Lock Task (Device Owner) | Assigned Access |
| Manter tela ligada | `wakelock_plus` | `wakelock_plus` |

---

## 4. Configuração de ambiente de desenvolvimento

- Flutter stable (validado: **3.41.x**, Dart 3.11.x).
- **Windows:** Visual Studio com workload "Desktop development with C++".
- **Android:** Android SDK + (para TV física) ADB; emulador de Android TV
  opcional via AVD (perfil Android TV).
- `flutter doctor` deve estar verde para Windows antes do primeiro build.

---

## 5. Riscos por plataforma e mitigação

| Risco | Plataforma | Mitigação |
|-------|-----------|-----------|
| Suporte Windows do `flutter_inappwebview` ainda novo | Windows | Abstração `AppWebView` + plano B `webview_windows` |
| WebView2 Runtime ausente no PC alvo | Windows | Detectar e instruir/instalar bootstrapper |
| Motor TTS/idioma ausente na TV | Android TV | Detecção + mensagem; orientar instalação do Google TTS |
| OEM bloqueia autoplay mesmo com flag | Android TV | Áudio crítico vai pelo TTS nativo (não depende de autoplay) |
| Sair do kiosque sem Device Owner | Android TV | Aceitável p/ instalação controlada; hardening opcional |
| `localStorage` volátil em algum WebView | Android TV | Reforçar com cookies + IndexedDB; testar persistência no alvo |
