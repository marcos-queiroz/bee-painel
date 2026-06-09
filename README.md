# ASAPainel

Navegador em **modo kiosque** para **Android TV** e **Windows**, feito em Flutter.
O operador informa uma URL, ela abre em tela cheia e pode ser **fixada** para
abrir automaticamente nas próximas inicializações.

Recurso central: **narração (Web Speech API) que funciona mesmo em WebViews de
Smart TV que não suportam `speechSynthesis`**, via uma ponte de TTS nativa
(polyfill JS → `flutter_tts`).

A arquitetura completa está em [`.docs/`](./.docs/README.md).

## Estrutura
- `lib/` — código do app (camadas em `core/`, `data/`, `application/`, `services/`, `features/`).
- `assets/js/speech_polyfill.js` — polyfill da narração injetado no WebView.
- `assets/test/senha_demo.html` — página de teste do sistema de senha (narração + localStorage).

## Pré-requisitos (Windows)
1. Flutter stable (validado: 3.41.x).
2. Visual Studio (Build Tools) com workload **Desktop development with C++**.
3. **WebView2 Runtime** (já presente no Windows 11; senão instalar o Evergreen).
4. **Developer Mode** habilitado (`start ms-settings:developers`).
5. **`nuget.exe`** no PATH (exigido pelos plugins de WebView/TTS). Ver
   [`.docs/SDD-005`](./.docs/SDD-005-plataformas-e-build.md#111-pré-requisitos-de-build-descobertos-na-implementação).

## Rodar (desenvolvimento)
```powershell
flutter pub get
flutter run -d windows
```

## Build de release (Windows)
```powershell
flutter build windows --release
```
Saída: `build\windows\x64\runner\Release\beepainel.exe` (com DLLs e `data\`).

## Testes
```powershell
flutter test
flutter analyze
```

## Uso rápido
1. Na tela inicial, digite uma URL (ou use **"Abrir demo de senha"** para testar a narração).
2. Marque **"Fixar esta URL"** para auto-abrir nas próximas execuções.
3. Para sair/fechar: use o **controle no canto superior direito** (menu →
   Configurações / Tela inicial / Fechar ASAPainel). Alternativa oculta: **5
   toques no canto superior esquerdo** em até 3s. A saída pode ser protegida por
   PIN (configurável em Configurações).
