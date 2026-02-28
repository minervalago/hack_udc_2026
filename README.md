# Administrador de Becas Inteligente — HackUDC 2026

Herramienta de apoyo a la decisión basada en IA para filtrar y recomendar candidatos a becas públicas (convocatoria MEC). No es un chatbot de uso libre: es un motor analítico estructurado que procesa criterios socioeconómicos y devuelve rankings justificados.

---

## Arquitectura

```
Flutter Web (Chrome)
       │
       ▼
DenodoService (HTTP + Basic Auth)
       │
       ▼
Denodo AI SDK  ──────────────────────────────┐
(localhost:8008)                             │
       │                                     │
       ├─ /answerMetadataQuestion  (Turbo 1) │
       ├─ /answerDataQuestion      (Turbo 2) │
       ├─ /deepQuery               (Deep 1)  │
       └─ /generateDeepQueryReport (Deep 2)  │
                                             │
       ▼                                     │
Denodo Express (VQL) ◄───────────────────────┘
```

**Servicios externos:**
- **Firebase Auth** — autenticación con Google
- **Firestore** — persistencia de sesiones de chat
- **Resend API** — envío de informes por correo electrónico
- **OpenAI** — modelos LLM (`gpt-4o-mini` en Turbo, `o1` en Deep)

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Flutter SDK | 3.10.x |
| Chrome | cualquier versión reciente |
| Denodo AI SDK | corriendo en `localhost:8008` |
| Denodo Express | corriendo en Docker (`vdp`) |

---

## Configuración inicial

### 1. Firebase

El archivo `lib/firebase_options.dart` **no está incluido en el repositorio**. Debe generarse localmente:

```bash
# Instalar FlutterFire CLI si no está disponible
dart pub global activate flutterfire_cli

# Configurar con el proyecto Firebase del equipo
flutterfire configure
```

Esto generará `lib/firebase_options.dart` con las credenciales del proyecto.

### 2. Dependencias Flutter

```bash
cd flutter_hackudc
flutter pub get
```

### 3. Denodo AI SDK

El SDK debe estar corriendo en `localhost:8008` con las vistas de Denodo Express sincronizadas. Credenciales por defecto: `admin / admin`.

Vistas de datos requeridas:
- `solicitudes_beca_mec`
- `umbrales_renta_mec`

---

## Ejecución

```bash
cd flutter_hackudc
flutter run -d chrome
```

> La app **solo funciona en Chrome**. El inicio de sesión con Google usa `signInWithPopup`, que es exclusivo de Flutter Web.

---

## Funcionalidades

### Modos de consulta

| Modo | Modelo LLM | Tiempo máximo | Resultado |
|---|---|---|---|
| **Turbo** | `gpt-4o-mini` | 60 s | Tabla markdown + VQL + gráfica opcional |
| **Deep** | `o1` (thinking) | 300 s | Análisis profundo + informe HTML descargable |

#### Flujo Turbo (2 fases)
1. `GET /answerMetadataQuestion` — descubre las tablas/columnas disponibles dinámicamente
2. `GET /answerDataQuestion` — genera y ejecuta VQL sobre Denodo Express

#### Flujo Deep (2 fases)
1. `POST /deepQuery` — razonamiento completo con `o1`
2. `POST /generateDeepQueryReport` — genera un informe HTML con justificación detallada

### Gestión de sesiones
- Las conversaciones se guardan automáticamente en Firestore por usuario y base de datos.
- Se pueden renombrar y eliminar desde el panel lateral.

### Tarjetas de candidatos
Cuando la respuesta incluye una tabla de candidatos, se puede alternar entre vista de texto markdown y tarjetas visuales con:
- Posición en el ranking (#1, #2, ...)
- Nombre e identificador
- Renta anual familiar
- Badges de criterios: Discapacidad, Orfandad, Familia numerosa, Reside fuera

### Exportación
- **Gráfica SVG** — descarga directa desde el mensaje de respuesta
- **Informe PDF** — abre el informe HTML en nueva pestaña y lanza el diálogo de impresión del navegador
- **Informe HTML** — descarga el informe completo generado en modo Deep
- **Correo electrónico** — envía el informe al email del usuario autenticado (vía Resend API)

---

## Estructura del proyecto

```
flutter_hackudc/
├── lib/
│   ├── main.dart                    # Punto de entrada, AuthGate
│   ├── firebase_options.dart        # Generado localmente (no en repo)
│   ├── models/
│   │   ├── chat_message.dart        # Modelo de mensaje
│   │   └── chat_session.dart        # Modelo de sesión
│   ├── providers/
│   │   └── query_provider.dart      # Estado global (ChangeNotifier)
│   ├── screens/
│   │   ├── home_screen.dart         # Pantalla principal
│   │   └── login_screen.dart        # Pantalla de inicio de sesión
│   └── services/
│       ├── auth_service.dart        # Firebase Authentication
│       ├── denodo_service.dart      # Cliente HTTP del Denodo AI SDK
│       ├── email_service.dart       # Envío de correo (Resend)
│       ├── firestore_service.dart   # Persistencia de sesiones
│       └── download_helper*.dart    # Exportación multiplataforma
└── pubspec.yaml
```

---

## Criterios de elegibilidad MEC

La app evalúa candidatos según las reglas oficiales de la convocatoria MEC:

**Descalificadores automáticos:**
- `nacionalidad_espanola = false`
- `repite_curso = true`
- Renta familiar > umbral 2 para el número de miembros

**Criterios de ranking** (mayor prioridad primero):
1. Renta por debajo del umbral 1 (mayor necesidad económica)
2. Discapacidad reconocida
3. Orfandad
4. Familia numerosa
5. Reside fuera del domicilio familiar

---

## Problemas conocidos

1. **`firebase_options.dart`** no está en el repositorio — debe generarse con `flutterfire configure`.
2. **Sesiones restauradas** desde Firestore no incluyen VQL, gráficas ni preguntas relacionadas (el campo `apiResponse` no se serializa).
3. Los botones **Exportar / Compartir** del panel de opciones no están implementados.

---

## Tecnologías

- **Flutter 3** — framework UI multiplataforma (target: web)
- **Provider** — gestión de estado
- **Firebase Auth + Firestore** — autenticación y persistencia
- **OpenAI** (`gpt-4o-mini`, `o1`) — modelos LLM vía Denodo AI SDK
- **Denodo Express** — integración virtual de datos (VQL)
- **Resend** — envío transaccional de correos
