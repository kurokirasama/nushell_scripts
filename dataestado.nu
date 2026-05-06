# DataEstado API Wrapper module
# API Documentation: https://dataestado.cl/docs

const BASE_URL = "https://api.dataestado.cl/v1"

# --- General ---

# Get the health status of the DataEstado API
export def "dataestado health" [] {
    http get ([$BASE_URL ".." "health"] | str join "/")
}

# Perform a global search across ministries, persons, authorities, and governments
export def "dataestado search" [
    query: string # Search term
] {
    _get-api "search" {q: $query}
}

# --- Autoridades ---

# List government authorities with optional filters and pagination
export def "dataestado autoridades" [
    --gobierno(-g): string # Filter by government name (e.g., Boric, Frei)
    --page(-p): int        # Page number (1-based)
    --limit(-l): int = 100 # Number of results per page
] {
    let offset = if ($page != null) { ($page - 1) * $limit } else { null }
    let query = {} | upsert gobierno $gobierno | upsert offset $offset | upsert limit $limit
    _get-api "autoridades" ($query | compact gobierno offset limit)
}

# Get authorities for a specific government
export def "dataestado autoridades gobierno" [
    nombre: string # Government name
] {
    _get-api $"autoridades/gobierno/($nombre)"
}

# Get authorities for a specific ministry by name search
export def "dataestado autoridades ministerio" [
    nombre: string # Ministry name (partial match)
] {
    _get-api $"autoridades/ministerio/($nombre)"
}

# Get authorities for a specific ministry by its stable code
export def "dataestado autoridades ministerio-codigo" [
    codigo: string         # Ministry code (e.g., min-hacienda)
    --page(-p): int        # Page number (1-based)
    --limit(-l): int = 100 # Number of results per page
] {
    let offset = if ($page != null) { ($page - 1) * $limit } else { null }
    let query = {} | upsert offset $offset | upsert limit $limit
    _get-api $"autoridades/ministerio/codigo/($codigo)" ($query | compact offset limit)
}

# Get aggregate statistics for authorities by government
export def "dataestado autoridades estadisticas" [] {
    _get-api "autoridades/estadisticas"
}

# --- Personas ---

# List registered persons with optional pagination and search
export def "dataestado personas" [
    --search(-s): string   # Search by name
    --page(-p): int        # Page number (1-based)
    --limit(-l): int = 50  # Number of results per page
] {
    let offset = if ($page != null) { ($page - 1) * $limit } else { null }
    let query = {} | upsert q $search | upsert offset $offset | upsert limit $limit
    _get-api "personas" ($query | compact q offset limit)
}

# Get summary profile for a specific person
export def "dataestado personas ficha" [
    id: int # Person ID
] {
    _get-api $"personas/($id)"
}

# Get full career trajectory for a specific person
export def "dataestado personas trayectoria" [
    id: int # Person ID
] {
    _get-api $"personas/($id)/trayectoria"
}

# --- Gobiernos ---

# List available governments and presidential ranges
export def "dataestado gobiernos" [] {
    _get-api "gobiernos"
}

# --- Ministerios ---

# List current ministries and their current authorities
export def "dataestado ministerios" [] {
    _get-api "ministerios"
}

# Get full details for a specific ministry by ID
export def "dataestado ministerios ficha" [
    id: int # Ministry ID
] {
    _get-api $"ministerios/($id)"
}

# Get full details for a specific ministry by its stable code
export def "dataestado ministerios codigo" [
    codigo: string # Ministry code (e.g., min-hacienda)
] {
    _get-api $"ministerios/codigo/($codigo)"
}

# Get historical list of authorities for a specific ministry by ID
export def "dataestado ministerios historial" [
    id: int # Ministry ID
] {
    _get-api $"ministerios/($id)/historial"
}

# --- Utility Commands ---

# Get a comprehensive profile of a person, including summary and trajectory
export def "dataestado personas profile" [
    id: int # Person ID
] {
    let ficha = (dataestado personas ficha $id)
    let trayectoria = (dataestado personas trayectoria $id)
    $ficha | insert trayectoria $trayectoria
}

# Get all authorities of a specific ministry by its code
export def "dataestado ministerios authorities-history" [
    codigo: string # Ministry code (e.g., MIN_HACIENDA)
] {
    let info = (dataestado ministerios codigo $codigo)
    let id = $info.id
    dataestado ministerios historial $id
}

# Summarize all governments in a clean table
export def "dataestado gobiernos summary" [] {
    dataestado gobiernos 
    | select nombre presidente fecha_inicio fecha_termino
}

# Summarize all ministries in a clean table
export def "dataestado ministerios summary" [] {
    dataestado ministerios
    | select id codigo nombre sigla sitio_web
}

# --- Helpers ---

# Internal helper for API requests
def _get-api [path: string, query: record = {}] {
    let q = if ($query | is-empty) { "" } else { 
        "?" + ($query | url build-query)
    }
    let url = $"($BASE_URL)/($path)($q)"
    http get $url
}
