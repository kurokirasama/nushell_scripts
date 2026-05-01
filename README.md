# nushell scripts
My collection of Nushell custom commands/functions. 

## Installation
First, clone the repo somewhere you like:
```bash
git clone https://github.com/kurokirasama/nushell_scripts
```

### Credentials
- The `credentials.json.asc` file is an encrypted file with the necessary credentials and API keys that are loaded into `$env.MY_ENV_VARS.api_keys` in `env_vars.nu`. 
- The credentials and API keys services I use in this project are in `credentials_example.json`
- For encryption, you need the `gpg` tool installed. You can encrypt and decrypt using the commands in `crypt.nu`.

### Edit `env_vars.nu`
Modify `$env.PATH` and `$env.MY_ENV_VARS` in `$env_vars.nu` according to your settings.

### Nushell config
#### Linux
1. Modify `append_to_config.nu` and replace with the path to this repo.
2. Take the content of `append_to_config.nu` and copy it at the end of the config.nu file. Or, you can run:
```nu
open append_to_config.nu | save --append $nu.config-path
```
3. Restart Nushell.

#### Windows
1. Take the content of `append_to_config_win.nu` and copy it at the end of the `config.nu` file. Or, you can run:
```nu
open append_to_config_win.nu | save --append $nu.config-path
```
2. Restart Nushell.

## Files description
### AI Tools
The AI tools are a collection of scripts that provide a comprehensive suite of tools for interacting with various AI services. These tools are organized into separate files based on the service they interact with:

*   `ai_chatpdf.nu`: Manage and query PDFs with ChatPDF.
*   `ai_claude.nu`: Interact with Anthropic's Claude models.
*   `ai_deepl.nu`: Translate text using the DeepL API.
*   `ai_elevenlabs.nu`: Generate speech from text using ElevenLabs API.
*   `ai_google.nu`: Interact with Google's Gemini and Imagen models.
*   `ai_ollama.nu`: Interact with local Ollama models.
*   `ai_openai.nu`: Interact with OpenAI's ChatGPT and DALL-E models.
*   `ai_stablediffusion.nu`: Generate images using Stable Diffusion models.
*   `ai_tools.nu`: A collection of general AI-related tools and wrappers that provide a unified interface to the other AI scripts.

These scripts facilitate tasks such as transcription, summarization, image generation, and text-to-speech conversion, streamlining the integration of AI capabilities into users' workflows and enhancing productivity and automation within the Nushell environment.

### alias_def
These custom functions for Nushell provide a variety of utilities for streamlining tasks on a Unix-like system. These functions allow users to analyze code statistics, manage keybindings, navigate to the nu configuration directory, monitor core temperatures, check battery stats, view listening ports, connect to a Bluetooth headset, gather RAM usage data, interface with YouTube through a command-line client, and perform ADB operations for Android devices. Each function is designed to execute a specific task, such as retrieving system information, manipulating environmental settings, or integrating with external applications and devices, all from within the Nushell environment.


### apis
This set of custom functions for Nushell includes a variety of utilities that enhance productivity through automation. There are functions for URL shortening, leveraging services such as Bitly and Rebrandly, complete with clipboard integration for ease of use. Translation capabilities are provided, allowing text to be translated between languages with options to use the MyMemory or OpenAI API. Geo-location functions offer the ability to get coordinates from addresses and vice versa, as well as calculate estimated travel times and directions using Google Maps API. Financial tools include functions to obtain exchange rates from the Fixer.io API with custom currency support. Additionally, there's integration with Google Translate for text translations and with the Joplin note-taking application for searching and editing notes. Each function is designed to interact with external APIs or services, and they often include error handling, API key management, and user interaction for input and selections.

### autolister
Standalone script that get the list of files in provided directory recursively. It is used within `pre_execution_hook.nu` file. 

### backups
These custom functions collectively offer a set of utilities to backup and restore configurations/settings for various applications including Sublime Text, nchat, GNOME shell extensions, and LibreOffice. They also include a function to update Sublime Text syntax highlighting for Nushell commands and another to backup Nushell history. The backup functions typically compress configuration files into `7z` archives or copy them to a backup directory, while the restore functions extract these archives or copy the files back to their original locations. The syntax update function generates a list of nushell commands, including built-ins, plugins, custom commands, keywords, and aliases, and integrates them into the Sublime Text syntax file, with an option to push changes to a repository if specified. Lastly, the history backup function vacuums the nushell command history into a specified output file.

### config
This script job is to configure the shell environment, modifying settings and adding hooks, menus, keybindings, and other elements to enhance user interaction. It adjusts color schemes for different commands based on environmental variables, set preferences for table display, file size color coding, and history file format. It includes hooks to update the shell prompt with Git status and network connectivity, execute scripts before commands, and adjust the environment upon directory changes. It also defines a custom menu for aliases with specific layout and style settings, and they incorporate new keybindings for actions like opening the alias menu, reloading the config, updating the prompt, inserting new lines, and recalling the last argument. The table trim settings are set for truncating long text with an option to keep words together, and the overall configuration is updated to the environment. Additionally, it includes a playful element that fetches a random joke from an online source.

### crypt
These custom functions offer a suite of tools for encrypting, decrypting, and managing credentials. The `nu-crypt` function performs symmetric encryption or decryption on files using GPG, with additional options for suppressing UI prompts and specifying output files for decryption. The `open-credential` function decrypts and parses a JSON file containing credentials, with a UI-toggle option. Lastly, the `save-credential` function updates or adds new credentials to a JSON file, encrypts it, and then removes the unencrypted file, ensuring sensitive information is securely stored. All functions have built-in error handling for invalid flag combinations or missing arguments.

### debloat
This script is collection of commands designed for managing apps on Xiaomi devices using Android Debug Bridge (ADB) commands. It includes commands to uninstall and disable various pre-installed apps and services from the device. The uninstallation commands target Facebook-related apps, while the disablement commands are categorized into three safety levels: safe, supposedly safe, and uncertain. The safe category addresses Xiaomi and MIUI specific apps and services, the supposedly safe category includes a mix of Xiaomi, Google, and other apps, and the not sure category is commented out, indicating ambivalence about the impact of disabling those apps. These functions would help users to debloat their smartphone by removing or disabling unwanted system apps to improve performance and privacy.

### defs
These custom functions provided for nushell aim to enhance the command line experience by offering a variety of utilities. These functions include searching within files or streams with highlighting, copying the current working directory to the clipboard, converting Excel files to CSV, checking if a drive is mounted, retrieving phone numbers from Google contacts, and launching the mcomix application. Additionally, they facilitate obtaining download information from JDownloader, summarizing source file information for nushell scripts, executing web searches from the terminal, marking Habitica dailies as complete, and setting countdown alarms with audible notifications.

Other functions check the validity of web links, send emails via Gmail with signature files, reset Alpine mail client authentication, run MATLAB in CLI mode, download all files with specific extensions from a webpage using wget, compile LaTeX documents, check the status of Maestral (Dropbox client), generate QR codes, compact data by removing empty strings and nulls, serve a local HTTP server, and even open the balenaEtcher app. Each function is designed to perform a specific task, streamlining various operations that a user might need to perform in a Unix-like environment.

### env_change_hook
These custom functions provided perform a series of operations to manage and update the size information of the current working directory (PWD). Initially, it ensures the existence of a `.pwd_sizes.json` file, creating it from a backup if necessary. It then checks conditions such as the time elapsed since the last update and whether the current directory is part of a Google Drive. Based on these conditions, it calculates the size of the PWD, excluding any Google Drive subdirectories, and updates an environment variable accordingly. If the PWD size information is outdated or missing, it recalculates the size and then updates the `.pwd_sizes.json` file with the new size and the current timestamp. The function is careful to exclude updates for Google Drive directories and ensures that the size information is refreshed only after a specified interval, which is set to 12 hours in this case.

### env_vars
These nushell custom functions serve to configure the shell environment with a variety of settings and behaviors. The `$env.PATH` is extended with additional directories, including various user-specific paths and system binaries. The `PROMPT_COMMAND` constructs a dynamic prompt that changes color based on the last command's exit code and displays different symbols and path sizes depending on whether the current directory is the home directory or elsewhere, as well as Git status information. The `PROMPT_COMMAND_RIGHT` is designed to show weather information and command duration on the right side of the prompt, but only if the terminal is wide enough. The `PROMPT_INDICATOR` changes color based on the success of the previous command. The `BROWSER` variable is set to use "lynx," and `LS_COLORS` is configured to colorize file listings. The shell environment also includes a custom `MY_ENV_VARS` hashmap that holds various user-defined variables and paths, which are set and updated using the `upsert` function. Additionally, `PAGER` is set to "less," and `VISUAL` is set to "nano," to define the default pager and editor. Finally, `api_keys` are loaded into `MY_ENV_VARS` from an encrypted JSON file.

### gcal
These nushell custom functions provide a convenient wrapper for interacting with Google Calendar using the `gcalcli` tool. They enable users to add events, as well as view their agenda, weekly, or monthly calendar, with options to specify details such as calendar selection, event title, date, location, and duration. The functions are flexible, allowing for both full calendar visibility and the inclusion of additional flags for detailed customization. Users can also invoke these commands without arguments, prompting them for the necessary inputs. Overall, these functions are designed to streamline the process of managing Google Calendar events directly from nushell.

### geek
These custom nushell functions provide a suite of tools designed to interface with the Geeknote command-line client for Evernote. They offer a variety of operations such as searching for notes with "geek find," displaying note content with "geek show," editing notes via "geek edit," and creating new notes using "geek create." Additionally, there is a function for exporting notes to ENEX files named `geek export`, which automatically installs the necessary `evernote-backup` package if it isn't already present. These functions streamline the process of managing Evernote notes from the command line, adding extra features like handling additional flags and formatting output for improved readability.

### get-ips
The custom Nushell function outlined here is designed to determine both the internal and external IP addresses of a device. It takes an optional parameter to specify the network device, defaulting to 'wlo1' for Wi-Fi or 'eno1' for a LAN connection, based on the hostname and a predefined environment variable. The function retrieves the system's hostname and decides the network device based on the provided argument or environment settings. It then fetches the local (internal) IP address corresponding to the chosen network device and queries an external service to get the external IP address. The function returns a JSON object containing both IP addresses. This script is used by `pre_execution_hook.nu`.

### github
These custom functions facilitate various scripting operations related to repository management and file synchronization. They include a function to selectively copy non-private scripts from a private directory to a public repository and commit the changes. Another function clones a private backup repository of Ubuntu onto the local machine. There's also an alias named `quantum` that updates a private repository with the contents of a private Linux backup directory, with options to force the copy, update the public nushell scripts repository, and upload Debian package files to Google Drive. Lastly, there's a function dedicated to uploading new or updated Debian package files to Google Drive if they are newer than the files already present, ensuring that the remote storage is kept current with local changes. These functions are designed to streamline the process of maintaining and synchronizing script files and software backups between local and remote locations.

### jdown
This script is a Python-based wrapper for JDownloader, using the `myjdapi` library to interact with JDownloader instances. It defines a main function that handles command-line arguments to select a specific JDownloader device configuration, connects to a given user's JDownloader account, retrieves the device using its label (which could be 'dev1' or 'dev2'), and queries the download packages. It compiles detailed information about each download, including UUID, name, host, child count, ETA, speed, and the amount of data loaded versus the total data size (both in megabytes), and outputs this as a JSON-formatted list. If no downloads are found or the specified device is not found, it prints an appropriate message and exits. The script is meant to be executed directly and requires the `myjdapi` library to be installed.

### lister
This script offer a set of file manipulation and information retrieval capabilities within a specified directory structure. The `main` function processes a JSON file from a given directory, extracts and manipulates file path information, and ultimately saves the processed data back into a structured file format. It involves getting a list of files, dropping certain attributes, parsing file paths, and renaming components before appending the information into a final format. The `get-files` function is a utility that facilitates the recursive listing of files in directories, with options to include full paths, target specific directories, and filter for files only, which can then be sorted by name. The commands allow for flexible and powerful batch processing of file data in a user's environment.

### maths
The collection of custom functions for Nushell includes a variety of mathematical operations. These functions allow users to perform root calculations with customizable denominators and scalars, compute cube roots, factorials, and check for prime numbers, as well as generate lists of primes up to a specified limit. Users can calculate roots of quadratic equations, create multiplication tables up to a given number, determine if a year is a leap year, and find the greatest common divisor (GCD) and least common multiple (LCM) of two integers. Conversion between decimal and custom base representations is supported, and functions for scaling numerical lists or table columns to a specified interval are included. Additional functions cover calculating the exponential function, selecting random integers or elements from a list, computing binomial coefficients, permutations, the Fibonacci sequence, and statistical measures such as skewness and kurtosis of numerical data.

### media
These nushell custom functions provide a comprehensive suite of media manipulation tools that require dependencies such as `ffmpeg`, `sox`, `subsync`, and `mpv`. These functions allow users to perform a variety of actions on media files, including but not limited to: obtaining media information, translating and syncing subtitles, removing audio noise from both audio and video files, screen recording, stripping audio from video, cutting and splitting video and audio files, extracting audio, merging videos, compressing videos, and **automatically detecting and removing logos**. Additional features include searching media databases, handling downloaded YouTube content, and notifying an Android device via Join upon task completion. The functions are designed to handle different file types and provide options for output formats, encoding settings, and language support for subtitles.

### net
This script invokes `nethogs` to monitor network traffic, processes the output, and formats it before saving it to a file. Specifically, the script captures the first five entries of network traffic data, cleans up process names, pads the upload and download rates for alignment, and then consolidates the data into a formatted string with the process name followed by the upload and download rates, separated by colons. The formatted data is joined by newlines and saved to a designated file in the user's home directory, appending a newline character each time the script runs. This script is used in the `.conkyrc` file.

### network
These custom functions serve a variety of network-related purposes. They enable users to switch to a stronger known Wi-Fi network, display detailed Wi-Fi connection information with visual enhancements for the active connection, list used network sockets by process, and fetch internal and external IP addresses with optional device specification. Other functions include identifying devices connected to the network using `nmap`, retrieving saved Wi-Fi passwords from system configurations, and displaying stored IP addresses in a table format. These utilities facilitate network management and information retrieval, enhancing user experience on systems that support NuShell scripts.

### plots
These custom functions are designed to visualize various types of data through different plotting methods. The `png-plot` function uses the `ping` command to check network latency to a specified IP address and plots the results in real-time. The `speedtest-plot` function measures and plots both download and upload internet speeds. The `gnu-plot` function generates plots from one or two-column data tables using `gnuplot`, with options to set titles and label axes, while the `plot-table` function creates plots from table data using a plugin, with customization options for the type of plot, title, and width. Each function enhances the visualization of data in the terminal, allowing users to understand and analyze data more effectively through graphical representations.

### pre_execution_hook
These custom functions are designed to automate system tasks related to file management and network information updating. Initially, the script checks for the existence of a data file and copies it from a backup location if it's not found. It then determines whether a certain time interval has passed to decide if it should update a list of mounted drives and directories. If an update is due, it executes another script and updates a JSON file with the current date and time. Additionally, if the update condition is met, the script retrieves and updates the device's IP address information, echoing a message in green, storing the hostname, and updating an IPs JSON file with the latest network information obtained from yet another script. The process involves reading, modifying, and saving JSON files and executing external Nu scripts.

### progressbar
These custom functions provide various utilities for displaying progress indicators and managing cursor visibility in a terminal. They include functions to generate text-based progress bars with customizable symbols, colors, and percentage displays; a more detailed progress bar with incremental blocks that fill up over time; a loading function that updates the percentage complete; and functions to hide and show the terminal cursor. Additionally, there is a utility for formatting floating-point numbers with specified precision and padding. These functions enhance the user experience in command-line interfaces by providing visual feedback on the progress of operations and improving the readability of numerical output.

### string_manipulation
These nushell custom functions facilitate string manipulation, text processing, date and time conversion, and visual output enhancement. They offer ways to prepend or append strings, repeat strings a specified number of times, and remove accents from characters. Additionally, they can convert time in the format `hh:mm:ss` to a duration and vice versa. One function extracts the first HTTP link from text and opens it, while another formats dates in a custom pattern and can be used for renaming files with date information. Lastly, there is a progress bar generator that displays a progress bar on the terminal with customizable symbols, colors, and background, adjusting dynamically to the terminal size and task progress. These functions are versatile tools designed to streamline various tasks in shell scripting with nushell.

### system
These nushell custom functions offer a variety of utilities for system information and environment management. They include functions to display a colorful banner with system details, fetch system information similar to `neofetch`, handle prompts, provide help for commands, access command history with syntax highlighting, search and manage processes, manipulate paths and directories, get aliases and source code for custom commands, control network applications, arrange multiple displays, unmount drives, fix Docker permissions, and handle errors. These functions are designed to enhance user interaction with the shell, streamline system monitoring, and facilitate easy navigation and control of the operating environment.

### table_manipulation
These functions for nushell facilitate various data manipulation tasks: converting ranges to lists, cleaning up ANSI escape codes from tables, adding hidden index columns to tables, filtering for unique rows by a specified column, summing file sizes from `ls` output, transforming tables into records, calculating set differences, finding index positions of search terms, extracting and transforming table columns into tables or lists, merging and deduplicating lists, retrieving specific rows from a table based on indexes, interactively selecting columns from a table, and setting default values across entire tables. These utilities enhance nushell's capabilities by streamlining common operations on tables, lists, and text, making data processing more efficient.

### tasker
These functions provide a suite of tools for interacting with devices using the Join app, offering a variety of methods for remote communication and control. The functions allow users to send notifications, initiate phone calls, utilize text-to-speech (TTS), and send SMS messages from a specified device, with the option to select a device interactively. These functions interact with the Join API, requiring an API key and device ID, and they support encoding text and title information for network transmission. Parameters can be set for specifying devices, choosing a language for TTS, and customizing other aspects of the communication. Additionally, the help function provides an overview of the available methods and their usage.

### transmission
These custom functions serve as a wrapper for managing Transmission, a BitTorrent client, through the command line. These functions allow users to control and interact with the Transmission daemon and include capabilities such as starting and stopping the daemon, reloading its configuration, and listing currently managed torrents. Users can also retrieve basic or full statistics for the torrents, open a text-based user interface for Transmission, and add torrents to the download queue either individually or in bulk from a file. Additionally, the functions support fetching information about specific torrents, removing torrents from the queue with or without deleting associated files, removing completed torrents, and initiating or halting the download of torrents either individually or collectively. These utilities provide a convenient and scriptable way to handle torrent activities directly from the shell environment.

### update_apps
These nushell custom functions collectively handle software updates and installations for various applications, both on and off the package manager as well as custom functions to fetch the latest release information from GitHub repositories, and to update GitHub app releases. Other functions deal with updating utilities and tools like nchat, ffmpeg with CUDA support, whisper, manim, yewtube, yt-dlp, and Joplin, as well as registering nushell plugins, upgrading the system, upgrading pip3 packages, updating the nushell config, installing fonts, and handling errors during installations. Each function encapsulates the necessary steps to check for updates, download new versions, and install them, often with error handling to notify the user if something goes wrong.

### update_right_prompt
This script sets up an environment variable named `MY_ENV_VARS`. Within this, it defines or updates the `l_prompt` field. The `l_prompt` field is toggled between "short" and "long" based on its current state. If it does not exist or is empty, or if it is currently set to "short", it will be set to "long". If it is already set to "long", it will be changed back to "short". This script ensures that `l_prompt` alternates between these two states, presumably to adjust the prompt length in the user's shell environment.

### weather_tomorrow
These functions collectively form a comprehensive weather reporting tool. The functions allow users to retrieve weather forecasts and current conditions based on their IP address or specified location. The tool uses APIs like tomorrow.io for weather data and deprecated airvisual for air pollution, alongside Google Maps API for street addresses. The script supports various functionalities such as fetching weather at intervals for the command prompt, providing detailed descriptions of wind and UV conditions, and displaying air quality levels. There is also a plotting feature for visualizing weather data if the system supports it. Version 2.0 of the weather script features the ability to customize the home location, check network status before fetching data, and gracefully handle errors or lack of data. Users can also explore detailed weather conditions and forecasts, such as temperature, humidity, sunrise and sunset times, and wind speeds, as well as see a text representation of current weather conditions with an icon.

### yandex
These nushell custom functions serve as wrappers for the Yandex Disk CLI app, offering simplified commands to manage and interact with Yandex Disk. These commands include checking the status of the synchronization and space usage, starting and stopping the synchronization process, accessing the help menu, and listing the last synchronized items. The status function filters the output to show sync-related information and space usage, the start and stop functions control the sync process, the help function displays the help options, and the last function presents the most recent files that were synchronized.

### yt_api
These custom functions provide a suite of tools for interacting with the YouTube API and managing YouTube music playlists. They enable users to configure credentials, create and refresh API tokens, and handle token expiration. The functions include methods for playing YouTube music from a local database or directly from YouTube, downloading music playlists to a local database, updating playlists with new likes, and removing duplicates or all songs from a playlist. Additional commands allow for verifying token validity, getting and refreshing tokens, and testing API interactions. Helper commands such as `yt-api help` provide more information on usage, and related commands like `ytm` are also mentioned. The functions are designed to work with YouTube playlists, allowing fetching of playlist items, updating playlists, and managing songs with various filters and options.

### zoxide
These custom functions offer enhanced directory navigation capabilities. They allow users to quickly jump to directories using keywords or an interactive search interface. The first function defines a command that accepts one or more keywords to identify and change to a target directory, handling cases where the path needs expansion or querying a database. The second function presents an interactive search method, where users can select from a list of directories that match the input criteria. Both functions integrate with `zoxide`, a smarter `cd` command, and use fuzzy matching to improve the user experience. Additionally, there's a completion function designed to suggest directory paths based on the user's input, further aiding navigation by providing real-time, context-aware options. Taken from the official zoxide repository.

## Available Commands

| Command | Description |
| --- | --- |
| `?` | short help |
| `activate` | No description provided. |
| `adbtasker` | adbtasker |
| `ago` | Calculates a past datetime by subtracting a duration from the current time. |
| `aimsc` | No description provided. |
| `aimsy` | No description provided. |
| `ansi-strip-table` | ansi strip table |
| `apagar` | No description provided. |
| `apps-update` | update off-package manager apps |
| `askai` | No description provided. |
| `askaimage` | No description provided. |
| `askpdf` | No description provided. |
| `autolister` | create media database for downloads and all mounted disks |
| `autouse-file` | generate autouse file |
| `bar` | Print a multi-sectional bar  Examples: `$ ui bar {foo: 0.5, bar: 0.5}` `$ ui bar {foo: {fraction: 0.4, color: lur}, bar: {fraction: 0.6, color: cr}}` `$ ui bar --width 10 {foo: 0.5, bar: 0.5}` `$ ui bar --normalize {foo: 0.1, bar: 0.1}` `$ ui bar {progress%: 0.4}` |
| `bard` | alias for bard |
| `base2dec` | Custom base representation number to decimal |
| `bat` | No description provided. |
| `batstat` | battery stats |
| `bitly` | No description provided. |
| `btop` | No description provided. |
| `budget` | budget |
| `cal` | No description provided. |
| `cava` | No description provided. |
| `cblue` | list bluetooth devices and connect |
| `chat_gpt` | No description provided. |
| `check-link` | check validity of a link |
| `check-ups` | UPS Status Check Command Returns a structured table with comprehensive UPS metrics |
| `claude_ai` | No description provided. |
| `clean-analytics` | delete empty google analytics csv files |
| `clone-ubuntu-install` | clone ubuntu backup repo as main local repo |
| `clone-yandex-disk` | clone yandex.disk repo as main local repo |
| `colorpicker` | No description provided. |
| `column` | select column of a table (to table) |
| `column2` | get column of a table (to list) |
| `const-table` | generates table with an unique constant value |
| `copy` | copy text to clipboard |
| `copy-scripts-and-commit` | copy private nushell script dir to public repo and commit |
| `copy-yandex-and-commit` | update yandex.disk repository |
| `coretemp` | cores temp |
| `countdown` | countdown alarm |
| `country-flag` | Return the flag emoji for a given two-digit country code |
| `cp-pipe` | cp trough pipe to same dir  Example ls *.txt \| first 5 \| cp-pipe ~/temp |
| `cputemp` | No description provided. |
| `cpwd` | copy pwd |
| `create-virtualenv` | create virtual env |
| `dailys` | No description provided. |
| `dall_e` | No description provided. |
| `debunk-table` | debug data given in table form |
| `dec2base` | Decimal number to custom base representation |
| `deep_l` | No description provided. |
| `default-table` | default a whole table |
| `echo-c` | custom color echo |
| `echo-g` | green echo |
| `echo-r` | red echo |
| `echo-y` | yellow echo |
| `exchange_rates` | No description provided. |
| `export-nushell-docs` | export nushell.github documentation |
| `filter-command` | No description provided. |
| `find` | No description provided. |
| `find-file` | find file in dir recursively |
| `find-index` | find index of a search term |
| `finished` | No description provided. |
| `fix-docker` | fix docker run error |
| `fix-green-dirs` | fix green dirs |
| `fuzzy-dispatcher` | No description provided. |
| `fuzzy-select-fs` | select files and dirs |
| `g` | alias for ai gcal with gemini |
| `generate-md-from-dir` | generate an unique md from all files in current directory recursively |
| `generate-nushell-doc` | generates nushell document for llm (gemini and claude) |
| `get-aliases` | get aliases |
| `get-api-key` | Standardized API key retrieval with robust error handling  Usage: get-api-key google.gemini_paid |
| `get-deepl-lang-code` | Helper function to get DeepL language code from common language names |
| `get-devices` | get devices connected to network  It needs nmap2json, installable (ubuntu at least) via: `sudo gem install nmap2json`  |
| `get-dirs` | get list of directories in current path |
| `get-files` | get list of files recursively |
| `get-git-metrics` | Extract git metrics using porcelain v2 |
| `get-github-latest` | get latest release info in github repo |
| `get-input` | get $in input if necessary |
| `get-ips` | get ips |
| `get-keybindings` | keybindings |
| `get-mac` | No description provided. |
| `get-monitors` | get monitors |
| `get-phone-number` | get phone number from google contacts |
| `get-rows` | select rows in a table from list of ints |
| `get-used-keybindings` | current used keybindinds |
| `get-wg` | No description provided. |
| `gg-contacts` | No description provided. |
| `gg-trans` | No description provided. |
| `github-app-update` | update github app release if file doesnt have an extension, use the pattern flag |
| `gnu-plot` | plot data table using gnuplot  Example: If $x is a table with 2 columns $x \| gnu-plot ($x \| column 0) \| gnu-plot ($x \| column 1) \| gnu-plot ($x \| column 0) \| gnu-plot --title "My Title" gnu-plot $x --title "My Title" |
| `google_ai` | No description provided. |
| `google_aimage` | No description provided. |
| `google_search` | No description provided. |
| `grep-nu` | grep for nu  Examples; grep-nu search file.txt ls **/* \| some_filter \| grep-nu search open file.txt \| grep-nu search |
| `group-list` | group list Example: [1 1 2 2 3 4] \| group list {$in mod 2 == 0} |
| `grp` | No description provided. |
| `gtes` | No description provided. |
| `h` | alias for ai habitica with gemini |
| `his` | last 100 elements in history with highlight |
| `history-stats` | Show some history stats similar to how atuin does it |
| `hs` | aliases |
| `htop` | No description provided. |
| `indexify` | add a hidden column with the content of the # column |
| `install-font` | install font |
| `intersect` | intersection between two lists |
| `is-column` | verify if a column exist within a table |
| `is-in` | checks to see if the elements in the first list are contained in the second list analog to polars is-in  Example:  let a = [[a]; [a] [b] [c] [d]] let b = [[a]; [a] [c]] $a \| is-in $b |
| `is-mounted` | check if drive is mounted |
| `iselect` | interactively select columns from a table |
| `isleap` | Check if year is leap |
| `jd` | jdownloader downloads info |
| `jdown` | jdown.py wrapper |
| `join-text-files` | concatenate all files in current directory  asummes all are text files |
| `killn` | kill specified process  Receives a name or a list of processes |
| `killnode` | kill mcp node servers running |
| `l` | ls sorted by name |
| `label-encode` | No description provided. |
| `last-command` | get last command |
| `lc` | No description provided. |
| `le` | ls sorted by extension |
| `left_prompt` | helper for displaying left prompt |
| `lg` | ls in text grid |
| `list-diff` | difference between 2 lists of numbers Example: let a = [1 2 3]  list-sum $a $a |
| `list-sum` | sum lists of numbers Example: let a = [1 2 3]  list-sum $a $a list-sum $a $a $a |
| `listen-ports` | listen ports |
| `lister` | list all files and save it to json in Dropbox/Directorios |
| `lists2table` | list of lists into table |
| `lo` | ls only name |
| `ls-ports` | list used network sockets |
| `lt` | ls by date (newer last) |
| `matlab-cli` | run matlab in cli |
| `max-vol` | No description provided. |
| `mcv` | No description provided. |
| `mcx` | open mcomix |
| `mk-anime` | create anime dirs according to files |
| `mk-manga` | create manga dirs according to files |
| `monitor` | Monitor the output of a command |
| `mpv` | mpv wrapper |
| `multiwhere` | filter by multiple where conditions simultaneous Example:  ls \| multiwhere { name: .txt, type: file } |
| `mute` | No description provided. |
| `mv-pipe` | mv trough pipe to same dir  Example ls *.txt \| first 5 \| mv-pipe ~/temp |
| `my-pandoc` | pandoc md compiler |
| `my-pdflatex` | my pdflatex |
| `nala-fetch` | No description provided. |
| `ncdu` | No description provided. |
| `nerd-fonts-clean` | clean nerd-fonts repo |
| `netspeed` | netspeed graph |
| `network-switcher` | network switcher |
| `newer-than` | Check if date is closer to the present than specified duration |
| `node-info` | No description provided. |
| `nu-clean` | No description provided. |
| `nu-crypt` | crypt |
| `nu-sloc` | nushell source files info |
| `nufetch` | neofetch but nu |
| `nullify-record` | make null all values of a record, recursively |
| `nushell-syntax-2-sublime` | No description provided. |
| `nutts` | No description provided. |
| `nuwget` | Download file with nu |
| `nvitop` | No description provided. |
| `o_llama` | No description provided. |
| `ochat` | alias for ollama chat |
| `older-than` | Check if date is further in the past than specified duration |
| `ollama_search` | ollama web search |
| `one-hot-encode` | No description provided. |
| `op` | open text file |
| `open-analytics` | open google analytics csv file |
| `open-config` | No description provided. |
| `open-credential` | open credentials |
| `open-link` | extract first link from text |
| `openl` | open last file |
| `openm` | accumulate a list of files into the same table  Example ls *.json \| openm let list = ls *.json; openm $list |
| `parse-git-status-v2` | Git metrics helper for prompt Parse git status --porcelain=v2 --branch output |
| `paste` | paste text from clipboard |
| `patch-font` | patch font with nerd font |
| `pchat` | private-gpt chat |
| `pip3-upgrade` | upgrade pip3 packages |
| `pivot-table` | simple pivoting of a table without aggregation It's a process of summarizing data from a table into a new table by grouping values from one or more columns into new columns and then applying an aggregation function to the values in other columns.  For instance:  table_1: YEAR,ITEM,VALUE 2000,case1,10 2000,case2,20 2000,case3,20 2001,case1,20 2001,case2,10 2001,case3,50 2003,case2,30 2003,case1,50 2004,case3,10 2004,case2,39  converts to table_2: ITEM,2000,2001,2003,2004 case1,10,20,50, case2,20,10,30,39 case3,20,50,,10  via:  $table_1 \| pivot-table --columns [YEAR] --index [ITEM] --values [VALUE] |
| `pl` | No description provided. |
| `plot-table` | plot data table using plot plugin  Example: |
| `png` | No description provided. |
| `png-plot` | ping with plot |
| `print-file` | send to printer |
| `print-list` | No description provided. |
| `private_gpt` | No description provided. |
| `progress_bar` | progress bar  Example 1: def test [] { let max = 200 mut progress_bar = progress_bar 0 $max for i in 1..($max) { $progress_bar = (progress_bar $i $max $progress_bar) sleep 0.01sec } }  Example 2 : def test [] { let max = 200 mut progress_bar = "" for i in 0..($max) { $progress_bar = (progress_bar $i $max $progress_bar) sleep 0.01sec } } |
| `psn` | search for specific process |
| `pwd-short` | short pwd |
| `qrenc` | qr code generator |
| `quantum` | alias for short call |
| `quick-ubuntu-and-tools-update-module` | copy private linux backup dir to private repo and commit (alias quantum) |
| `R` | No description provided. |
| `ram` | ram info |
| `rand-select` | random selection from a list or table |
| `randi` | random int |
| `range2list` | range to list |
| `re-enamerate` | rename all files starting with certain prefix, enumerating them |
| `reiniciar` | No description provided. |
| `remove-code-blocks` | No description provided. |
| `rename` | No description provided. |
| `rename-all` | manually rename files in a directory |
| `rename-date` | date renaming |
| `rename-file` | rename file via pattern replace |
| `replicate-tree` | replicate directory structure to a new location |
| `reset-alpine-auth` | reset alpine authentification |
| `return-error` | ##################################################### here because they are needed in this file ##################################################### generate error output |
| `rm-empty-dirs` | delete empty dirs recursively |
| `rm-pipe` | rm trough pipe  Example ls *.txt \| first 5 \| rm-pipe |
| `rml` | rm last |
| `rmount` | mount fuse drive via rclone  possible drives: - box - gdrive - onedrive - yandex - mega |
| `run-private-gpt` | No description provided. |
| `s` | No description provided. |
| `save-credential` | save credentials |
| `scale-minmax` | Scale list to [a,b] interval |
| `scale-minmax-table` | Scale every column of a table (separately) to [a,b] interval |
| `scompact` | compact with empty strings and nulls |
| `select-pattern` | select columns by pattern |
| `set-screen` | second screen positioning |
| `setdiff` | calculates elements that are in list a but not in list b |
| `show_banner` | nushell banner |
| `show-ips` | show stored ips |
| `show-prompts` | show system prompts and pre-prompts definitions |
| `speedtest-plot` | plot download-upload speed |
| `ssh-sin-pass` | enable ssh without password |
| `stable_diffusion` | No description provided. |
| `stop-net-apps` | stop network applications |
| `subtitle-renamer` | Renames subtitles files according to tv shows names found in a directory Accepted syntaxes for season/episode are: 304, s3e04, s03e04, 3x04 (case insensitive) |
| `sum-size` | get total sizes of ls output |
| `supgrade` | update-upgrade system |
| `svg2pdf` | convert svg image into a pdf file |
| `system-cleanup` | Unified system cleanup command to reclaim disk space.  Categories: 1. User Caches: thumbnails, fontconfig, wallust, pip, uv, npm, stack. 2. Package Managers: apt (clean/autoremove), uv, pip, npm, stack. 3. System Logs: journalctl vacuum (last 3 days). 4. Aggressive: rustup toolchains (stable only), old build dirs (node_modules, target > 30d).  Note: Privileged commands (apt, journalctl) require sudo and will only be executed if --sudo is provided. |
| `table-diff` | table diff |
| `table2record` | table to record |
| `takephoto` | No description provided. |
| `termshot` | No description provided. |
| `timg` | wrapper for timg |
| `todos` | No description provided. |
| `tokei` | tokei wrapper |
| `token2word` | No description provided. |
| `trans` | No description provided. |
| `tree` | No description provided. |
| `tts` | No description provided. |
| `typeof` | ##################################################### ##################################################### wrapper for describe |
| `um` | umount fuse drive  possible drives: - box - gdrive - onedrive - yandex - photos |
| `umall` | umount all drives |
| `union` | join 2 lists |
| `uniq-by` | returns a filtered table that has distinct values in the specified column |
| `unmute` | No description provided. |
| `update-all-likes` | update all_likes m3u playlist via gemini |
| `update-nu-config` | update nu config (after nushell update) |
| `upload-debs-to-gdrive` | upload deb files to gdrive |
| `upload-debs-to-mega` | upload deb files to mega |
| `upload-zed-backup-to-mega` | upload zed backup to mega |
| `usage` | get the examples from tldr as a table |
| `ver` | get the version information formatting the plugins |
| `verify` | Performs logical operations on multiple predicates. User has to specify exactly one of the following flags: `--all`, `--any` or `--one-of`. |
| `view-code` | get code of custom command |
| `web_search` | wrapper for web search |
| `wget-all` | get files all at once from webpage using wget |
| `wifi-info` | wifi info |
| `wifi-pass` | get wifi pass |
| `wsp` | No description provided. |
| `xls2csv` | xls/ods 2 csv |
| `ydx` | yandex-disk wrappers |
| `yt-api` | youtube api implementation to get playlists and songs info |
| `yt-get-access-token` | Main function to get a valid access token, handling refresh automatically |
| `ytcli` | yewtube |
| `ytm` | play youtube music with playlist items pulled from local database  First run `yt-api download-music-playlists` |
| `ytm2` | wrapper for cliamp |
| `zed-backup` | No description provided. |
| `zed-restore` | No description provided. |

# Disclaimer
- Some of these have been taken from the `#cool-scripts` Discord channel of Nushell ;)
