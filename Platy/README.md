# Platy

Platy is a terminal console for talking to AI models that run entirely on your own machine, through Ollama. There's no cloud dependency and nothing leaves your computer unless you turn on the optional Claude API fallback for harder questions.

## What you need

- macOS, Apple Silicon or Intel
- Python 3.9+ (standard library only — nothing to `pip install`)
- [Ollama](https://ollama.com), which does the actual model serving

## Getting it running

Install Ollama from ollama.com. On Linux you can skip the installer and just run:

```sh
curl -fsSL https://ollama.com/install.sh | sh
```

Then pull a model. `qwen2.5:14b` is a good default if your Mac can handle it:

```sh
ollama pull qwen2.5:14b
```

or, if you're tighter on RAM:

```sh
ollama pull phi3
```

Nothing stops you from pulling several and flipping between them later with `/model`.

Now grab Platy itself:

```sh
mkdir -p ~/bin
cp ./platy ~/bin/platy
chmod +x ~/bin/platy
```

and make sure `~/bin` is actually on your `PATH` — add this to `~/.zshrc` if it's missing:

```sh
export PATH="$HOME/bin:$PATH"
source ~/.zshrc
```

## Optional extras

None of this is required — Platy works fine offline with just Ollama. Set whichever of these you want in `~/.zshrc` or a secrets file it sources.

Claude API access, for when a task needs more horsepower than a local model can give:

```sh
export ANTHROPIC_API_KEY="sk-ant-..."
```

Serper for web search (DuckDuckGo is the default if you skip this):

```sh
export SERPER_API_KEY="..."
```

And if you want a `/docs` command that searches a specific product's documentation instead of the general web, point it at that product:

```sh
export PLATY_DOCS_NAME="Jamf Pro"
export PLATY_DOCS_SITES="site:developer.jamf.com OR site:docs.jamf.com"
export PLATY_DOCS_KEYWORDS="jamf,jss,jamf pro"
```

Swap in whatever product and domains you actually need — the keyword list is just what triggers Platy to route a question to `/docs` automatically instead of a plain web search.

## Using it

```sh
platy
```

drops you into the TUI. If you just want a quick answer without the full interface:

```sh
platy what is the syntax for a Swift async function
```

Dragging a file or folder from Finder into the terminal window also works — Platy will read it in.

A few commands worth knowing: `/model` switches models, `/auto` lets Platy pick one for you, `/think` toggles deeper reasoning, and `/pin` / `/learn` / `/forget` / `/memory` manage facts that persist across sessions. `/read` and `/watch` load or track a file, `/run` executes the last script Platy generated, and `/sessions` / `/export` / `/clear` manage the conversation itself. `/help` lists everything.

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

## Keeping Ollama in shape

`ollama list` shows what you've got installed, `ollama pull llama3.1:8b` grabs something new, and `ollama rm qwen2.5:14b` gets rid of a model you don't need anymore. The Ollama macOS app starts the server automatically, but if Platy can't reach it, run `ollama serve` yourself and check again. Updating Ollama is just re-running the installer — same one-liner as above on Linux, or a fresh download on macOS.

## Where things get stored

Conversations land in `~/platy_sessions/`, pinned and learned facts live in `~/.platy_memory.json`, and your input history is in `~/.platy_history`.

## Script validation

If you drop the `shellcheck` binary at `~/bin/shellcheck`, Platy will run it against any Bash script it generates before handing it back to you. Get it from shellcheck.net.
