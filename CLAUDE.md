# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

**HackUDC 2026 — Administrador de Becas Inteligente**

An AI-powered decision-support tool that filters and recommends candidates for public scholarships/grants. This is **NOT a free-form chatbot** — it is a structured analytical engine that processes socioeconomic criteria and returns justified rankings.

**Context**: 24–48 h hackathon, team of 3–4, live demo before judges. Prioritize correctness and reliability of the demo over architectural perfection.

---

## Architecture

```
Flutter UI → Denodo AI SDK (localhost:8008) → Denodo Express (VQL)
```

> No Python middleware layer. Flutter calls Denodo AI SDK directly via `DenodoService`.

### Layers
- **Frontend**: Flutter web app (`frontend/flutter_hackudc/`). Runs on Chrome. Chat-style UI with sidebar, model selector, results display, and candidates panel.
- **Denodo AI SDK** (`localhost:8008`): RAG orchestration layer. Swagger docs at `http://localhost:8008/docs`.
- **Denodo Express**: Virtual data integration platform (Docker container `vdp`).

### Mandatory Two-Phase Reasoning Flow (Turbo mode)

Every Turbo query **must** follow this order — never skip phase 1:

1. **`GET /answerMetadataQuestion`** — Discover available tables/columns dynamically. No hardcoded view names.
2. **`GET /answerDataQuestion`** — Generate and execute VQL based on phase 1 discovery.

Deep mode uses a different flow:
1. **`POST /deepQuery`** — Full reasoning with DeepSeek-R1 (`deepseek-reasoner`).
2. **`POST /generateDeepQueryReport`** — Generates HTML report from metadata.

All calls use Basic Auth (`admin:admin`) and hit `localhost:8008`.

---

## AI Modes (CURRENT — updated from original spec)

| Mode (UI label) | SDK LLM | Thinking LLM | Use case |
|-----------------|---------|--------------|----------|
| Turbo | `deepseek-chat` | — | Fast filtering, VQL generation, temperature 0 |
| Deep | `deepseek-chat` | `deepseek-reasoner` (R1) | Full reasoning, HTML report, justification |

> **Important**: Embeddings remain on OpenAI (`text-embedding-3-small`) because DeepSeek does not provide embedding models. The `OPENAI_API_KEY` in `config/sdk_config.env` must stay valid for embeddings to work.

### DeepSeek configuration (in `config/sdk_config.env`)
```
LLM_PROVIDER = DEEPSEEK
LLM_MODEL = deepseek-chat
THINKING_LLM_PROVIDER = DEEPSEEK
THINKING_LLM_MODEL = deepseek-reasoner
THINKING_LLM_TEMPERATURE = 0.6   ← NOT 1.0 (DeepSeek-R1 recommends 0.5–0.7)
EMBEDDINGS_PROVIDER = openai
EMBEDDINGS_MODEL = text-embedding-3-small
DEEPSEEK_API_KEY = <key>
DEEPSEEK_BASE_URL = https://api.deepseek.com/v1
```

---

## Implementation Status

### ✅ Implemented and working
- Flutter web app with Firebase Auth (Google Sign-In via `signInWithPopup`)
- Two-mode query flow: Turbo (2-phase) and Deep (`/deepQuery` + `/generateDeepQueryReport`)
- Sidebar with session management (create, rename, delete), persisted in Firestore
- Chat UI with loading phases, error messages in Spanish, related questions, VQL reasoning tile
- SVG graph rendering and download
- HTML report download (Deep mode)
- DeepSeek migration: `deepseek-chat` for Turbo, `deepseek-reasoner` for Deep
- **Reasoning visible**: DeepSeek-R1 chain-of-thought displayed in the UI (collapsible section)

### 🔲 Planned — not yet implemented
See "Planned Features" section below.

---

## Planned Features (to implement)

### 1. Consultas rápidas predefinidas
Quick-query chips shown on the welcome screen (when no messages exist). Tapping a chip sends the query immediately without typing.

**Placement**: Replace/extend `_WelcomeText` in `home_screen.dart`. Chips appear below the welcome message, above the input bar.

**Queries to include** (subject to team decision):
- "Top 20 candidatos elegibles para la beca MEC"
- "Candidatos con discapacidad reconocida"
- "Análisis de solicitantes por comunidad autónoma"
- "Candidatos con renta inferior al umbral 1"

**Implementation notes**:
- Chips call `provider.sendMessage(text)` directly — no new service calls needed.
- No new packages required.
- Only touches `home_screen.dart`.

---

### 2. Email automático del informe Deep
After a Deep query completes and the HTML report is generated, automatically send it to the logged-in user's email (`FirebaseAuth.instance.currentUser?.email`) via the **Resend** API.

**Service**: [Resend](https://resend.com) — free tier (3,000 emails/month). REST API compatible with the existing `http` package.

**Flow**:
1. Deep query finishes → `htmlReport` is non-null in `ApiResponse`
2. `DenodoService` or `QueryProvider` calls `EmailService.sendReport(toEmail, htmlReport)`
3. `EmailService` posts to `https://api.resend.com/emails` with the HTML as body
4. SnackBar confirms: `"Informe enviado a usuario@gmail.com"`
5. The "Enviar por correo" button in `_ReportActions` updates to show sent state

**New file**: `lib/services/email_service.dart`

**Environment**: The Resend API key must be stored as a constant in `email_service.dart` (for hackathon simplicity — not production practice).

**Package**: No new package needed — uses existing `http`.

---

### 3. Panel de candidatos (tarjetas)
A dedicated screen/tab that renders the last Deep query result as structured candidate cards instead of plain text. This is the most impactful "anti-chatbot" feature.

**UI layout per card**:
- Avatar with initials (colored circle)
- Candidate name and application ID
- Renta anual + número de miembros
- Badge chips for active criteria: `[Discapacidad]`, `[Orfandad]`, `[Familia numerosa]`, `[Reside fuera]`, `[Renta < U1]`
- Score bar (visual ranking position)
- Ranking number (#1, #2, ...)

**Data source**: The `ApiResponse.answer` text from Deep mode. Two parsing strategies:
1. **Preferred**: Modify `CUSTOM_INSTRUCTIONS` in `config/sdk_config.env` to request JSON output from the LLM, then parse it in a new `CandidateParser` class.
2. **Fallback**: Regex/Markdown parsing of the existing text response.

**New files**:
- `lib/models/candidate.dart` — `Candidate` data class
- `lib/widgets/candidate_card.dart` — card widget
- `lib/screens/candidates_screen.dart` — full screen with `ListView.builder`

**Navigation**: Add a "Ver candidatos" button on the last Deep response bubble that navigates to `CandidatesScreen`.

**Package**: No new packages required (badges and bars with standard Flutter widgets).

---

### 4. Langfuse (LLM observability)
Langfuse is an open-source LLM observability platform. It records every LLM call made by the Denodo AI SDK: prompt, response, token usage, latency, model used, and user feedback.

**Why it matters for the demo**: Opens a real-time dashboard during the demo showing every query the judges just ran — latencies, token costs, model comparisons. Answers "how do you monitor this in production?"

**Implementation** (no Flutter changes needed — infrastructure only):
1. Add Langfuse container to `docker-compose` (or use free cloud tier at langfuse.com)
2. Create a free project at langfuse.com → get `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY`
3. Uncomment and fill in `config/sdk_config.env` section 9:
   ```
   LANGFUSE_PUBLIC_KEY = pk-lf-...
   LANGFUSE_SECRET_KEY = sk-lf-...
   LANGFUSE_HOST = https://cloud.langfuse.com
   ```
4. Restart `denodo-ai-sdk-chatbot` container
5. All subsequent queries appear automatically in Langfuse dashboard

**No code changes to Flutter required.**

---

## Denodo Data Views

| View | Key columns |
|------|-------------|
| `solicitudes_beca_mec` | id_solicitud, nif_solicitante, nombre_solicitante, renta_anual_familiar, num_miembros_unidad_familiar, discapacidad, orfandad, familia_numerosa, nacionalidad_espanola, repite_curso, reside_fuera_domicilio |
| `umbrales_renta_mec` | num_miembros, umbral_1_euros, umbral_2_euros |

### MEC Eligibility Rules

Automatic disqualifiers (applied before ranking):
- `nacionalidad_espanola = false`
- `repite_curso = true`
- `renta_anual_familiar > umbral_2_euros` for their `num_miembros`

Ranking criteria (higher priority first):
1. Renta below `umbral_1_euros` (strongest need)
2. `discapacidad = true`
3. `orfandad = true`
4. `familia_numerosa = true`
5. `reside_fuera_domicilio = true` (additional grant component)

---

## Infrastructure (Docker)

- `vdp` — Denodo Express (Virtual DataPort)
- `denodo-ai-sdk-chatbot` — Denodo AI SDK

**Key rules:**
- License file must be at `config/denodo.lic`.
- Config files: `config/sdk_config.env` (SDK) and `config/chatbot_config.env` (sample chatbot — not used by Flutter).
- After any Design Studio change: **sync with Data Marketplace** and **restart `denodo-ai-sdk-chatbot`**.
- After any change to `config/sdk_config.env`: **restart `denodo-ai-sdk-chatbot`**.

---

## Flutter Code Guidelines

### State Management: Provider

Use **Provider** for all shared state. Do NOT use raw `setState` for state consumed by more than one widget.

```
lib/
  models/          # Plain Dart data classes (fromJson, toJson)
  providers/       # ChangeNotifier classes — business logic lives here
  services/        # HTTP clients (DenodoService, EmailService). No UI logic.
  screens/         # Full-page widgets. Only call providers, no direct service calls.
  widgets/         # Reusable UI components.
```

### Language Rules

- **UI strings visible to the user**: Spanish
- **Code** (variables, functions, classes, comments): English

### Dependency Policy

**Do not add packages to `pubspec.yaml` without explicit user approval.**

Current approved and installed packages:
- `flutter`, `http: ^1.2.0`, `flutter_svg: ^2.2.3`, `cupertino_icons: ^1.0.8`
- `provider: ^6.1.2`
- `firebase_core: ^3.13.0`, `firebase_auth: ^5.5.0`, `cloud_firestore: ^5.6.6`
- `google_sign_in: ^6.2.2`

### Widget Rules

- Use `const` constructors wherever possible.
- Extract any `build` method longer than ~80 lines into sub-widgets.
- Always handle three states for async data: **loading**, **error**, **data**.
- Use `ListView.builder` (never `ListView` with `children`) for lists of unknown length.

### Demo Reliability (critical for live demo)

- Turbo timeout: **60 s**. Deep timeout: **300 s**.
- Show a **loading indicator** with phase label during queries.
- On error, show a **user-readable message in Spanish** — never a raw exception or stack trace.
- The app must not crash on empty API responses or malformed JSON.
- Platform target: **Flutter Web (Chrome)**. `AuthService` uses `signInWithPopup` which only works on web — do not run on desktop or mobile.

---

## Known Issues

1. `firebase_options.dart` was deleted from the repo. It must exist locally at `lib/firebase_options.dart` before building. Regenerate with `flutterfire configure` if missing.
2. `ChatMessage.toJson()` does not serialize `apiResponse`. Sessions restored from Firestore will not have VQL, graphs, or related questions.
3. `_OptionsPanel` (Exportar / Compartir buttons): `onTap: () {}` — not yet implemented.

---

## Data Files

Located in `data/`:
- `data/solicitudes_beca_mec.csv` — 100 synthetic applicants (75 eligible, 25 rejected)
- `data/umbrales_renta_mec.csv` — MEC income thresholds by family size (1–5 members)

Generator script: `scripts/generate_mec_data.py` (seed=42, deterministic output)
