#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function bakAndSymlink {
  TARGET=$2
  SOURCE=$1

  if [ -f $SOURCE ] ; then
    if [ -f $TARGET ] && [ ! -L $TARGET ] ; then
      mv $TARGET ${TARGET}_bak
      echo "$TARGET already exists. Backing up as ${TARGET}_bak..."
    fi
    if [ ! -f $TARGET ] ; then
      ln -s $DIR/$SOURCE $TARGET
      return 0
    fi
  fi

  if [ -d $SOURCE ] ; then
    if [ -d $TARGET ] && [ ! -L $TARGET ] ; then
      mv $TARGET ${TARGET}_bak
      echo "$TARGET already exists. Backing up as ${TARGET}_bak..."
    fi
    if [ ! -d $TARGET ] ; then
      ln -s $DIR/$SOURCE $TARGET
      return 0
    fi
  fi

  return 1
}

########################
##### ~/ dotfiles ######
########################

# zshrc
bakAndSymlink .zshrc ~/.zshrc

# antigen
if [ ! -d $DIR/antigen ] ; then
  mkdir -p $DIR/antigen
  curl https://cdn.rawgit.com/zsh-users/antigen/v1.2.0/bin/antigen.zsh > $DIR/antigen/antigen.zsh
fi

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh ] ; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

# .xprofile
bakAndSymlink .xprofile ~/.xprofile

# .fehbg
bakAndSymlink .fehbg ~/.fehbg

################################
##### ~/.config/ dotfiles ######
################################

# ~/.config
if [ ! -d ~/.config ] ; then
  mkdir ~/.config
fi

# nvim
bakAndSymlink nvim ~/.config/nvim
[ $? -eq 0 ] && nvim +PlugInstall +qa

# i3
bakAndSymlink i3 ~/.config/i3

# polybar
bakAndSymlink polybar ~/.config/polybar

# rofi
bakAndSymlink rofi ~/.config/rofi

# alacritty
bakAndSymlink alacritty.yml ~/.config/alacritty.yml
bakAndSymlink alacritty ~/.config/alacritty
