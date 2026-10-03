# Comunicación cotidiana

Adaptación a Flutter de los flujos de [AAC Board AI](https://github.com/shayc/aac-board-ai), ajustada al alcance de este proyecto: comunicación presencial con tarjetas y texto, perfiles independientes y datos locales en Android e iOS.

[Arquitectura en Google Drive](https://docs.google.com/document/d/1VQoBmbEhhIOqYEBMzwhAtZiAaosnx3qTCpTwpJTSXu4/edit) · [Arquitectura local](docs/arquitectura.md) · [Contrato del servicio de IA](docs/suggestion-service.md)

## Funciones incluidas

- Cuatro temas fijos: En casa, Tiempo libre, Comida y Cuidado diario.
- Dieciséis tarjetas iniciales, entrada de texto y tarjetas personales con foto.
- Lectura inmediata de cada tarjeta y reproducción manual del mensaje completo.
- Selección de sugerencias sin reproducción automática, con entrada original conservada.
- Acceso por correo/contraseña o Google mediante un adaptador Firebase.
- Varios perfiles por cuenta, aislados en la base SQLite de cada instalación.
- PIN local para la administración y anotación manual de ayuda humana en el historial.
- Adaptador HTTPS para sugerencias, sin claves de proveedor en el cliente.

Los datos de comunicación no se sincronizan ni se recuperan al cambiar de dispositivo. La autenticación utiliza un servicio en línea separado. El catálogo inicial requiere revisión con participantes; sus símbolos son provisionales.

## Estado de la entrega

El análisis estático y 18 verificaciones automatizadas pasan. Se compiló el APK de depuración Android. La compilación iOS quedó pendiente porque el Xcode disponible no tiene instalada la plataforma iOS 26.2 solicitada; CocoaPods sí resolvió las dependencias.

El APK de depuración permite entrar con «Probar sin iniciar sesión». Crea el perfil «Usuario de prueba» sin configurar Firebase. El inicio de sesión real requiere un proyecto Firebase y la configuración OAuth de Google. Las sugerencias reales requieren desplegar el servicio de IA. Estos servicios no fueron creados ni usados con credenciales reales durante la entrega.

## Probar ahora sin iniciar sesión

Instala el APK de depuración y toca **Probar sin iniciar sesión**. Se abrirá el tablero con el perfil **Usuario de prueba**, sus cuatro temas y las tarjetas incluidas. Puedes escribir, tocar tarjetas y agregar perfiles o tarjetas desde la administración. Al abrir la administración por primera vez, elige un PIN de seis números.

Los datos de prueba se conservan en la carpeta privada `communication_preview`, separada de la carpeta `communication` usada por las cuentas reales. Volver a entrar no duplica el perfil inicial. El botón de salida de la barra superior regresa al acceso. Las sugerencias de IA están desactivadas en esta vista; la voz utiliza el motor del dispositivo y requiere una voz es-MX instalada.

El acceso de prueba está limitado a compilaciones de depuración mediante `kDebugMode`. La versión de distribución sigue requiriendo autenticación.

## Preparar el acceso

Se utilizó Flutter 3.35.7 con Dart 3.9.2. Las versiones exactas están en `pubspec.lock`.

1. Crea o elige un proyecto Firebase y habilita Email/Password y Google en Authentication.
2. Registra Android con el identificador `mx.edu.comunicacion.comunicacion_cotidiana` e iOS con `mx.edu.comunicacion.comunicacionCotidiana`.
3. Copia `config/example.json` a `config/android.local.json` y a `config/ios.local.json`. Completa los valores de Firebase para cada aplicación. `FIREBASE_APP_ID` es distinto por plataforma.
4. Configura el cliente OAuth de Android con los certificados SHA de la firma utilizada. Indica el cliente web en `GOOGLE_WEB_CLIENT_ID` para obtener un token de identidad.
5. En iOS, proporciona `GOOGLE_IOS_CLIENT_ID` y agrega en `ios/Runner/Info.plist` el esquema de URL invertido de ese cliente, siguiendo la integración oficial de Google Sign-In.
6. Deja `SUGGESTION_ENDPOINT` vacío hasta tener un servicio HTTPS que cumpla el contrato. El tablero sigue siendo independiente de ese servicio.

Los valores Firebase que identifican la aplicación no sustituyen las reglas del servicio ni las credenciales privadas del proveedor de IA. No pongas esas credenciales privadas en los archivos de configuración móvil.

```sh
flutter pub get
flutter run --dart-define-from-file=config/android.local.json
```

Para iOS, utiliza `config/ios.local.json`. Consulta [Firebase Authentication para Flutter](https://firebase.google.com/docs/auth/flutter/start) y la [integración de Google Sign-In](https://pub.dev/packages/google_sign_in/versions/6.3.0).

## Voz y almacenamiento

Instala una voz es-MX en el dispositivo. Android filtra voces que requieren red. El funcionamiento sin conexión de la voz debe comprobarse en los equipos elegidos. Si falta una voz, el mensaje escrito permanece disponible.

SQLite y las fotos se guardan bajo `ApplicationSupport/communication`. Las fotos usan nombres relativos. El PIN se almacena como verificador PBKDF2 en el almacenamiento seguro del sistema. La base SQLite utiliza la protección del dispositivo y no agrega cifrado propio.

Android excluye los datos de las reglas de respaldo y transferencia. iOS marca la carpeta para excluirla de los respaldos. La sesión de acceso conservada permite abrir datos locales sin iniciar sesión de nuevo. Una instalación nueva empieza sin perfiles locales.

## Estructura

```text
lib/
  app/           Inicio, configuración y conexión de dependencias por cuenta
  application/   Estado de comunicación, permiso de gestión y alta de tarjetas
  domain/        Entidades e interfaces
  data/          SQLite, catálogo, autenticación, PIN, voz y cliente HTTPS
  ui/            Acceso, tablero, administración y formularios
docs/            Arquitectura y contrato del servicio de sugerencias
test/            Comportamientos de comunicación y separación de datos
```

## Verificar y compilar

```sh
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter build ios --simulator --debug
```

Android requiere un JDK compatible con Gradle 8.12, por ejemplo Java 21. La compilación realizada usó Java 21 para Gradle sin cambiar la configuración global. iOS requiere instalar la plataforma correspondiente en Xcode. La firma para distribución todavía debe configurarse; el proyecto no usa una firma de depuración como firma de publicación.

Las verificaciones cubren selección y reproducción, respuestas antiguas de IA, uso sin IA, acceso entre cuentas, tarjetas incluidas inmutables y conservación de la entrada original. No se verificaron con servicios reales el acceso, la generación de texto ni la voz de un dispositivo físico.

## Alcance pendiente de integración

Desplegar el servicio de sugerencias, configurar Firebase/Google, revisar el vocabulario, habilitar la firma de distribución y comprobar la galería, la voz y las exclusiones de respaldo en dispositivos reales. Esta versión no tiene restablecimiento de PIN, edición de tarjetas predefinidas, creación de temas, importación OBF/OBZ ni exportación o recuperación de datos.

La atribución de la referencia está en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
