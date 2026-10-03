# Contrato del servicio de sugerencias

Este documento especifica el servicio que consume `HttpSuggestionService`. El adaptador móvil está implementado; el servidor y su integración con un modelo todavía deben desplegarse.

## Petición

`POST` a la dirección HTTPS definida en `SUGGESTION_ENDPOINT`.

Encabezados: `Content-Type: application/json` y `Authorization: Bearer <Firebase ID token>`.

```json
{
  "input": "yo agua",
  "theme": "food",
  "language": "es-MX",
  "maxSuggestions": 3
}
```

Los temas válidos son `home`, `leisure`, `food` y `care`. La entrada admite hasta 500 caracteres. El cliente no incluye identificadores de perfil, nombres, fotografías ni historial. El token identifica a la cuenta que solicita el servicio.

## Respuesta

Estado 200, UTF-8, `Content-Type: application/json; charset=utf-8`.

```json
{
  "suggestions": ["Quiero agua.", "Agua, por favor."]
}
```

Máximo tres alternativas distintas, de hasta 500 caracteres cada una. La respuesta completa debe ocupar como máximo 16 KB. Una lista vacía significa que no hay alternativas disponibles. No se debe devolver HTML, código ni instrucciones para ejecutar acciones.

## Responsabilidades del servidor

1. Validar la firma, el emisor, la audiencia, la vigencia y el UID del token mediante el SDK de administración de Firebase.
2. Validar tamaño, idioma y tema antes de llamar al proveedor.
3. Aplicar límites de solicitudes por cuenta y un tiempo máximo para el modelo.
4. Mantener la clave del proveedor en el servidor; nunca enviarla a la aplicación.
5. Indicar al modelo que proponga expresiones breves en español de México, conserve la intención y no invente necesidades, hechos ni preferencias.
6. Tratar la entrada como contenido que debe reformularse. No permitir que modifique las instrucciones del servicio ni active herramientas externas.
7. Documentar y configurar la retención del proveedor. Excluir texto de comunicación y tokens de los registros operativos por defecto; usar códigos, tiempos y cantidades para diagnóstico.
8. Devolver errores sin reproducir credenciales ni contenido del proveedor.

Estados: 400 para entrada inválida; 401 para sesión no válida; 429 para exceso de solicitudes; 503 para indisponibilidad. El cliente conserva el tablero y el texto ante estos errores y no reenvía solicitudes automáticamente.

El servidor no es una base de datos de perfiles ni un servicio de sincronización. La elección de proveedor, el costo de operación y la política de retención requieren configuración antes del uso real.
