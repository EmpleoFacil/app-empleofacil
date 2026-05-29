# Guía desde cero para correr la app (Flutter)

Esta guía te explica cómo preparar tu entorno y ejecutar la app en:
- Un emulador Android
- Tu celular físico

## 1) Requisitos previos

- Git instalado
- Editor recomendado: VS Code o Android Studio
- Espacio libre en disco (mínimo ~10 GB)

## 2) Instalar Flutter

1. Ve a la guía oficial: https://docs.flutter.dev/get-started/install
2. Descarga Flutter para tu sistema operativo (Windows, macOS o Linux).
3. Descomprime el SDK de Flutter en una carpeta fija (por ejemplo `C:\src\flutter` o `~/development/flutter`).
4. Agrega `flutter/bin` al `PATH` del sistema.
5. Abre una terminal nueva y valida:

```bash
flutter --version
flutter doctor
```

6. Sigue lo que indique `flutter doctor` hasta que no tengas errores críticos.

## 3) Instalar Android Studio y crear un emulador

1. Instala Android Studio: https://developer.android.com/studio
2. Durante la instalación, asegúrate de incluir:
   - Android SDK
   - Android SDK Platform-Tools
   - Android Emulator
3. Abre Android Studio > **More Actions** > **SDK Manager** y verifica que todo esté instalado.
4. Ve a **Device Manager** > **Create Device**.
5. Elige un dispositivo (ej. Pixel) y descarga una imagen de sistema Android.
6. Inicia el emulador.
7. Verifica que Flutter lo detecte:

```bash
flutter devices
```

## 4) Usar tu celular físico (Android)

1. En tu celular, activa **Opciones de desarrollador** (tocando varias veces “Número de compilación”).
2. Activa **Depuración por USB**.
3. Conecta el celular por cable USB a tu computadora.
4. Acepta en el celular el permiso de depuración cuando aparezca.
5. Verifica conexión:

```bash
flutter devices
```

Si no aparece el dispositivo:
- Cambia el modo USB a “Transferencia de archivos”.
- Instala drivers USB del fabricante (Windows).
- Ejecuta `flutter doctor` para ver qué falta.

## 5) Clonar e iniciar el proyecto

En terminal:

```bash
git clone <URL_DEL_REPOSITORIO>
cd <NOMBRE_DEL_REPOSITORIO>
flutter pub get
```

## 6) Ejecutar la app

Con emulador abierto o celular conectado:

```bash
flutter run
```

Si tienes varios dispositivos:

```bash
flutter devices
flutter run -d <DEVICE_ID>
```

## 7) Comandos útiles

```bash
flutter doctor
flutter clean
flutter pub get
flutter test
```

## 8) Nota del proyecto

Este proyecto usa Flutter/Dart (ver `pubspec.yaml`) y requiere tener Flutter correctamente instalado para poder analizar, probar y ejecutar la app.
