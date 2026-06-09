# Publicar o ASAPainel na Google Play

Guia passo a passo para clonar o projeto, abrir no Android Studio, configurar as
chaves de assinatura e gerar o build (`.aab`) que será enviado para a Google Play.

> Pré-requisitos: ter o **Android Studio** instalado (com o plugin do Flutter) e o
> **Flutter SDK** configurado no PATH. Para conferir, rode `flutter doctor`.

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

## 3. Criar a chave de assinatura (keystore)

A chave é o que identifica você como dono do app na loja. **Crie uma vez e
guarde com muito cuidado** — se perder, não consegue mais atualizar o app.

No terminal, rode (ajuste o caminho/senha):

```bash
keytool -genkey -v -keystore beepainel-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias beepainel
```

- Vai pedir uma **senha** e alguns dados (nome, organização, etc.).
- Será gerado o arquivo **`beepainel-release.jks`**.
- Guarde esse arquivo e as senhas em local seguro (fora do Git).

> O comando `keytool` vem com o Java/JDK que acompanha o Android Studio. Se não
> for reconhecido, ele costuma estar em
> `C:\Program Files\Android\Android Studio\jbr\bin`.

---

## 4. Apontar o projeto para a chave

### 4.1. Criar o arquivo `android/key.properties`

Crie o arquivo **`android/key.properties`** com o conteúdo abaixo (substitua
pelos seus valores e pelo caminho real do `.jks`):

```properties
storePassword=SUA_SENHA_DO_KEYSTORE
keyPassword=SUA_SENHA_DA_CHAVE
keyAlias=beepainel
storeFile=C:/caminho/para/beepainel-release.jks
```

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

- [ ] `flutter doctor` sem erros
- [ ] `flutter pub get` executado
- [ ] Keystore `.jks` criado e guardado em local seguro
- [ ] `android/key.properties` preenchido (e fora do Git)
- [ ] `build.gradle.kts` apontando para a chave de release
- [ ] Versão atualizada no `pubspec.yaml`
- [ ] `flutter build appbundle --release` gerou o `.aab`
- [ ] `.aab` enviado no Play Console
