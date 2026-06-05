# SDD-001 — Visão Geral e Escopo

## 1. Objetivo

Construir um aplicativo **Flutter** multiplataforma (**Android TV** e **Windows
Desktop**) que se comporta como um **navegador kiosque dinâmico**:

1. Na primeira execução, exibe uma **tela inicial** onde o operador digita uma URL.
2. A URL é aberta em **modo kiosque** (tela cheia, sem barras de navegação).
3. O operador pode **fixar (pin)** a URL. Quando fixada, o app passa a abrir
   automaticamente naquela URL em toda inicialização, sem passar pela tela inicial.
4. Um **gesto/atalho oculto** permite voltar à tela de configuração (opcionalmente
   protegido por PIN) para trocar ou desafixar a URL.

O app é essencialmente um **WebView gerenciado** com recursos extras de quiosque,
persistência e — o ponto central — **narração por voz (TTS)** que funciona mesmo
em dispositivos cujo WebView não suporta a Web Speech API.

## 2. Contexto e problema

Sistemas web de atendimento (ex.: **chamada de senhas**, painéis, totens)
costumam usar a **Web Speech API** (`window.speechSynthesis`) do navegador para
narrar ("Senha 042, guichê 3"). Em **Smart TVs com Android**, o WebView do
sistema (System WebView / navegador embutido) frequentemente **não implementa**
`speechSynthesis`, então a narração simplesmente não acontece.

Além disso, esses ambientes geralmente:
- **Bloqueiam autoplay de áudio** sem gesto do usuário.
- Têm **restrições de armazenamento** (localStorage/cookies podem ser voláteis).

Este projeto resolve os três pontos de forma nativa pelo app Flutter.

## 3. Requisitos funcionais

| ID | Requisito | Prioridade |
|----|-----------|------------|
| RF-01 | Tela inicial para o usuário digitar uma URL e abri-la. | Must |
| RF-02 | Abrir a URL em modo kiosque (tela cheia, sem chrome do navegador). | Must |
| RF-03 | Fixar a URL para que o app abra direto nela nas próximas execuções. | Must |
| RF-04 | Desafixar / trocar a URL via tela de configuração. | Must |
| RF-05 | Persistir `localStorage`, `sessionStorage` (best-effort), cookies e IndexedDB para manter autenticação do sistema web entre sessões. | Must |
| RF-06 | Permitir **autoplay de áudio** sem gesto do usuário. | Must |
| RF-07 | Suportar **narração (`speechSynthesis`)** do sistema web, inclusive em WebViews que não a implementam (ponte TTS nativa). | Must |
| RF-08 | Atalho/gesto oculto para sair do kiosque e voltar à configuração. | Must |
| RF-09 | Proteção opcional por PIN para sair do kiosque. | Should |
| RF-10 | Manter a tela ligada (anti screensaver) enquanto em kiosque. | Should |
| RF-11 | Recarregar/“tela de erro” amigável em caso de falha de rede, com retry automático. | Should |
| RF-12 | Histórico/lista de URLs recentes na tela inicial. | Could |
| RF-13 | Navegação por controle remoto (D-pad) na tela inicial (Android TV). | Should |

## 4. Requisitos não-funcionais

| ID | Requisito |
|----|-----------|
| RNF-01 | **Plataformas-alvo:** Android TV (API 21+) e Windows 10/11 (x64). |
| RNF-02 | **Resiliência:** recuperação automática após perda/retorno de rede. |
| RNF-03 | **Desempenho:** inicialização até o WebView em < 3 s no alvo fixado. |
| RNF-04 | **Manutenibilidade:** arquitetura em camadas, dependências isoladas em serviços. |
| RNF-05 | **Acessibilidade da narração:** latência da fala < 500 ms após chamada `speak()`. |
| RNF-06 | **Segurança:** PIN de saída não armazenado em texto puro; HTTPS recomendado. |
| RNF-07 | **Build de teste inicial:** Windows release funcional. |

## 5. Fora de escopo (v1)

- Múltiplas abas / gerenciamento de janelas.
- Bloqueio de propaganda / extensões.
- Sincronização de configuração na nuvem (MDM) — previsto como evolução futura.
- iOS, macOS, Linux, Web (a arquitetura não impede, mas não são alvos da v1).

## 6. Personas

- **Operador/Instalador:** configura a TV/PC uma vez (digita e fixa a URL).
- **Usuário final:** apenas vê o conteúdo em kiosque (ex.: painel de senhas);
  não interage com a configuração.

## 7. Glossário

| Termo | Definição |
|-------|-----------|
| **Kiosque** | Modo tela cheia bloqueado, sem acesso ao SO ou a outros apps/URLs. |
| **URL fixada (pinned)** | URL salva que vira o destino automático na inicialização. |
| **TTS** | *Text-to-Speech* — síntese de fala. |
| **Web Speech API** | API do navegador (`speechSynthesis` / `SpeechSynthesisUtterance`) para TTS. |
| **Ponte TTS** | Mecanismo que conecta chamadas JS de narração ao TTS nativo do Flutter. |
| **Polyfill** | Código JS injetado que implementa uma API ausente no WebView. |
| **WebView2** | Runtime Chromium da Microsoft usado pelo WebView no Windows. |
| **Leanback** | Conjunto de APIs/manifesto que identifica o app como app de TV no Android. |

## 8. Critérios de aceite (v1)

1. Digitar uma URL e vê-la carregar em tela cheia (Windows e Android TV).
2. Fixar a URL, reiniciar o app e ser levado direto à URL fixada.
3. Login no sistema web persiste após reiniciar o app (RF-05).
4. Áudio/vídeo do sistema web toca sem clique inicial (RF-06).
5. Um sistema de senha que use `speechSynthesis.speak(...)` **narra com voz**
   tanto no Windows quanto no Android TV (RF-07) — validação do problema central.
6. Build `flutter build windows --release` gerado e executável.
