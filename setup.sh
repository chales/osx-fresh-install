#!/bin/sh

# Forked from https://github.com/thoughtbot/laptop
# Last update 01/14/2016

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

# shellcheck disable=SC2016
append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

case "$SHELL" in
  */zsh) : ;;
  *)
    fancy_echo "Changing your shell to zsh ..."
      chsh -s "$(which zsh)"
    ;;
esac

brew_install_or_upgrade() {
  if brew_is_installed "$1"; then
    if brew_is_upgradable "$1"; then
      brew upgrade "$@"
    fi
  else
    brew install "$@"
  fi
}

cask_install() {
    fancy_echo "Installing $1 ..."
    brew cask install "$@"
}

brew_is_installed() {
  local name
  name="$(brew_expand_alias "$1")"

  brew list -1 | grep -Fqx "$name"
}

brew_is_upgradable() {
  local name
  name="$(brew_expand_alias "$1")"

  ! brew outdated --quiet "$name" >/dev/null
}

brew_tap() {
  brew tap "$1" --repair 2> /dev/null
}

brew_expand_alias() {
  brew info "$1" 2>/dev/null | head -1 | awk '{gsub(/.*\//, ""); gsub(/:/, ""); print $1}'
}

brew_launchctl_restart() {
  local name
  name="$(brew_expand_alias "$1")"
  local domain="homebrew.mxcl.$name"
  local plist="$domain.plist"

  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sfv "/usr/local/opt/$name/$plist" "$HOME/Library/LaunchAgents"

  if launchctl list | grep -Fq "$domain"; then
    launchctl unload "$HOME/Library/LaunchAgents/$plist" >/dev/null
  fi
  launchctl load "$HOME/Library/LaunchAgents/$plist" >/dev/null
}

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
    rbenv rehash
  fi
}

if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    append_to_zshrc '# recommended by brew doctor'

    # shellcheck disable=SC2016
    append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

    export PATH="/usr/local/bin:$PATH"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

fancy_echo "Updating Homebrew formulae ..."
brew_tap 'thoughtbot/formulae'
brew update

fancy_echo "Updating Unix tools ..."
brew_install_or_upgrade 'ctags'
brew_install_or_upgrade 'git'
brew_install_or_upgrade 'openssl'
brew unlink openssl && brew link openssl --force
# brew_install_or_upgrade 'rcm'
# brew_install_or_upgrade 'reattach-to-user-namespace'
# brew_install_or_upgrade 'the_silver_searcher'
brew_install_or_upgrade 'tmux'
brew_install_or_upgrade 'vim'
brew_install_or_upgrade 'zsh'
brew_install_or_upgrade 'tree'
brew_install_or_upgrade 'wget'
brew install macvim --with-override-system-vim
brew linkapps macvim

# fancy_echo "Updating Heroku tools ..."
# brew_install_or_upgrade 'heroku-toolbelt'
# brew_install_or_upgrade 'parity'

# fancy_echo "Updating GitHub tools ..."
# brew_install_or_upgrade 'hub'

fancy_echo "Updating image tools ..."
brew_install_or_upgrade 'imagemagick'

# fancy_echo "Updating testing tools ..."
# brew_install_or_upgrade 'qt'

fancy_echo "Updating programming languages ..."
brew_install_or_upgrade 'libyaml' # should come after openssl
brew_install_or_upgrade 'node'
brew_install_or_upgrade 'rbenv'
brew_install_or_upgrade 'ruby-build'

# fancy_echo "Updating databases ..."
# brew_install_or_upgrade 'postgres'
# brew_install_or_upgrade 'redis'
# brew_launchctl_restart 'postgresql'
# brew_launchctl_restart 'redis'

fancy_echo "Configuring Ruby ..."
find_latest_ruby() {
  rbenv install -l | grep -v - | tail -1 | sed -e 's/^ *//'
}

ruby_version="$(find_latest_ruby)"
# shellcheck disable=SC2016
append_to_zshrc 'eval "$(rbenv init - --no-rehash)"' 1
eval "$(rbenv init -)"

if ! rbenv versions | grep -Fq "$ruby_version"; then
  rbenv install -s "$ruby_version"
fi

rbenv global "$ruby_version"
rbenv shell "$ruby_version"
gem update --system
gem_install_or_update 'bundler'
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

if [ -f "$HOME/.laptop.local" ]; then
  fancy_echo "Running your customizations from ~/.laptop.local ..."
  # shellcheck disable=SC1090
  . "$HOME/.laptop.local"
fi

fancy_echo "Setting up ~/.zsh ..."
append_to_zshrc 'export EDITOR=vim'
cp ./aliases "$HOME/.aliases"
append_to_zshrc 'source ~/.aliases'

fancy_echo "Cleaning up old Homebrew formulae ..."
brew cleanup
brew cask cleanup

fancy_echo "Installing native apps .."
brew install caskroom/cask/brew-cask

cask_install "dropbox"
cask_install "slack"
cask_install "google-chrome"
cask_install "transmit"
cask_install "codekit"
cask_install "dash"
cask_install "sequel-pro"
cask_install "docker-compose"
cask_install "webstorm"
cask_install "phpstorm"
cask_install "skype"
cask_install "1password"
cask_install "arq"
cask_install "google-photos-backup"
cask_install "licecap"
cask_install "cinch"
cask_install "iterm2"


fancy_echo "Installing Composer ..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

fancy_echo "Installing Grunt and gulp CLI ..."
npm install grunt-cli -g
npm install gulp -g

fancy_echo "Installing Ruby Sass ..."
gem_install_or_update "sass"