# KioskWeb — Documentação de Arquitetura

Aplicativo Flutter que funciona como um **navegador em modo kiosque** para
**Android TV** e **Windows**. O usuário informa uma URL na tela inicial, o app
a abre em tela cheia (kiosque) e permite **fixá-la** — de modo que, nas próximas
inicializações, o app abre direto naquela URL.

O grande desafio resolvido por esta arquitetura: os WebViews embutidos em
Smart TVs com Android **não suportam a Web Speech API** (`speechSynthesis`),
usada por sistemas web de chamada de senha/narração. A solução é uma **ponte
de TTS nativa** (Flutter `flutter_tts`) com um **polyfill JavaScript** que
substitui `window.speechSynthesis` dentro do WebView.

## Índice dos documentos

| Documento | Conteúdo |
|-----------|----------|
| [SDD-001 — Visão Geral e Escopo](./SDD-001-visao-geral.md) | Objetivos, requisitos funcionais/não-funcionais, personas, glossário |
| [SDD-002 — Arquitetura Geral](./SDD-002-arquitetura.md) | Camadas, estrutura de pastas, dependências, fluxo do app, modelos de dados |
| [SDD-003 — WebView e Ponte de TTS](./SDD-003-webview-e-ponte-tts.md) | Configuração do WebView, localStorage, autoplay e a ponte de narração (núcleo técnico) |
| [SDD-004 — Modo Kiosque e Navegação](./SDD-004-modo-kiosque-e-navegacao.md) | Tela cheia, fixar URL, gesto de saída, navegação por D-pad |
| [SDD-005 — Plataformas e Build](./SDD-005-plataformas-e-build.md) | Especificidades de Android TV e Windows, requisitos e instruções de build |
| [TODO.md](./TODO.md) | Roadmap de implementação com checklist por fase |

## Resumo das decisões técnicas

- **Framework:** Flutter (canal stable 3.41.x, Dart 3.11.x).
- **WebView:** [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview) v6+ (Android + Windows/WebView2), escolhido por suportar injeção de scripts no início do documento, handlers JS bidirecionais e configuração fina de mídia/armazenamento.
- **TTS nativo:** [`flutter_tts`](https://pub.dev/packages/flutter_tts) para Android e Windows.
- **Persistência de config:** [`shared_preferences`](https://pub.dev/packages/shared_preferences).
- **Estado/DI:** [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod).
- **Janela/kiosque desktop:** [`window_manager`](https://pub.dev/packages/window_manager) + manter tela ligada com [`wakelock_plus`](https://pub.dev/packages/wakelock_plus).

> As versões exatas dos pacotes estão consolidadas no [SDD-002](./SDD-002-arquitetura.md#dependências) e devem ser confirmadas no pub.dev no momento da implementação.

## Status

Fase de **arquitetura / planejamento**. A implementação segue o [TODO.md](./TODO.md).
O primeiro alvo de build para testes é **Windows** (`flutter build windows`).
