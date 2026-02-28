# Diagramas de Flujo — Administrador de Becas Inteligente

---

## 1. Arranque y Autenticación

```mermaid
flowchart TD
    A([Inicio: main.dart]) --> B[Firebase.initializeApp]
    B --> C[ChangeNotifierProvider\nQueryProvider..loadDatabases]
    C --> D[AuthGate]
    D --> E[escucha authStateChanges]

    E -->|User == null| F[LoginScreen]
    E -->|User != null| G[HomeScreen]

    F --> H[Botón: Continuar con Google]
    H --> I[AuthService.signInWithGoogle]
    I --> J[signInWithPopup\nChrome únicamente]
    J -->|Éxito| K[Firebase emite User]
    J -->|Error / cancelado| F
    K --> G

    G --> L[QueryProvider.setUser uid]
    L --> M[_loadSessionsFromFirestore]
    M --> N["Firestore: users/{uid}/sessions\nWHERE database = selectedDatabase\nORDER BY updatedAt DESC"]
    N --> O[Sesiones cargadas en memoria]

    C --> P[loadDatabases]
    P --> Q["GET /getVectorDBInfo\nBasic Auth: admin/admin"]
    Q -->|200 OK| R["databases = keys de\nsyncedResources.DATABASE"]
    Q -->|Error| S[databasesError = mensaje]
    R --> T[selectedDatabase = databases.first]
    T --> M
```

---

## 2. Flujo de Consulta — Modo Turbo

```mermaid
flowchart TD
    A([Usuario escribe mensaje]) --> B{texto vacío\no isLoading?}
    B -->|Sí| Z([Ignorar])
    B -->|No| C{currentSession\n== null?}
    C -->|Sí| D["newChat()\nChatSession con id=timestamp\ndatabase=selectedDatabase"]
    C -->|No| E[Usar sesión actual]
    D --> E

    E --> F[Añadir ChatMessage usuario a sesión]
    F --> G["status = loading\nloadingPhase = 'Iniciando consulta...'"]
    G --> H{"wantsPlot?\nregex: gráfic|plot|chart|diagrama"}
    H --> I["DenodoService.query\nmodel='Turbo', database, plot"]

    I --> J["onPhaseChange:\n'Descubriendo esquema de datos...'"]
    J --> K["_discoverMetadata(question)"]

    subgraph FASE1["Fase 1 — Descubrimiento de metadatos"]
        K --> L["GET /answerMetadataQuestion"]
        L --> M["llm_model: gpt-4o-mini\nllm_temperature: 0\nembeddings_model: text-embedding-3-small\nvector_store_provider: chroma\nvector_search_k: 5\nmarkdown_response: false"]
        M --> N{HTTP 200?}
        N -->|No| ERR["throw Exception\n'Metadata error {status}'"]
        N -->|Sí| O["metadataContext = data['answer']"]
    end

    O --> P["onPhaseChange:\n'Consultando base de datos...'"]
    P --> Q["_queryData(question, metadataContext, plot)"]
    Q --> R["enrichedQuestion =\nquestion + '[Contexto de esquema]:\n' + metadataContext"]

    subgraph FASE2["Fase 2 — Consulta de datos y VQL"]
        R --> S["GET /answerDataQuestion"]
        S --> T["llm_model: gpt-4o-mini\nllm_temperature: 0\nllm_max_tokens: 4096\nplot: true/false\nvql_execute_rows_limit: 100\nllm_response_rows_limit: 25\nmarkdown_response: true\nexpand_set_views: true\nallow_external_associations: false"]
        T --> U{HTTP 200?}
        U -->|No| ERR
        U -->|Sí| V["ApiResponse.fromJson\n─────────────────\nanswer: string\nsqlQuery: string\nqueryExplanation: string\nrelatedQuestions: list\nrawGraph: base64 SVG\ntablesUsed: list"]
    end

    ERR --> EH{tipo de\nexcepción}
    EH -->|TimeoutException| ET["ApiResponse.error:\n'La consulta tardó demasiado...'"]
    EH -->|SocketException| ES["ApiResponse.error:\n'No se puede conectar con\nDenodo (localhost:8008)...'"]
    EH -->|Otro| EO["ApiResponse.error:\n'Error inesperado: {msg}'"]

    V --> FIN
    ET --> FIN
    ES --> FIN
    EO --> FIN

    FIN["ChatMessage.fromApiResponse\nañadido a sesión"] --> FIN2["status = done\nloadingPhase = ''"]
    FIN2 --> FIN3[notifyListeners]
    FIN3 --> FS{userId != null?}
    FS -->|Sí| FS2["FirestoreService.saveSession\nusers/{uid}/sessions/{sessionId}"]
    FS -->|No| END([Fin])
    FS2 --> END
```

---

## 3. Flujo de Consulta — Modo Deep

```mermaid
flowchart TD
    A([Usuario escribe mensaje]) --> B[Misma lógica de sesión\nque en Turbo]
    B --> C["DenodoService.query\nmodel='Deep', database"]

    C --> D["onPhaseChange:\n'Iniciando análisis profundo con o1...'"]
    D --> E["_runDeepQuery(question, database)"]

    subgraph DEEP1["Fase 1 — deepQuery con o1"]
        E --> F["POST /deepQuery"]
        F --> G["execution_model: 'thinking'\nthinking_llm_provider: openai\nthinking_llm_model: o1\nthinking_llm_temperature: 1\nthinking_llm_max_tokens: 10240\nllm_provider: openai\nllm_model: gpt-4o-mini\nllm_temperature: 0\nllm_max_tokens: 4096\nembeddings_model: text-embedding-3-small\nvdp_database_names: {database}\nmax_analysis_loops: 50\nmax_concurrent_tool_calls: 5\ndefault_rows: 10"]
        G --> H{HTTP 200?}
        H -->|No| ERR["throw Exception\n'DeepQuery error {status}'"]
        H -->|Sí| I["deepResult:\n  answer: string\n  deepquery_metadata: object"]
    end

    I --> J["onPhaseChange:\n'Generando informe detallado...'"]
    J --> K["_generateDeepReport(metadata)"]

    subgraph DEEP2["Fase 2 — Generación de informe HTML"]
        K --> L["POST /generateDeepQueryReport"]
        L --> M["deepquery_metadata: {metadata}\ncolor_palette: 'red'\nmax_reporting_loops: 25\ninclude_failed_tool_calls_appendix: false\nthinking_llm_model: o1\nthinking_llm_temperature: 1\nllm_model: gpt-4o-mini\nllm_temperature: 0"]
        M --> N{HTTP 200?}
        N -->|No| ERR
        N -->|Sí| O["htmlReport = data['html_report']"]
    end

    ERR --> EH{tipo de\nexcepción}
    EH -->|TimeoutException| ET["'El análisis profundo tardó\ndemasiado. Simplifica...'"]
    EH -->|SocketException| ES["'No se puede conectar\ncon Denodo...'"]
    EH -->|Otro| EO["'Error inesperado: {msg}'"]

    O --> P["ApiResponse\n─────────────\nanswer: string\nhtmlReport: string HTML"]

    P --> FIN
    ET --> FIN
    ES --> FIN
    EO --> FIN

    FIN["ChatMessage añadido a sesión"] --> FIN2[status = done]
    FIN2 --> FIN3[notifyListeners]
    FIN3 --> FS{userId != null?}
    FS -->|Sí| FS2[FirestoreService.saveSession]
    FS -->|No| END([Fin])
    FS2 --> END
```

---

## 4. Renderizado de Respuesta en la UI

```mermaid
flowchart TD
    A([Nuevo ChatMessage en lista]) --> B[_MessageBubble]
    B --> C{isUser?}
    C -->|Sí| D["Burbuja gris\nalineada a la derecha"]
    C -->|No| E["Burbuja asistente\nalineada a la izquierda"]

    E --> F["MarkdownBody\nrenderiza tablas, negrita,\ncódigo, listas"]

    F --> G{apiResponse?\n.sqlQuery != null}
    G -->|Sí| H["_VqlReasoningTile\n(expandible/colapsable)\nmuestra VQL + explicación"]
    G -->|No| I

    H --> I{apiResponse?\n.rawGraph != null}
    I -->|Sí| J["_GraphCard\nSvgPicture.string decodifica\nbase64 → SVG"]
    J --> J2["Botón: Descargar gráfica\n→ saveSvgFile blob download"]
    J2 --> K
    I -->|No| K

    K --> L{"_parseMarkdownTable\n(content).isNotEmpty?"}
    L -->|Sí| M["Toggle: 'Ver como tarjetas'\n/ 'Ver como texto'"]
    M -->|showCards = true| N["_CandidateCardsView\nWrap de _CandidateCard\n─────────────────────\n• Círculo rank con color\n• Nombre + ID\n• Renta anual\n• Badges: Discap.\n  Orfandad, Fam.Num.\n  Reside Fuera"]
    M -->|showCards = false| O[MarkdownBody normal]
    L -->|No| P

    N --> P
    O --> P

    P --> Q{apiResponse?\n.relatedQuestions\n.isNotEmpty}
    Q -->|Sí| R["_RelatedQuestionsRow\nChips con preguntas sugeridas\n→ click: provider.sendMessage"]
    Q -->|No| S

    R --> S{apiResponse?\n.htmlReport != null}
    S -->|Sí - modo Deep| T["_ReportActions\n─────────────\n[Descargar HTML]\n[Imprimir PDF]\n[Enviar por correo]"]
    S -->|No - modo Turbo| U([Fin renderizado])

    T --> T1["Descargar HTML\n→ saveHtmlFile blob download\ninforme_{timestamp}.html"]
    T --> T2["Imprimir PDF\n→ printAsPdf\ninyecta window.print()\nabre blob en nueva pestaña"]
    T --> T3["Enviar por correo\n→ EmailService.sendReport"]
    T3 --> T4["POST api.resend.com/emails\nAuthorization: Bearer {apiKey}\nfrom: onboarding@resend.dev\nto: currentUser.email\nsubject: Informe — Adm. de Becas\nhtml: htmlReport"]
    T4 --> T5{HTTP 200/201?}
    T5 -->|Sí| T6["Botón → estado 'Enviado'\nSnackBar: Informe enviado a..."]
    T5 -->|No| T7["Botón → estado 'Error'\nMensaje de error inline"]
    T6 --> U
    T7 --> U
```

---

## 5. Gestión de Sesiones

```mermaid
flowchart TD
    A([Usuario autenticado]) --> B[Panel lateral\n_Sidebar]

    B --> C["_DatabaseSelector\nPopupMenuButton\ncon checkmark en seleccionada"]
    C -->|Cambia base de datos| D["selectDatabase db\n→ selectedDatabase = db\n→ _currentSession = null\n→ _loadSessionsFromFirestore"]

    B --> E["Botón: Nuevo chat"]
    E --> F["newChat()\nid = DateTime.now().milliseconds\ndatabase = selectedDatabase\nmessages = vacía"]
    F --> G[Añadir a _sessions\nsetear como _currentSession]

    B --> H["_SessionTile por cada sesión\nTítulo = customTitle ?? primer mensaje del usuario (32 chars)"]
    H -->|Tap en sesión| I["loadSession(session)\n→ _currentSession = session"]
    H -->|Menú: Renombrar| J["AlertDialog con TextField\nrenameSession id, nuevoTítulo"]
    J --> K["session.customTitle = título\nnotifyListeners\nFirestoreService.saveSession"]
    H -->|Menú: Eliminar| L["deleteSession id\n→ _sessions.remove\n→ si era actual: _currentSession = null\n→ FirestoreService.deleteSession"]

    B --> M["_UserTile\nAvatar + email del usuario\nBotón Cerrar sesión"]
    M --> N["AuthService.signOut\n→ Firebase signOut\n→ authStateChanges emite null\n→ LoginScreen"]

    subgraph FS["Persistencia en Firestore"]
        O["Estructura:\nusers/{uid}/sessions/{sessionId}\n─────────────────────────────\ndatabase: string\ncustomTitle: string?\nmessages: lista de content+isUser\nupdatedAt: timestamp"]
    end

    K -.-> FS
    L -.-> FS
    D -.-> FS
    G -.->|Al enviar el primer mensaje| FS
```

---

## 6. Parseo de Tabla Markdown → Tarjetas de Candidatos

```mermaid
flowchart TD
    A(["_parseMarkdownTable(content)"]) --> B["Regex: busca bloques\nque empiecen con '| '"]
    B --> C{¿Hay filas\nde tabla?}
    C -->|No| Z([Lista vacía])
    C -->|Sí| D[Extraer fila de cabeceras\nEliminar fila separadora]
    D --> E[Normalizar cabeceras\nen minúsculas sin espacios]
    E --> F[Por cada fila de datos]
    F --> G[Mapear columnas]
    G --> H{"Columna 'nombre'\no 'name'?"}
    H -->|Sí| I[nombre = valor]
    H -->|No| J
    G --> K{"Columna 'renta'\no 'renta_anual'?"}
    K -->|Sí| L[renta = valor]
    K -->|No| J
    G --> M{"Columna 'rank'\no 'ranking'?"}
    M -->|Sí| N[rank = valor]
    M -->|No| O[rank = índice+1]
    G --> P["Columnas bool:\ndiscapacidad, orfandad\nfamilia_numerosa, reside_fuera"]
    P --> Q["true si: sí/si/yes/true/1\nfalse si: no/false/0"]
    G --> J[Resto → extraFields map]
    I & L & N & O & Q & J --> R["Candidate objeto\n─────────────\nrank: int\nnombre: string\nrenta: string\ndiscapacidad: bool\norfandad: bool\nfamiliaNumerosa: bool\nresideFuera: bool\nextraFields: Map"]
    R --> S([Lista de Candidate])
    S --> T["_CandidateCard renderiza:\n• Círculo rank: oro/plata/bronce/rojo\n• Nombre bold\n• Renta anual\n• Badges coloreados por estado\n• Campos extra del API"]
```
