# Publicar o ASAPainel na Google Play

Guia passo a passo para clonar o projeto, abrir no Android Studio, configurar as
chaves de assinatura e gerar o build (`.aab`) que será enviado para a Google Play.

> **Você já publica apps Android e já tem a sua keystore, mas trabalha com Ionic?**
> Então só falta preparar o ambiente **Flutter** — este projeto é em Flutter, não
> em Ionic/Capacitor. Comece pela seção **0** abaixo e, na hora da chave, é só
> reaproveitar a sua (a criação na seção 3 é opcional).

---

## 0. Preparar o ambiente Flutter (quem vem do Ionic)

No mundo Ionic você builda com Node + Capacitor/Cordova (`npx cap ...`). No
Flutter, o build é feito pelo **Flutter SDK** (comando `flutter`). A boa notícia:
o que você já usa para Android no Ionic é reaproveitado — **Android Studio,
Android SDK, JDK e a sua keystore**. O que falta instalar é o **Flutter SDK**.

**O que você já deve ter (do Ionic):**
- Git
- Android Studio + Android SDK
- JDK 17 (acompanha o Android Studio)
- Keystore de assinatura (você já tem)

**O que falta instalar — Flutter SDK (macOS):**

1. Instale o Flutter SDK. A forma mais simples é com o **Homebrew**:

```bash
brew install --cask flutter
```

   Alternativa manual: baixe pelo guia oficial
   <https://docs.flutter.dev/get-started/install/macos/mobile-android> e
   descompacte em uma pasta, ex.: `~/development/flutter`.

2. Se instalou manualmente, adicione o Flutter ao **PATH** no seu shell
   (no Mac o padrão é o **zsh** → arquivo `~/.zshrc`):

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

   (Com o Homebrew o `flutter` já fica no PATH automaticamente.)

3. Abra o **Android Studio** e instale os plugins **Flutter** e **Dart**
   (**Settings → Plugins → Marketplace**).
4. Aceite as licenças do Android SDK:

```bash
flutter doctor --android-licenses
```

5. Valide o ambiente:

```bash
flutter doctor
```

Para publicar no Android, estes itens precisam aparecer com **[✓]**: *Flutter*,
*Android toolchain* e *Android Studio*. Os itens de *Xcode/iOS* só importam se um
dia você também for publicar para iPhone — podem ser ignorados por enquanto.

---

## 1. Clonar o projeto

```bash
git clone git@github.com:marcos-queiroz/bee-painel.git
cd bee-painel
```

Se você usa HTTPS em vez de SSH:

```bash
git clone https://github.com/marcos-queiroz/bee-painel.git
cd bee-painel
```

---

## 2. Abrir no Android Studio

1. Abra o **Android Studio**.
2. **File → Open** e selecione a pasta do projeto (`bee-painel`).
3. Aguarde o Android Studio indexar e baixar as dependências.
4. Baixe os pacotes do Flutter pelo terminal embutido (**View → Tool Windows →
   Terminal**):

```bash
flutter pub get
```

---

## 3. Criar a chave de assinatura (keystore) — *opcional*

> **Já tem uma keystore?** Pule esta seção e vá direto para a **seção 4**,
> reaproveitando o seu `.jks`/`.keystore` e as senhas que você já usa nos seus
> apps Ionic. (Use a sua chave de **upload** se você usa o Play App Signing.)

A chave é o que identifica você como dono do app na loja. **Crie uma vez e
guarde com muito cuidado** — se perder, não consegue mais atualizar o app.

No terminal, rode (ajuste o caminho/senha):

```bash
keytool -genkey -v -keystore ~/keys/asapainel-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias asapainel
```

- Vai pedir uma **senha** e alguns dados (nome, organização, etc.).
- Será gerado o arquivo **`asapainel-release.jks`** (em `~/keys/`, neste exemplo).
- Guarde esse arquivo e as senhas em local seguro (fora do Git).

> O comando `keytool` vem com o Java/JDK que acompanha o Android Studio. Se não
> for reconhecido no Mac, use o caminho completo:
> `/Applications/Android\ Studio.app/Contents/jbr/Contents/Home/bin/keytool`.

---

## 4. Apontar o projeto para a chave

### 4.1. Criar o arquivo `android/key.properties`

Crie o arquivo **`android/key.properties`** com o conteúdo abaixo (substitua
pelos seus valores e pelo caminho real do `.jks`):

```properties
storePassword=SUA_SENHA_DO_KEYSTORE
keyPassword=SUA_SENHA_DA_CHAVE
keyAlias=beepainel
storeFile=/Users/SEU_USUARIO/keys/asapainel-release.jks
```

> No macOS use o caminho absoluto do arquivo (ex.: `/Users/...`). Você pode
> descobrir o caminho com `pwd` na pasta onde está o `.jks`.

> **Importante:** nunca suba o `key.properties` nem o `.jks` para o Git. Confira
> se ambos estão no `.gitignore`.

### 4.2. Configurar a assinatura no `android/app/build.gradle.kts`

Hoje o build de release está assinado com a chave de **debug** (não serve para a
loja). Edite o arquivo **`android/app/build.gradle.kts`** assim:

**a) No topo do arquivo**, logo após o bloco `plugins { ... }`, adicione o
carregamento do `key.properties`:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

**b) Dentro do bloco `android { ... }`**, adicione um `signingConfigs` e troque o
`signingConfig` do `release` para usar a nova configuração:

```kotlin
android {
    // ... namespace, compileSdk, etc. (mantenha como está) ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

## 5. Ajustar nome e versão do app

- **Nome exibido / ID do app:** o ID é `com.beepainel.beepainel`
  (em `android/app/build.gradle.kts`, campo `applicationId`). Defina o ID
  definitivo **antes** do primeiro envio — ele não pode mudar depois.
- **Versão:** ajuste em `pubspec.yaml`, na linha:

```yaml
version: 1.0.0+1
```

O formato é `versionName+versionCode`. A cada novo envio para a loja, aumente o
número **depois do `+`** (ex.: `1.0.1+2`).

---

## 6. Gerar o build para a loja (App Bundle `.aab`)

A Google Play exige o formato **App Bundle (`.aab`)**.

```bash
flutter build appbundle --release
```

Arquivo gerado em:

```
build/app/outputs/bundle/release/app-release.aab
```

> Para gerar um `.apk` (testes ou instalação direta, não para a loja):
> `flutter build apk --release`

---

## 7. Enviar para a Google Play

1. Acesse o **[Google Play Console](https://play.google.com/console)** (precisa
   de conta de desenvolvedor, taxa única de US$ 25).
2. **Criar app** → preencha nome, idioma e tipo.
3. Preencha as seções obrigatórias: classificação de conteúdo, política de
   privacidade, público-alvo, ficha da loja (descrição, ícone, capturas de tela).
4. Vá em **Versões → Produção** (ou faça primeiro um teste em **Testes internos**).
5. **Criar nova versão** e faça o upload do arquivo
   `app-release.aab`.
6. Revise e **envie para análise**. A aprovação costuma levar de algumas horas a
   alguns dias.

> Recomendado: ative o **Play App Signing** (a Google guarda a chave de
> distribuição e você mantém a sua chave de upload). É a opção padrão e mais
> segura.

---

## Checklist rápido

- [ ] Flutter SDK instalado e no PATH (seção 0)
- [ ] `flutter doctor` OK em Flutter, Android toolchain e Android Studio
- [ ] `flutter pub get` executado
- [ ] Keystore em mãos (a sua já existente) e guardada em local seguro
- [ ] `android/key.properties` preenchido (e fora do Git)
- [ ] `build.gradle.kts` apontando para a chave de release
- [ ] Versão atualizada no `pubspec.yaml`
- [ ] `flutter build appbundle --release` gerou o `.aab`
- [ ] `.aab` enviado no Play Console
