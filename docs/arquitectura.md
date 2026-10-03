# Arquitectura de software

Comunicación cotidiana con Flutter

Este documento explica qué hace la aplicación, cómo se organiza y dónde guarda la información. Está dirigido al equipo que la desarrolla y a quienes necesitan revisar su alcance. La redacción sigue los principios de pertinencia, facilidad para encontrar información, comprensión y uso de ISO 24495-1:2023.

## 1. Propósito y alcance

La aplicación apoya la comunicación cotidiana de personas autistas de 3 a 22 años que cuentan con cierta capacidad de lectura y escritura. Permite expresar necesidades, preferencias y mensajes mediante tarjetas y texto, con reproducción por voz. Madres, padres y personas cuidadoras preparan los perfiles y agregan tarjetas personales.

Se desarrolla con Flutter para teléfonos y tabletas Android e iOS. Los temas iniciales son En casa, Tiempo libre, Comida y Cuidado diario. La persona cambia de tablero manualmente y conserva el control sobre lo que expresa.

El alcance incluye cinco módulos: perfiles y personalización; entrada mediante tarjetas y texto; sugerencias contextuales; selección y voz; e historial local. La inteligencia artificial es una ayuda opcional para formular mensajes. La comunicación básica también funciona sin solicitar sugerencias.

El proyecto se concentra en la interacción presencial cotidiana. Quedan fuera la mensajería a distancia, la enseñanza de lectoescritura, la interpretación continua del habla y la creación de escenarios particulares. Tampoco se ofrecen sincronización, respaldo en la nube ni recuperación de los datos locales.

## 2. Personas, cuentas y datos locales

### Una cuenta de acceso y varios perfiles

La cuenta pertenece a la madre, el padre o la persona cuidadora. El acceso admite correo y contraseña o Google. Dentro de esa cuenta se pueden crear varios perfiles locales, uno por cada persona que utiliza los tableros. Un perfil no necesita un correo ni una contraseña propios.

Cada perfil reúne sus tarjetas personales y sus registros de comunicación. El identificador de la cuenta delimita qué perfiles puede abrir cada sesión. La base de datos verifica esta relación al consultar tarjetas, guardar mensajes o leer el historial.

### Qué significa guardar los datos en el dispositivo

Los perfiles, las tarjetas personalizadas, las fotos y el historial se conservan en el almacenamiento privado de la aplicación. Una misma cuenta puede iniciar sesión en varios dispositivos; cada instalación mantiene información independiente. Iniciar sesión en otro equipo no transfiere esos datos.

Cerrar sesión conserva los datos en ese equipo. Volver a entrar con la misma cuenta permite abrirlos mientras la instalación siga intacta. Desinstalar la aplicación, borrar sus datos o reemplazar el dispositivo no tiene un mecanismo de recuperación dentro del proyecto.

La identidad de acceso sí utiliza un servicio en línea. En esta adaptación se eligió Firebase Authentication como decisión técnica para implementar correo, contraseña y Google. No se incorporaron Firestore ni Firebase Storage para guardar perfiles o mensajes.

### Administración protegida

Un PIN local de seis números protege la administración. Se configura por cuenta y por instalación. Se solicita para agregar perfiles, agregar tarjetas, consultar el historial y anotar la ayuda observada. La comunicación diaria permanece disponible sin pedir el PIN en cada mensaje.

La administración se bloquea al volver al tablero, cambiar de perfil, cerrar sesión o dejar la aplicación en segundo plano. El repositorio también comprueba el permiso antes de escribir; ocultar un botón no es el único control.

## 3. Organización de la aplicación

La estructura separa la interfaz, la coordinación de las acciones y el acceso a datos. En la pantalla de comunicación se usa un modelo de vista: un objeto que conserva el mensaje, las sugerencias y el estado de reproducción, y avisa a la pantalla cuando cambian.

Flujo principal: pantalla → BoardViewModel → interfaces de repositorio y servicios → SQLite, voz del dispositivo o servicio de sugerencias.

### Interfaz: lib/ui

AuthView muestra el acceso y el registro. BoardView presenta el perfil activo, los cuatro temas, las tarjetas, el texto, las sugerencias y el botón de reproducción. ManagementView permite agregar perfiles y tarjetas y consultar registros. PinDialog solicita o configura el PIN. Los formularios conservan localmente el estado visual, como campos, errores y botones ocupados.

Los controles usan etiquetas en español de México, áreas táctiles amplias y una distribución que cambia entre teléfono y tableta. Las tarjetas combinan texto con una imagen o símbolo. La confirmación visual de una sugerencia aparece antes de reproducirla.

### Coordinación: lib/application

BoardViewModel coordina la composición y la reproducción. Conserva por separado la entrada original y la sugerencia elegida. También descarta respuestas de IA que llegan después de modificar la entrada, cambiar de tema o cambiar de perfil.

ManagementGate controla si la administración está desbloqueada. AddCard coordina la copia de una foto y el guardado de la tarjeta. Si el permiso cambia o el guardado falla, retira la copia que esa operación haya creado para evitar archivos sin tarjeta.

### Reglas y contratos: lib/domain

Esta carpeta define UserProfile, CommunicationCard, BoardTheme e InteractionRecord. También define CommunicationRepository, SpeechService y SuggestionService: contratos que describen las operaciones necesarias sin depender de SQLite, Firebase o un proveedor de IA.

Los cuatro temas forman un catálogo cerrado. Las tarjetas incluidas se identifican como predefinidas y no se pueden modificar. Las tarjetas personales se agregan a uno de esos temas y pertenecen a un perfil.

### Persistencia e integraciones: lib/data

LocalCommunicationRepository aplica la separación de cuentas y perfiles. LocalStore abre SQLite, crea las tablas y administra archivos de fotos. AuthRepository encapsula el acceso con Firebase y Google. PinVault guarda el verificador del PIN. DeviceSpeechService reproduce texto con una voz instalada. HttpSuggestionService solicita alternativas mediante HTTPS.

### Inicio y dependencias: lib/app

AppConfig recibe los valores de configuración. AccountDependencies crea los objetos de una cuenta y los conecta entre sí. Al cambiar de cuenta se destruye ese conjunto y se crea otro, para que el mensaje en curso y las respuestas pendientes no pasen a otra sesión.

La interfaz no ejecuta consultas SQL ni conoce las claves de un proveedor de IA. Los detalles del sistema operativo quedan en los servicios y en las carpetas android e ios.

## 4. Información que conserva cada módulo

### Perfiles

La tabla profiles contiene id, owner y name. id identifica el perfil; owner contiene el identificador de la cuenta de acceso; name guarda un nombre o apodo. El alcance actual no necesita almacenar diagnósticos ni expedientes clínicos para operar el tablero.

### Tarjetas y fotos

Las tarjetas predefinidas se distribuyen con la aplicación. El catálogo inicial del código incluye 16 expresiones en los cuatro temas. Ese vocabulario es una base de implementación y deberá revisarse con las personas participantes antes de adoptarlo para uso cotidiano.

La tabla cards guarda id, profile_id, theme, label, spoken, symbol y photo. label es el texto visible; spoken es el texto que se lee al tocar la tarjeta. Ambos pueden coincidir o ser distintos. photo conserva el nombre relativo de un archivo local, lo que evita depender de la ruta absoluta de una instalación anterior.

El selector permite elegir una foto de la galería. La aplicación copia el archivo al espacio privado del proyecto y lo vincula a la tarjeta. No sube la foto al servicio de sugerencias. Los símbolos del catálogo inicial no sustituyen una selección posterior de pictogramas adecuados.

### Mensaje en curso

El mensaje en curso existe en memoria. Incluye la entrada original, las alternativas recibidas, la alternativa seleccionada y el estado de reproducción. Cambiar de perfil limpia ese mensaje. Un reinicio no restaura borradores.

Elegir una sugerencia no sobrescribe la entrada original. La persona puede volver a su texto o editarlo. Cualquier cambio de entrada invalida las sugerencias anteriores para evitar que se reproduzca una alternativa correspondiente a otro mensaje.

### Historial

La tabla interactions guarda id, profile_id, created_at y payload. payload conserva el tema, la entrada original, las alternativas ofrecidas, el texto reproducido, el uso de una sugerencia, el tipo de acción y la anotación de ayuda humana. El tipo distingue una tarjeta aislada de un mensaje completo.

El registro se guarda cuando el servicio de voz informa que terminó la reproducción. Una reproducción cancelada no se cuenta como completada. La vista muestra los 100 registros más recientes del perfil; los anteriores siguen en la base de datos.

La ayuda humana empieza como «Sin registrar». La persona cuidadora puede anotar «Sin ayuda observada» o «Con ayuda observada». La aplicación no deduce autonomía, comprensión ni avance terapéutico a partir del texto generado por la IA.

Las relaciones entre tarjetas, registros y perfiles se verifican mediante claves foráneas de SQLite. Los índices por cuenta, perfil, tema y fecha permiten consultar los datos sin recorrer toda la base. La versión inicial del esquema es 1; los cambios posteriores requieren migraciones explícitas que conserven los datos de esa instalación.

## 5. Recorridos principales

### Preparar el primer uso

La persona cuidadora inicia sesión con conexión, configura el PIN local y agrega un perfil. Al abrirlo, aparecen las tarjetas incluidas. Puede agregar tarjetas propias en cualquiera de los cuatro temas. Si la sesión ya está conservada en el dispositivo, el tablero y la administración local pueden utilizarse sin conexión.

### Expresar un mensaje con tarjetas o texto

La persona elige un tema. Al tocar una tarjeta, escucha de inmediato el texto de voz de esa tarjeta y su etiqueta se agrega al mensaje. También puede escribir con el teclado. El botón «Reproducir mensaje» lee la composición completa. El mensaje queda visible después de escucharlo y puede borrarse cuando la persona lo decida.

### Solicitar y elegir una sugerencia

La persona toca «Pedir sugerencias en línea». Se envían la entrada actual y el tema elegido. El servicio devuelve hasta tres alternativas; se muestran sin reproducirse. La persona puede seleccionar una, conservar el texto original o cambiar su entrada. Para escuchar la alternativa seleccionada debe tocar «Reproducir mensaje».

La solicitud no bloquea el uso de texto y tarjetas. Si falla la conexión o el servicio, aparece un mensaje breve y la entrada sigue disponible. No se guardan solicitudes pendientes para enviarlas automáticamente más tarde.

### Agregar una tarjeta personal

La persona cuidadora abre la administración con su PIN, elige el perfil y captura una palabra o frase. Puede indicar un texto de voz distinto y seleccionar una foto. Después asigna uno de los cuatro temas y guarda. La tarjeta queda disponible únicamente para ese perfil en ese dispositivo.

### Cambiar de perfil o salir

Cambiar de perfil detiene la voz, limpia el mensaje y descarta las respuestas de IA pendientes. Dejar la aplicación en segundo plano también detiene la reproducción y bloquea la administración. Cerrar sesión mantiene los registros locales, pero deja de exponerlos hasta que vuelva a acceder la cuenta correspondiente.

## 6. Servicios externos y funcionamiento sin conexión

### Autenticación

Firebase Authentication resuelve registro, acceso y recuperación de contraseña por correo. Google Sign-In obtiene la credencial para el acceso con Google. La contraseña no se guarda en las tablas del proyecto. Recuperar la contraseña de la cuenta no recupera perfiles, tarjetas ni registros que se hayan perdido de un dispositivo.

### Servicio de sugerencias

El cliente móvil incluye un adaptador HTTP y un contrato para un servicio intermediario. Ese servicio deberá validar el token de identidad, llamar al modelo de lenguaje y devolver las alternativas. El proveedor, el modelo y el despliegue del servicio todavía no están configurados.

La petición usa HTTPS, un encabezado Authorization con un token de Firebase y un cuerpo con cuatro campos: input, theme, language y maxSuggestions. input admite hasta 500 caracteres; theme identifica uno de los cuatro temas; language vale es-MX; maxSuggestions vale 3. La respuesta contiene una lista suggestions de textos breves.

El cliente no agrega nombres, identificadores de perfil, fotos ni historial a esa petición. El token sí identifica la cuenta ante el servicio. El texto escrito por la persona puede contener información personal, por lo que deberá procesarse únicamente para generar las alternativas solicitadas.

El contrato del servicio exige conservar la intención del mensaje, evitar hechos que la persona no haya expresado y tratar el texto recibido como contenido para reformular. Las claves del proveedor deben permanecer en el servidor. La política de retención, los límites de uso y los errores del proveedor deben quedar definidos al desplegar ese servicio; el cliente móvil por sí solo no los garantiza.

Se espera hasta 10 segundos para obtener el token y hasta 15 segundos para recibir la respuesta HTTP. El cliente valida el formato, elimina alternativas repetidas y limita la cantidad y longitud de los textos. Una respuesta antigua nunca reemplaza un mensaje más reciente.

### Voz del dispositivo

DeviceSpeechService usa flutter_tts y busca una voz de español de México. En Android selecciona una voz que el motor identifica como disponible sin red. Si no hay una voz adecuada, informa que debe instalarse y mantiene visible el texto. La disponibilidad y el funcionamiento real sin conexión deben comprobarse en cada plataforma.

### Disponibilidad por tipo de operación

Sin conexión: consultar perfiles ya creados, cambiar de tema, escribir, usar tarjetas, administrar datos locales con PIN y consultar el historial. La reproducción depende de una voz instalada. Con conexión: primer acceso, creación de cuenta, recuperación de contraseña y nuevas sugerencias de IA. No se incorpora un modelo de IA dentro del teléfono.

## 7. Protección y conservación de los datos

SQLite y las fotos se alojan en el espacio privado de la aplicación. El PIN se verifica con PBKDF2-HMAC-SHA256, una sal aleatoria y 210 000 iteraciones; el resultado se guarda mediante el almacenamiento seguro del sistema. Cinco intentos incorrectos aplican una espera de un minuto. El PIN no se guarda como texto legible.

El identificador de instalación forma parte de la clave del PIN. Una instalación nueva no reutiliza automáticamente el PIN de una instalación eliminada. Esta versión todavía no incorpora un flujo para restablecer un PIN olvidado.

En Android se desactiva el respaldo y se excluyen los archivos de las reglas de copia y transferencia. En iOS se marca la carpeta de datos del proyecto para excluirla de los respaldos. Estas configuraciones expresan la decisión de no ofrecer recuperación y requieren verificación en dispositivos reales antes de distribuir la aplicación.

La base SQLite no incorpora cifrado adicional de aplicación en esta versión; utiliza el aislamiento y la protección del sistema operativo. El PIN controla el acceso a la administración. No se presenta como sustituto del bloqueo del dispositivo.

## 8. Adaptación del proyecto de referencia

AAC Board AI, de Shay Cojocaru, se utiliza como referencia técnica. Su código web no define el alcance de este proyecto. La adaptación se realizó en una carpeta Flutter independiente y conserva la atribución de la licencia MIT.

React y sus hooks se trasladan a widgets y a BoardViewModel. IndexedDB se sustituye por SQLite y archivos privados. La reproducción del navegador se sustituye por la voz nativa. La IA del navegador se sustituye por una interfaz para sugerencias en línea. El PIN, las cuentas y los perfiles independientes se añaden para responder al alcance acordado.

Se conserva la diferencia entre tocar una tarjeta, elegir una sugerencia y reproducir el mensaje. También se conserva la selección manual del contexto. El nuevo cliente envía el tema elegido al servicio de sugerencias para relacionar la entrada con una situación cotidiana.

No se trasladaron la importación de archivos OBF/OBZ, los tableros enlazados del catálogo externo ni la dependencia de funciones de IA de un navegador de escritorio. El catálogo Flutter inicial es propio y no incorpora los recursos gráficos de Quick Core.

## 9. Entrega y configuración pendiente

### Vista previa local para desarrollo

La compilación de depuración incluye «Probar sin iniciar sesión». Este acceso abre un perfil inicial llamado «Usuario de prueba» sin inicializar una cuenta Firebase. Sus perfiles, tarjetas y registros utilizan la carpeta privada communication_preview, separada del almacenamiento de cuentas reales. La administración conserva su protección por PIN. Las sugerencias en línea están desactivadas en la vista previa. El acceso se excluye de las compilaciones de distribución mediante kDebugMode.

El proyecto local contiene la estructura Android/iOS, las pantallas, el modelo de vista de comunicación, el catálogo inicial, SQLite, el control de PIN, el registro de interacciones y los adaptadores de autenticación, voz y sugerencias. El archivo pubspec.lock fija las versiones resueltas con Flutter 3.35.7 y Dart 3.9.2.

La revisión estática del código pasó sin incidencias y se verificaron 15 casos sobre composición, reproducción, aislamiento de perfiles, protección del historial, inmutabilidad de tarjetas incluidas y contrato de sugerencias. Estas verificaciones usan servicios simulados para voz e IA y una base SQLite local para persistencia.

Se compiló correctamente el APK de depuración para Android. La compilación del simulador iOS se detuvo porque el Xcode disponible solicita una plataforma iOS 26.2 que no está instalada; las dependencias de CocoaPods sí se resolvieron. Por ello, esta entrega no confirma una compilación iOS completa.

Para habilitar el acceso real se debe registrar la aplicación en Firebase, activar correo y Google y proporcionar los valores de configuración de cada plataforma. Google requiere además su configuración OAuth de Android e iOS. No se creó ni se vinculó un proyecto externo de Firebase durante esta entrega.

Para obtener sugerencias reales se debe desplegar el servicio descrito en la sección 6 y proporcionar su dirección HTTPS mediante SUGGESTION_ENDPOINT. No se incluye una clave de proveedor en el código móvil ni se presenta una respuesta simulada como si proviniera de un modelo real.

La distribución final también requiere configurar la firma de las aplicaciones, revisar el vocabulario con participantes y comprobar en equipos reales el acceso, la galería, la voz sin conexión y las exclusiones de respaldo. La integración externa y esa revisión en dispositivos siguen pendientes.

## 10. Fuentes y criterio de redacción

El alcance combina la propuesta PLab 1.1.1, la actividad LU Taller 2.3.1 y las decisiones confirmadas para este proyecto. Cuando existe una diferencia, prevalecen las decisiones más recientes: capacidad de lectura y escritura, Flutter para Android e iOS y almacenamiento local sin sincronización ni recuperación.

ISO 24495-1:2023 orienta la redacción del documento. La información necesaria aparece primero; los encabezados permiten localizar decisiones; los términos técnicos se explican al usarlos; y cada flujo indica qué hace la persona, qué hace la aplicación y qué resultado obtiene. La norma se utiliza para la comunicación escrita, no como una especificación de arquitectura de software.

[ISO 24495-1:2023 — Plain language: Governing principles and guidelines.](https://www.iso.org/standard/78907.html)

[Flutter — Guide to app architecture.](https://docs.flutter.dev/app-architecture/guide)

[Flutter — Architecture recommendations y aplicaciones con funcionamiento sin conexión.](https://docs.flutter.dev/app-architecture/recommendations)

[Firebase — Authentication para Flutter.](https://firebase.google.com/docs/auth/flutter/start)

[AAC Board AI — repositorio de referencia; revisión 1efba8bc08346150f4fffa7c166e9a655eb46ad9.](https://github.com/shayc/aac-board-ai/tree/1efba8bc08346150f4fffa7c166e9a655eb46ad9)

[flutter_tts — integración de texto a voz en Flutter.](https://pub.dev/packages/flutter_tts)
