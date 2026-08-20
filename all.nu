# Master loader for personal Nushell productivity toolkit
# Sources all toolkit scripts into the global namespace in strict topological dependency order

use std
use std-rfc
use ~/software/nu-rich/rich *

# Core Utilities & Primitives (Topological Dependency Order)
source ./date_formats.nu
source ./python.nu
source ./aliases.nu
source ./string_manipulation.nu
source ./table_manipulation.nu
source ./files.nu
source ./tasker.nu
source ./crypt.nu
source ./def_data.nu
source ./def_system.nu
source ./def_app.nu
source ./def_file_compilers.nu
source ./def_dev.nu
source ./maths.nu
source ./system.nu
source ./gcal.nu
source ./media.nu
source ./apis.nu
source ./obsidian.nu
source ./habitica.nu
source ./network.nu
source ./backups.nu
source ./update_apps.nu
source ./transmission.nu
source ./yandex.nu
source ./yt_api.nu
source ./plots.nu
source ./zoxide.nu
source ./weather_tomorrow.nu
source ./alias_defs.nu
source ./ai_google.nu
source ./ai_chatpdf.nu
source ./ai_claude.nu
source ./ai_elevenlabs.nu
source ./ai_ollama.nu
source ./ai_openai.nu
source ./ai_stablediffusion.nu
source ./ai_deepl.nu
source ./ai_tools.nu
source ./ai_privategpt.nu
source ./github.nu
source ./gmn_automatons.nu
source ./git_tools.nu
source ./dataestado.nu
source ./ghome.nu
source ./appimages.nu
source ./ghome_cron.nu
source ./agents_longterm_memory.nu
source ./tv_calendar.nu
source ./linecast_completions.nu
source ./manga.nu