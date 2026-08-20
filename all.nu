# Master loader for personal Nushell productivity toolkit
# Sources all toolkit scripts into the global namespace in strict topological dependency order

use std
use std-rfc
use /home/kira/software/nu-rich/rich *

# Core Utilities & Primitives (Topological Dependency Order)
source /path/to/scripts/date_formats.nu
source /path/to/scripts/python.nu
source /path/to/scripts/aliases.nu
source /path/to/scripts/string_manipulation.nu
source /path/to/scripts/table_manipulation.nu
source /path/to/scripts/files.nu
source /path/to/scripts/tasker.nu
source /path/to/scripts/crypt.nu
source /path/to/scripts/def_data.nu
source /path/to/scripts/def_system.nu
source /path/to/scripts/def_app.nu
source /path/to/scripts/def_file_compilers.nu
source /path/to/scripts/def_dev.nu
source /path/to/scripts/maths.nu
source /path/to/scripts/system.nu
source /path/to/scripts/gcal.nu
source /path/to/scripts/media.nu
source /path/to/scripts/apis.nu
source /path/to/scripts/obsidian.nu
source /path/to/scripts/habitica.nu
source /path/to/scripts/network.nu
source /path/to/scripts/backups.nu
source /path/to/scripts/update_apps.nu
source /path/to/scripts/transmission.nu
source /path/to/scripts/yandex.nu
source /path/to/scripts/yt_api.nu
source /path/to/scripts/plots.nu
source /path/to/scripts/zoxide.nu
source /path/to/scripts/weather_tomorrow.nu
source /path/to/scripts/alias_defs.nu
source /path/to/scripts/ai_google.nu
source /path/to/scripts/ai_chatpdf.nu
source /path/to/scripts/ai_claude.nu
source /path/to/scripts/ai_elevenlabs.nu
source /path/to/scripts/ai_ollama.nu
source /path/to/scripts/ai_openai.nu
source /path/to/scripts/ai_stablediffusion.nu
source /path/to/scripts/ai_deepl.nu
source /path/to/scripts/ai_tools.nu
source /path/to/scripts/ai_privategpt.nu
source /path/to/scripts/github.nu
source /path/to/scripts/gmn_automatons.nu
source /path/to/scripts/git_tools.nu
source /path/to/scripts/dataestado.nu
source /path/to/scripts/ghome.nu
source /path/to/scripts/appimages.nu
source /path/to/scripts/ghome_cron.nu
source /path/to/scripts/agents_longterm_memory.nu
source /path/to/scripts/tv_calendar.nu
source /path/to/scripts/linecast_completions.nu
source /path/to/scripts/manga.nu