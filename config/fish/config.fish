# fish — interactive shell config.
#
# Every tool wired up below is optional: each block checks the binary exists
# first, so a machine missing eza or zoxide still gets a working shell rather
# than a screenful of "command not found" on every prompt.

if not status is-interactive
    exit
end

set -g fish_greeting

# --- prompt ---------------------------------------------------------------
if type -q starship
    starship init fish | source
end

# --- directory jumping ----------------------------------------------------
if type -q zoxide
    zoxide init fish | source
    alias cd 'z'
end

# --- fuzzy finding --------------------------------------------------------
# Ctrl+R history, Ctrl+T files, Alt+C directories.
if type -q fzf
    fzf --fish | source
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border=none --info=inline'
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
        set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
        set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --exclude .git'
    end
end

# --- better defaults ------------------------------------------------------
if type -q eza
    alias ls 'eza --group-directories-first --icons'
    alias ll 'eza -l --group-directories-first --icons --git'
    alias la 'eza -la --group-directories-first --icons --git'
    alias lt 'eza --tree --level=2 --icons'
end

if type -q bat
    alias cat 'bat --style=plain --paging=never'
    set -gx BAT_THEME 'base16'
    # Colourised man pages, using the same palette as everything else.
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

type -q rg; and alias grep 'rg'
type -q fd; and alias find 'fd'

# --- git ------------------------------------------------------------------
alias g 'git'
alias gs 'git status --short --branch'
alias gd 'git diff'
alias gl 'git log --oneline --graph --decorate -20'

# --- this repo ------------------------------------------------------------
# The two commands you will actually run while iterating on the desktop.
alias hs-check '~/HPI/projects/hypersetup2/install/check.sh'
alias hs-theme '~/HPI/projects/hypersetup2/install/install.sh --theme'
# Restart the shell without logging out. Saving a QML file hot-reloads, so this
# is only for changes QuickShell cannot pick up (new singletons, IPC handlers).
alias qs-restart 'qs kill; and sleep 0.5; and uwsm app -- qs -c hypersetup2 &; disown'

# --- environment ----------------------------------------------------------
fish_add_path -g ~/.local/bin
