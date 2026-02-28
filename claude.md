# HackUDC 2026 — Notas de proyecto

> **La fuente de verdad para agentes de IA es `CLAUDE.md`** (mayúsculas).
> Este archivo es un resumen de referencia rápida. En caso de conflicto, `CLAUDE.md` tiene prioridad.

## Identidad del proyecto

Herramienta analítica de toma de decisiones para filtrar y recomendar candidatos a becas MEC.
**No es un chatbot libre** — es un motor estructurado que procesa criterios socioeconómicos y devuelve rankings justificados.

Stack: Flutter Web → Denodo AI SDK (localhost:8008) → Denodo Express (VQL)

## Proveedores de IA actuales

| Rol | Proveedor | Modelo |
|-----|-----------|--------|
| LLM principal (Turbo) | DeepSeek | `deepseek-chat` |
| Reasoning (Deep) | DeepSeek | `deepseek-reasoner` (R1) |
| Embeddings | OpenAI | `text-embedding-3-small` |

Configurado en `config/sdk_config.env` mediante el mecanismo de Custom Provider de Denodo AI SDK.

## Estado de implementación

### ✅ Implementado
- App Flutter web con Firebase Auth (Google login)
- Modo Turbo: 2 fases (`/answerMetadataQuestion` + `/answerDataQuestion`)
- Modo Deep: `/deepQuery` (o1/deepseek-reasoner) + `/generateDeepQueryReport`
- Sidebar con sesiones persistidas en Firestore
- Razonamiento visible: chain-of-thought de DeepSeek-R1 en la UI
- Descarga de informe HTML (modo Deep)
- Migración de OpenAI a DeepSeek completada

### 🔲 Pendiente de implementar
1. **Consultas rápidas predefinidas** — chips en la pantalla de bienvenida
2. **Email automático del informe Deep** — via Resend API al email del usuario logueado
3. **Panel de candidatos (tarjetas)** — vista estructurada de resultados con cards individuales
4. **Langfuse** — observabilidad LLM (solo infraestructura Docker + 2 variables de config)

## Reglas MEC (descalificadores y ranking)

Descalificadores: `nacionalidad_espanola=false`, `repite_curso=true`, `renta > umbral_2`

Ranking (prioridad descendente):
1. Renta < umbral_1
2. Discapacidad
3. Orfandad
4. Familia numerosa
5. Reside fuera del domicilio familiar

## Infraestructura Docker

- `vdp` — Denodo Express
- `denodo-ai-sdk-chatbot` — Denodo AI SDK
- Tras cambios en `sdk_config.env` o Design Studio: reiniciar `denodo-ai-sdk-chatbot`
- Licencia en `config/denodo.lic`

## Plataforma objetivo

Flutter Web (Chrome). `signInWithPopup` solo funciona en web — no ejecutar en desktop/mobile.
