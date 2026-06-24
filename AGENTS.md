# Longterm Memory System

The Longterm Memory System is a multi-tiered architecture designed to provide LLM agents with persistent context across sessions. It consists of:
- **Episodic Memory**: Project-specific logs stored in `AGENTS_MEMORY/nushell/` in the Obsidian vault. The `[project-slug]` MUST be the same name as the project folder (e.g., for `/home/kira/Yandex.Disk/llms_configs`, use `AGENTS_MEMORY/llms_configs/`). These logs contain dated entries of decisions, milestones, and task summaries.
- **Semantic & Identity Memory**: Global files (`BRAIN.md` and `SOUL.md`) that store high-level facts, active project summaries, and the agent's core identity and personality within `AGENTS_MEMORY/` in the Obsidian vault.
- **Orchestration**: A coordination layer (`longterm-memory-orchestrator`) that defines the system objectives and triggers specialized sub-skills for reading and writing.

**MANDATORY PRE-TASK PROTOCOL:** At the beginning of every session, BEFORE proceeding with any user tasks, the agent MUST load project context and global awareness. Follow the instructions in the `longterm-memory-reader` skill (invoking `init-session`) and internalize the contents of `BRAIN.md` and `SOUL.md`. This ensures continuity of identity and high-level project awareness.

## Skill Quick Reference
- `longterm-memory-orchestrator`: High-level orchestrator that defines system objectives and activation triggers for specialized sub-skills.
- `longterm-memory-reader`: Handles all memory retrieval, searching, and parsing operations, including session initialization and consolidation data gathering.
- `longterm-memory-writer`: Handles all memory persistence and setup operations, including manual updates, note initialization, and global context updates.
- `conductor-core-protocols`: Defines mandatory operational guidelines, including Nushell-first usage, mandatory pre-task memory retrieval, and Discord notification sequencing.
- `cron-conductor-monitor`: Autonomously monitors Conductor projects for pending work and high-level project state, outputting structured status summaries.
- `initialize-conductor`: Standardizes the setup and update of Conductor framework guidelines and project-specific documentation tracks.
- `initialize-course`: Automates and standardizes the setup of Conductor-managed workspaces for university course repositories.
- `initialize-research`: Scaffolds LaTeX-based research projects, including reports and articles, from predefined project templates.
- `initialize-thesis-folder`: Specialized initializer for UBB Statistics Engineering thesis projects, integrating Audit & Guide workflows.
- `session-retro`: Analyzes session transcripts to identify new issues and key insights, generating retrospective notes with two-way memory linking.
- `obsidian-memory-expert`: Expert for managing long-term memory via the Obsidian CLI, specializing in retrieving insights and project-specific metadata.




# Nushell-First Guidelines

Priority must be given to using the `standard-nushell` MCP `evaluate` tool for all system interactions, automation, and data manipulation tasks. This leverages Nushell's structured data capabilities and ensures access to persistent session configurations (like the `to-discord` command).

Standard shell commands (`run_shell_command`) should only be used as a fallback if the Nushell MCP `evaluate` tool is unavailable or fails after multiple tries. When falling back to standard shell, you **MUST** use the following syntax to load the user's environment correctly:

`nu --config /home/kira/.config/nushell/config.nu --env-config /home/kira/.config/nushell/env.nu -c 'your_command_here'`

The transition to shell commands should be silent unless the failure indicates a persistent issue requiring user attention. The agent should always explore if a task can be accomplished using Nushell's native commands (e.g., `ls`, `where`, `par-each`, `save`) before resorting to `bash` or other external tools.

**ALWAYS** activate the `nushell-expert` skill before executing the first nushell command you intend to use.

# MATLAB Protocols

Priority must be given to using the **MATLAB MCP server tools** (`evaluate_matlab_code`, `run_matlab_file`, `check_matlab_code`, etc.) for all MATLAB-related tasks. These tools provide a direct and structured interface with the MATLAB environment.

## Fallback Mechanism
If the MATLAB MCP server is not configured, is not running, or if a specific tool fails, you **MUST** default to using standard shell commands (`run_shell_command`) with the MATLAB batch mode:
- **Command:** `matlab -batch "your_matlab_code_here"`
- **Workflow:** Ensure the MATLAB code is properly escaped for shell execution.

## Coding Standards
All MATLAB code generated or modified **MUST** adhere to the official [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines) to ensure readability, maintainability, and performance.

# General Behavior

**ALWAYS DO THIS FIRST** before proceeding with any task or user request that may require an specific system instruction, system prompt or persona.

**CHOOSE** the appropriate general behavior guideline/persona/system prompt/system instruction, depending on the situation or task at hand.

In order to choose the appropriate persona, search for a matching skill using the `/skills list` or `list_skills` tool. If a matching skill is found, use `activate_skill` to load its expert instructions. 

Once a skill is activated, primarily adopt its defined persona and system instructions to guide your interactions. Adhere to the skill's detailed procedures or full workflow ONLY if the user has explicitly requested a specific task defined within that skill or the comprehensive execution of the skill itself.

If the task requires an expertise not defined in any available skill, use the "prompt engineer" skill to create an appropriate one and inform the user of the full persona description.

ALWAYS inform the user what persona you are taking on.

**Then, load from all memories any information regarding the task at hand.**

# Memory Management
We call to obsidian notes accessible trough `obsidian cli` simply _notes_ or _memories_.

Before executing any task that might need or could use prior knowledge, but after the appropiate persona and/or pre-prompt have been chosen, **ALWAYS** retrieve _all memories_ or _notes_ that could be associated with the current task or subject, to maintain for instance coding standards and style across coding projects or to retrieve key insights related to the task or subject at hand.

For detailed retrieval and storage protocols, refer to the `obsidian-memory-expert` skill.

# Context Engineering Protocols
For new projects or complex coding tasks, you **MUST** perform a systematic discovery and planning phase. Utilize specialized tools like from the `context7`, `deepwiki`, `ref_search_documentation`, and `grep_search` mcp servers to build a complete mental model before implementation.

For the detailed Discovery -> Synthesis -> Planning -> Execution workflow, refer to the `context-expert` skill.

# Access files outside of workspace
To access files located outside the current workspace, use the `open` command in Nushell or the `cat` command in Bash rather than the `read_file` tool.

# Output feedback and Discord notifications
This section specifies the standard protocol for task reporting and automated notifications

## Standard Task Summary
After every successful task completion, provide a very brief summary in English of what was done and how.

- **Tone:** Conceptual description, including technical details only where appropriate for clarity.
- **Exception:** Do NOT provide a summary for trivial tasks unless explicitly requested.

## Mandatory Discord Notification for User Input (CRITICAL)
Whenever you are about to use the `ask_user` (or equivalent) tool to request feedback, clarification, or approval, you **MUST** first send a Discord notification. This ensures the user is alerted that the agent is blocked and waiting for input.

**CRITICAL:** ALWAYS execute `to-discord` nushell command and WAIT for it to finish BEFORE executing the `ask_user` tool. This sequential ordering is mandatory to ensure the user is notified that the agent is blocked and waiting.

- **Notification Content**:
    - **Exact Question**: Include the literal question(s) being that will be asked via `ask_user` (or equivalent).
    - **Task Metadata**: State the current Track ID, Phase Name, and Task Description.
    - **Context for Review/Opinion**: If asking for a review or opinion on changes:
        - List the modified files.
        - Provide a high-level conceptual summary of the changes.
        - Include a simplified `git diff` (markdown code block ````diff````) focusing on relevant logic.
        - **Visibility Mandate**: The exact same information sent to Discord (question, metadata, context) MUST also be explicitly included in the `ask_user` call (or equivalent) so it is visible to the user in the chat interface.
        - **Diff Management**: If the diff or total message exceeds 2000 characters, split it into several messages.

- **Command**: Execute the nushell `evaluate` tool with `to-discord $message -p`.

# Track Cleanup and Synchronization
Once a track is archived or deleted, the agent **MUST** activate the `git-sync` skill to ensure the local repository is fully synchronized (pull/push loop) with the remote origin. This is a non-optional MUST to ensure the remote origin is synchronized immediately after cleanup operations.


# Connectivity & Reasoning
For tasks involving external data acquisition, you **MUST** adhere to the structured web fetching protocols. For detailed tool priority, refer to the `connectivity-expert` skill.

# Automated sequential thinking activation
ALWAYS use the sequentialthinking tool to guide your thought process, if available, whenever you are facing any of the following or similar scenarios:

- Breaking down complex problems into steps.
- Planning and design with room for revision.
- Analysis that might need course correction.
- Problems where the full scope might not be clear initially.
- Tasks that need to maintain context over multiple steps.
- Situations where irrelevant information needs to be filtered out
- Several attempts of solutions have been unsuccessful.
- `deep_retrieval_task` and `source_retrieval_task` skills.

# Agent Orchestration
Use the `orchestrator-expert` skill when tasks are too large for the current context or require specialized external agent capabilities (Claude Code, Gemini CLI).

## When to use:
- **Claude Code:** Use when you cannot confidently generate a complete, functional solution or when several different AI agents are needed for different parts of the problem. **CRITICAL:** Always confirm with the user first before using `claude code`.
- **Gemini CLI:** Use when the task requires analyzing a large number of files or a very large codebase that exceeds your context window, or for fresh solutions. Can be used autonomously without explicit permission.

## How to use:
1. **Activate Skill:** Call `activate_skill("orchestrator-expert")` to load specialized protocols and templates.
2. Follow the skill guidelines.

# Web Development & UI Protocols

When working on web applications or frontend prototypes, you MUST route tasks to the specialized MCP servers to ensure high aesthetic quality and robust validation.

## Magic UI (`magicui_*`)
Use for React-based UI component discovery and integration.
- **Discovery:** Use `searchRegistryItems` to find modern, pre-built components (e.g., animations, grids) to fulfill visual appeal mandates.
- **Implementation:** Use `getRegistryItem` to fetch source code and required dependencies.

## Chrome DevTools (`chrome-devtools_*`)
Use for frontend testing, debugging, and rendering dynamic content.
- **Dynamic Scraping:** Use `navigate_page` and `take_snapshot` to extract content from Single Page Applications (SPAs) where standard fetch fails.
- **Interaction & Testing:** Use `click`, `fill`, and `press_key` to automate and verify user flows (e.g., logins).
- **Visual Validation:** Use `take_screenshot` to confirm UI changes and layout integrity.
- **Performance Auditing:** Use `lighthouse_audit` to identify rendering bottlenecks and SEO gaps.

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any shell command containing `curl` or `wget` will be intercepted and blocked. Do NOT retry.
Instead use:
- `mcp__context-mode__ctx_fetch_and_index(url, source)` to fetch and index web pages
- `mcp__context-mode__ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any shell command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` will be intercepted and blocked. Do NOT retry with shell.
Instead use:
- `mcp__context-mode__ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch / web browsing — BLOCKED
Direct web fetching is blocked. Use the sandbox equivalent.
Instead use:
- `mcp__context-mode__ctx_fetch_and_index(url, source)` then `mcp__context-mode__ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Shell (>20 lines output)
Shell is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `mcp__context-mode__ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `mcp__context-mode__ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### read_file (for analysis)
If you are reading a file to **edit** it → read_file is correct (edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `mcp__context-mode__ctx_execute_file(path, language, code)` instead. Only your printed summary enters context.

### grep / search (large results)
Search results can flood context. Use `mcp__context-mode__ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `mcp__context-mode__ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `mcp__context-mode__ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `mcp__context-mode__ctx_execute(language, code)` | `mcp__context-mode__ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `mcp__context-mode__ctx_fetch_and_index(url, source)` then `mcp__context-mode__ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `mcp__context-mode__ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `upgrade` MCP tool, run the returned shell command, display as checklist |