# Obsidian CLI vs. `obsidian.nu` Comparison Report

## 1. Executive Summary
The official Obsidian CLI (v1.12+) provides a robust, native way to interact with your vault from the terminal. It eliminates the overhead of managing the Local REST API (keys, ports, SSL) and offers deeper integration with Obsidian features like Properties, Tasks, and Sync.

**Recommendation**: **Transition to Obsidian CLI** for all core operations. Use Nushell wrappers only to maintain the interactive "selection" UX that you currently enjoy (e.g., choosing a note from search results).

## 2. Feature Parity & Mapping

| `obs` Command | CLI Equivalent | Status | Notes |
| :--- | :--- | :--- | :--- |
| `obs search` | `obsidian search` | **Superior** | CLI supports JSON output and context-aware grep. |
| `obs create` | `obsidian create` | **Superior** | Native template support and overwrite flags. |
| `obs check` | N/A | **Redundant** | CLI connects automatically; no manual server check needed. |
| `obs check-path` | `obsidian file` | **Equivalent** | CLI returns structured metadata. |
| (New) | `obsidian property:*` | **New** | Native frontmatter/property management. |
| (New) | `obsidian tasks` | **New** | Specialized task filtering and status toggling. |

## 3. Deep Dive: Core Commands

### `obs search`
- **Current (`obsidian.nu`)**: Hits `/search/simple`, pipes to `input list`, then `glow`s content.
- **CLI (`obsidian search`)**: 
  - `obsidian search query="term" format=json` returns a list of matching paths.
  - **Proposed Replacement**:
    ```nu
    def "obs search" [...query: string] {
        let q = ($query | str join " ")
        let selection = (obsidian search $"query=($q)" format=json | from json | get path | input list)
        if ($selection | is-not-empty) {
            obsidian read $"path=($selection)" | glow
        }
    }
    ```

### `obs create`
- **Current (`obsidian.nu`)**: Interactive folder selection, then PUT request.
- **CLI (`obsidian create`)**: Native support for name, path, content, and templates.
- **Proposed Replacement**:
    ```nu
    def "obs create" [name: string, content: string, --path: string] {
        # Keep your interactive folder selection logic from obsidian.nu
        let target_path = if ($path | is-empty) { ... selection logic ... } else { $path }
        obsidian create $"name=($name)" $"content=($content)" $"path=($target_path)"
    }
    ```

## 4. Nushell Integration Analysis
The official CLI is highly compatible with Nushell's philosophy:
- **Structured Output**: Many commands support `format=json`, allowing direct piping to `from json`.
- **Exit Codes**: Proper exit codes for scripting and error handling.
- **Piping**: Note content can be read from or written to via stdout/stdin (using `--copy` and `read` / `append` / `prepend`).
- **Developer Tools**: `obsidian eval` allows executing arbitrary JavaScript within the Obsidian context, a powerful tool for complex automations.

## 5. Conclusion
Replacing the custom REST-based logic with the official CLI will result in a more maintainable, faster, and feature-rich toolkit. The CLI handles the low-level communication, while Nushell can continue to provide the high-level interactive interface.
