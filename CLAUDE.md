# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HackUDC 2026 — Administrador de Becas Inteligente**

An AI-powered decision-support tool that filters and recommends candidates for public scholarships/grants. This is NOT a free-form chatbot — it is a structured analytical engine that processes socioeconomic criteria and returns justified rankings.

**Context**: 24–48 h hackathon, team of 3–4, live demo before judges. Prioritize correctness and reliability of the demo over architectural perfection.

## Architecture

```
Flutter UI → Denodo AI SDK (localhost:8008) → Denodo Express (VQL)
```

> No Python middleware layer. Flutter calls Denodo AI SDK directly via `DenodoService`.

### Layers
- **Frontend**: Flutter app (`frontend/flutter_hackudc/`). Chat-style UI with sidebar, model selector, and results display.
- **Denodo AI SDK** (`localhost:8008`): RAG orchestration layer. Swagger docs at `http://localhost:8008/docs`.
- **Denodo Express**: Virtual data integration platform.

### Mandatory Two-Phase Reasoning Flow

Every query to Denodo **must** follow this order — never skip phase 1:

1. **`GET /answerMetadataQuestion`** — Discover available tables/columns dynamically. No hardcoded view names.
2. **`GET /answerDataQuestion`** — Generate and execute VQL based on phase 1 discovery.

Both calls use Basic Auth (`admin:admin`) and hit `localhost:8008`.

### AI Modes

| Mode (UI label) | LLM model | Use case |
|-----------------|-----------|----------|
| Turbo | `gpt-4o` | Fast filtering, temperature 0 |
| Pro | `o1` | Deep reasoning, full justification |

The selected model in the UI **must** change the `llm_model` parameter sent to Denodo AI SDK.

### Denodo Data Views

| View | Key columns |
|------|-------------|
| `solicitudes_beca_mec` | id_solicitud, nif_solicitante, nombre_solicitante, renta_anual_familiar, num_miembros_unidad_familiar, discapacidad, orfandad, familia_numerosa, nacionalidad_espanola, repite_curso, reside_fuera_domicilio |
| `umbrales_renta_mec` | num_miembros, umbral_1_euros, umbral_2_euros |

### MEC Eligibility Rules (for prompts and filters)

Automatic disqualifiers (must be applied before ranking):
- `nacionalidad_espanola = false`
- `repite_curso = true`
- `renta_anual_familiar > umbral_2_euros` for their `num_miembros`

Ranking criteria (higher priority first):
1. Renta below `umbral_1_euros` (strongest need)
2. `discapacidad = true`
3. `orfandad = true`
4. `familia_numerosa = true`
5. `reside_fuera_domicilio = true` (additional grant component)

## Infrastructure (Docker)

- `vdp` — Denodo Express (Virtual DataPort)
- `denodo-ai-sdk-chatbot` — Denodo AI SDK

**Key rules:**
- License file must be at `config/denodo.lic`.
- After any Design Studio change: **sync with Data Marketplace** and **restart `denodo-ai-sdk-chatbot`**.

## Flutter Code Guidelines

### State Management: Provider

Use **Provider** for all shared state. Do NOT use raw `setState` for state that is consumed by more than one widget.

Structure:
```
lib/
  models/          # Plain Dart data classes (fromJson, toJson)
  providers/       # ChangeNotifier classes — business logic lives here
  services/        # HTTP clients (DenodoService). No UI logic.
  screens/         # Full-page widgets. Only call providers, no direct service calls.
  widgets/         # Reusable UI components.
```

### Language Rules

- **UI strings visible to the user**: Spanish
- **Code** (variables, functions, classes, comments): English
- Example: a class `CandidateCard` shows the text `"Solicitud aprobada"`

### Dependency Policy

**Do not add packages to `pubspec.yaml` without explicit user approval.** Ask first, then add. Current approved packages: `flutter`, `http`, `flutter_svg`, `cupertino_icons`.

### Comments

Only comment logic that is genuinely non-obvious (complex algorithms, Denodo quirks, VQL workarounds). Do not comment self-explanatory code.

### Widget Rules

- Use `const` constructors wherever possible.
- Extract any `build` method longer than ~80 lines into sub-widgets.
- Always handle three states for async data: **loading**, **error**, **data**.
- Use `ListView.builder` (never `ListView` with `children`) for lists of unknown length.

### Demo Reliability (critical for live demo)

- Every API call must have a **timeout** (≥ 30 s for Turbo, ≥ 120 s for Pro/o1).
- Show a **loading indicator** with phase label while the two-phase call is in progress.
- On error, show a **user-readable message** in Spanish — never a raw exception or stack trace.
- The app must not crash on empty API responses or malformed JSON.

## Data Files

Located in `data/`:
- `data/solicitudes_beca_mec.csv` — 100 synthetic applicants (75 eligible, 25 rejected)
- `data/umbrales_renta_mec.csv` — MEC income thresholds by family size (1–5 members)

Generator script: `scripts/generate_mec_data.py`
