# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# set PATH so it includes user's private bin directories
PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Repopulate the encrypted configuration file for tripwire
alias twcfg='twadmin -m F -c /usr/local/.audit/tripwire/tw.cfg -S /usr/local/.audit/tripwire/site.key /usr/local/.audit/tripwire/twcfg.txt'

# Repopulate the tripwire policy
alias twpol='twadmin -m P -c /usr/local/.audit/tripwire/tw.cfg -p /usr/local/.audit/tripwire/tw.pol -S /usr/local/.audit/tripwire/site.key /usr/local/.audit/tripwire/twpol.txt'

# Aliases for vm connections
alias sol11='ssh jas@127.0.0.1 -p 2222'
alias sol10='ssh jas@127.0.0.1 -p 2223'
alias ubuntu='ssh jas@127.0.0.1 -p 2224'
alias cent5='ssh jas@127.0.0.1 -p 2225'
alias cent6='ssh jas@127.0.0.1 -p 2226'
alias kali='ssh jas@127.0.0.1 -p 2227'

# Alias to handle clamscans
alias cscan='clamscan -rvi --exclude-dir="^/sys|/proc" / >/var/tmp/clamscan.log 2>&1'


# Function to handle VM headless starts
function startvm()
{
  # Capture arg
  local vm="${@}"

  # Start the VM requeste as a headless node
  VBoxManage startvm "${vm}" --type headless 2> /dev/null
}


# Function to handle git commits w/ GPG key signing
function commit() {
  git commit --gpg-sign=9ACC8A57 -am "${@}"
}

# Function to handle signing new tags w/ GPG key
function tag() {
  git tag -u 9ACC8A57 -a ${1} -m "v${1}"
}

# Function handle git pushes w/ GPG key signing
function push() {
  git push --tags origin "${1}"
}


# Default path of UFW parser
parse_ufw=~/projects/ufw-parser.awk

# Default path of UFW log
log_ufw=/var/log/ufw.log

# Function for filtering outbound comms
function ufw_out
{
  for host in $(awk -f ${parse_ufw} ${log_ufw} | awk '$4 == "OUT" && $7 !~ /^192|^127/{print $7}' | sort -u); do
    lookup=( $(host ${host} 2>/dev/null | tr ' ' '^') )
    [[ "${lookup[@]}" =~ NXDOMAIN ]] &&
      result=" - Lookup failed" ||
      result="$(echo "${lookup[@]}" | tr '^' ' ' | awk '{print $5}')"
    echo "${host} ${result}"
  done
}

# Function for filtering inbound comms
function ufw_in
{
  for host in $(awk -f ${parse_ufw} ${log_ufw} | awk '$4 == "IN" && $9 !~ /^192|^127/{print $9}' | sort -u); do
    lookup=( $(host ${host} 2>/dev/null | tr ' ' '^') )
    [[ "${lookup[@]}" =~ NXDOMAIN ]] &&
      result=" - Lookup failed" ||
      result="$(echo "${lookup[@]}" | tr '^' ' ' | awk '{print $5}')"
    echo "${host} ${result}"
  done
}
