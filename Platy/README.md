```
██████  ██         ██     ████████  ██    ██         .--..-'''-''''-._
██  ██  ██        ████       ██     ██    ██     ___/%   ) )      \ i-;;,_
██████  ██      ████████     ██       ████      (:___/--/ /--------\ ) `'-'
██      ██      ██    ██     ██        ██            ""          ""
██      ██████  ██    ██     ██        ██
```

A local AI terminal console. Runs models on your machine via Ollama. No cloud required by default. Optional Claude API integration for tasks that need a more capable model.

---

## Requirements

- macOS (Apple Silicon or Intel)
- Python 3.9 or later — standard library only, no pip installs needed
- [Ollama](https://ollama.com) — the local model engine

---

## Install

### 1. Install Ollama

Download and install from [ollama.com](https://ollama.com).

On Linux:

```sh
curl -fsSL https://ollama.com/install.sh | sh
```

### 2. Pull a model

Platy works with any model Ollama supports. A solid starting point:

```sh
ollama pull qwen2.5:14b
```

Lighter option if you need less RAM:

```sh
ollama pull phi3
```

You can pull as many models as you want and switch between them inside Platy with `/model`.

### 3. Install Platy

```sh
mkdir -p ~/bin
curl -o ~/bin/platy https://raw.githubusercontent.com/alanramos/platy/main/platy
chmod +x ~/bin/platy
```

Make sure `~/bin` is on your PATH. Add this to `~/.zshrc` if it isn't already:

```sh
export PATH="$HOME/bin:$PATH"
```

Then reload your shell:

```sh
source ~/.zshrc
```

---

## Configure

Set these in `~/.zshrc` or a secrets file you source from it. None are required to run Platy — it works offline out of the box with just Ollama.

**Claude API** (optional — enables smarter fallback for hard tasks):

```sh
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Serper web search** (optional — DuckDuckGo is used by default):

```sh
export SERPER_API_KEY="..."
```

**Product documentation search** (optional — adds a `/docs` command that searches your configured product's docs):

```sh
export PLATY_DOCS_NAME="Jamf Pro"
export PLATY_DOCS_SITES="site:developer.jamf.com OR site:docs.jamf.com"
export PLATY_DOCS_KEYWORDS="jamf,jss,jamf pro"
```

Replace those values with any product and its documentation domains. The keywords control when Platy auto-routes questions to your docs instead of a general web search.

---

## Run

```sh
platy
```

One-shot mode — ask a question without entering the TUI:

```sh
platy what is the syntax for a Swift async function
```

---

## Commands

| Command | What it does |
|---|---|
| `/web <query>` | Search the web and send results to the AI |
| `/apple <query>` | Search Apple Developer documentation |
| `/docs <query>` | Search your configured product documentation |
| `/model` | Pick a model |
| `/auto` | Let Platy choose the model automatically |
| `/think` | Toggle deep reasoning mode |
| `/pin <fact>` | Save a fact permanently across sessions |
| `/learn <fact>` | Teach a correction or preference |
| `/forget <fact>` | Remove a pinned or learned fact |
| `/memory` | Browse and edit all saved facts |
| `/read <path>` | Load a file into the conversation |
| `/watch <path>` | Watch a file and auto-inject changes |
| `/run` | Execute the last generated script |
| `/sessions` | Session manager |
| `/export` | Export the current session as plain text |
| `/clear` | Clear the conversation |
| `/help` | Full command list |
| `/exit` | Quit |

Drag a file or folder from Finder into the terminal window — Platy reads it automatically.

---

## Maintaining Ollama

**See what models you have:**

```sh
ollama list
```

**Pull a new model:**

```sh
ollama pull llama3.1:8b
```

**Remove a model:**

```sh
ollama rm qwen2.5:14b
```

**Update Ollama:**

Re-download and run the installer from [ollama.com](https://ollama.com). On Linux:

```sh
curl -fsSL https://ollama.com/install.sh | sh
```

**Start the server manually** (macOS starts it automatically when you open the Ollama app):

```sh
ollama serve
```

If Platy can't connect to Ollama, make sure it's running before launching Platy.

---

## Where data lives

| Path | What's stored |
|---|---|
| `~/platy_sessions/` | Saved conversations |
| `~/.platy_memory.json` | Pinned and learned facts |
| `~/.platy_history` | Input history |

---

## Optional: script validation

Platy validates generated Bash scripts automatically if `shellcheck` is installed at `~/bin/shellcheck`. Download the binary from [shellcheck.net](https://www.shellcheck.net) and place it there.
