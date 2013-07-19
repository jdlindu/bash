# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='/usr/bin/vim'
alias asset='go 183.61.143.222 "php /home/linrunjin/bin/fetch_asset.php " '
alias list_pkg_ip='go 183.61.143.222 "php /home/linrunjin/bin/get_pkg_version_iplist.php "'
alias yyservice='cd /data/services/'
alias yyscp='scp -P32200'
