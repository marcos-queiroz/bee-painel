# TODO — Roadmap de Implementação (KioskWeb)

Checklist por fase. Cada item referencia o SDD correspondente. Marque `[x]` ao
concluir. O **objetivo da Fase 0–4 é um build Windows funcional** que valida o
problema central da narração (RF-07).

---

> **Status:** Fases 0–6 implementadas e build Windows validado (jun/2026).
> App `BeePainel` (org `com.beepainel`). Executável em
> `build\windows\x64\runner\Release\beepainel.exe`.

## Fase 0 — Bootstrap do projeto
- [x] `flutter create --platforms=android,windows --org com.beepainel --project-name beepainel .`
- [x] Confirmar `flutter doctor` verde para Windows (VS2019 BuildTools + C++)
- [x] Adicionar dependências do [SDD-002 §3](./SDD-002-arquitetura.md#dependências)
- [x] Criar estrutura de pastas conforme [SDD-002 §2](./SDD-002-arquitetura.md)
- [x] Configurar `assets/` no `pubspec.yaml` (js/ + test/)
- [x] Habilitar Developer Mode + instalar `nuget.exe` (ver [SDD-005 §1.1.1](./SDD-005-plataformas-e-build.md))

## Fase 1 — Dados e configuração
- [x] `PrefsSource` (wrapper de `shared_preferences`)
- [x] Modelos `KioskConfig`, `RecentUrl` (+ (de)serialização JSON)
- [x] `KioskSettingsRepository` (load/save config, add recente, fixar/desafixar)
- [x] Providers Riverpod (`kioskConfigProvider` = `NotifierProvider`)
- [x] Roteamento `go_router` com redirect do splash ([SDD-004 §1](./SDD-004-modo-kiosque-e-navegacao.md))

## Fase 2 — Telas básicas
- [x] `HomeScreen`: campo de URL + normalização + validação
- [x] Abrir URL → `KioskScreen`
- [x] Toggle "Fixar URL" persistindo `pinnedUrl` + `autoStart`
- [x] Lista de recentes
- [x] Reinício abre direto na URL fixada (redirect no router)

## Fase 3 — WebView: persistência e autoplay ([SDD-003](./SDD-003-webview-e-ponte-tts.md))
- [x] `InAppWebView` (flutter_inappwebview) integrado
- [x] Aplicar `InAppWebViewSettings` (autoplay, domStorage, databaseEnabled, cache)
- [x] `StorageService` (limpar cookies/cache)
- [ ] Windows: definir user data folder persistente explícita (hoje usa padrão do WebView2)
- [ ] Validar manualmente: login em sistema web persiste após reiniciar (RF-05)
- [ ] Validar manualmente: `<audio>/<video>` autoplay sem gesto (RF-06)

## Fase 4 — Ponte de TTS (núcleo — RF-07) ⭐
- [x] `assets/js/speech_polyfill.js` conforme [SDD-003 §4](./SDD-003-webview-e-ponte-tts.md)
- [x] Injetar polyfill como `UserScript` em `AT_DOCUMENT_START`
- [x] `TtsService` sobre `flutter_tts` (init, fila de ids, mapeamento de rate)
- [x] `WebViewBridgeService`: handlers `tts.speak/cancel/pause/resume/getVoices`
- [x] Callbacks `onComplete/onError` → `__ttsBridge.fireEnd/fireError`
- [x] `getVoices` → `__ttsBridge.setVoices`
- [x] Página de teste `assets/test/senha_demo.html` (botão "demo de senha" na Home)
- [ ] **Validar narração no Windows** com a página de senha (critério de aceite #5)

## Fase 5 — Modo kiosque e gesto de saída ([SDD-004](./SDD-004-modo-kiosque-e-navegacao.md))
- [x] `KioskModeService` + impl Windows (`window_manager` fullscreen/frameless) e Android (`immersiveSticky`)
- [x] `wakelock_plus` ligado no kiosque
- [x] `shouldOverrideUrlLoading`: travar origem inicial, bloquear esquemas externos
- [x] `ErrorOverlay` + retry com backoff + reload por conectividade (`connectivity_plus`)
- [x] Controle visível de saída (`KioskControls`: Configurações / Tela inicial / Fechar) + gesto oculto (5 toques no canto superior esquerdo)
- [x] Encerrar app (`KioskModeService.quitApp`): `windowManager.destroy()` (desktop) / `SystemNavigator.pop()` (Android)
- [x] `PinDialog` + hash de PIN (`crypto`) opcional
- [x] `SettingsScreen` (trocar/desafixar URL, toggles, limpar dados, definir PIN)
- [ ] Windows: `setPreventClose` + confirmação ao fechar (pendente)
- [ ] Atalho de teclado de saída (`Ctrl+Shift+Q`) além do gesto de canto (pendente)

## Fase 6 — Build Windows de teste (META INICIAL) 🎯
- [x] `flutter build windows --release` → `beepainel.exe` gerado
- [x] Smoke test: executável inicia sem crash
- [ ] Checklist de aceite manual ([SDD-001 §8](./SDD-001-visao-geral.md)) no Windows:
  - [ ] Digitar URL e carregar em tela cheia
  - [ ] Fixar, reiniciar, abrir direto na URL
  - [ ] Login persiste após reiniciar
  - [ ] Autoplay de áudio funciona
  - [ ] Sistema de senha **narra com voz** (RF-07) — usar botão "demo de senha"
- [ ] Documentar requisito do WebView2 Runtime para distribuição

## Fase 7 — Android TV ([SDD-005 §2](./SDD-005-plataformas-e-build.md))
- [ ] Manifesto: `LEANBACK_LAUNCHER`, `leanback` required, touchscreen não-required
- [ ] Banner de TV `@drawable/tv_banner` (320x180)
- [ ] Impl `KioskModeService` Android (`immersiveSticky`, interceptar Voltar)
- [ ] Navegação D-pad na Home (`FocusTraversalGroup`, `Shortcuts/Actions`)
- [ ] **Validar narração no Android TV físico** (motor TTS instalado) — RF-07
- [ ] Validar persistência de localStorage no WebView da TV
- [ ] `flutter build apk --release` + sideload via ADB

## Fase 8 — Hardening e distribuição (opcional/futuro)
- [ ] Windows: documentar Assigned Access (kiosk de SO)
- [ ] Android: Lock Task / Device Owner (provisionamento) — opcional
- [ ] Empacotamento Windows (MSIX/Inno) com WebView2 bootstrapper
- [ ] Tela de erro amigável + logs
- [ ] (Futuro) configuração remota/MDM da URL fixada

---

## Critérios de "pronto" da v1
1. Build Windows release executável validado (Fase 6). 
2. Narração funcionando em Windows **e** Android TV (RF-07).
3. URL fixada com auto-start e persistência de login.
4. Saída do kiosque protegida por gesto/PIN.

## Decisões em aberto (confirmar na implementação)
- [ ] Confirmar suporte Windows do `flutter_inappwebview` na versão escolhida;
      senão acionar plano B `webview_windows` ([SDD-002 §3](./SDD-002-arquitetura.md)).
- [ ] Definir gesto/atalho de saída padrão final (e se PIN é obrigatório).
- [ ] Definir política `lockToInitialOrigin` (travar domínio) como on/off padrão.
- [ ] Nome/identidade do app e `applicationId`/`org`.
