#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function bakAndSymlink {
  TARGET=$2
  SOURCE=$1
  printf "\nMaybe symlink $SOURCE into $TARGET\n"

  ##### Source type: file
  if [ -f "$SOURCE" ] ; then
    # If target exists & it's not a symlink
    if [ -f "$TARGET" ] && [ ! -L "$TARGET" ] ; then
      mv "$TARGET" "${TARGET}_bak"
      echo "...$TARGET already exists. Backing up as ${TARGET}_bak"
    fi
    if [ ! -f "$TARGET" ] ; then
      TEST=$(dirname "$TARGET")
      if [ -d "$(dirname "$TARGET")" ] ; then
        echo "...symlinking $DIR/$SOURCE to $TARGET"
        ln -s "$DIR/$SOURCE" "$TARGET"
        return 0
      else
        echo "...parent directory does not exist"
      fi
    elif [ -L "$TARGET" ] ; then
      echo "...already symlinked"
    fi
  fi

  ##### Source type: directory
  if [ -d "$SOURCE" ] ; then
    # If target exists & it's not a symlink
    if [ -d "$TARGET" ] && [ ! -L "$TARGET" ] ; then
      mv "$TARGET" "${TARGET}_bak"
      echo "...$TARGET already exists. Backing up as ${TARGET}_bak"
    fi
    if [ ! -d "$TARGET" ] ; then
      if [ -d "$(dirname "$TARGET")" ] ; then
        echo "...symlinking $DIR/$SOURCE to $TARGET"
        ln -s "$DIR/$SOURCE" "$TARGET"
        return 0
      else
        echo "...parent directory does not exist"
      fi
    elif [ -L "$TARGET" ] ; then
      echo "...already symlinked"
    fi
  fi

  printf "...did not symlink $SOURCE\n\n"
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

# vimium (vivaldi)
bakAndSymlink vimium/000003.log "$HOME/.config/vivaldi/Default/Local Extension Settings/dbepggeogbaibhgnhhndojpepiihcmeb/000003.log"
find ~/.config/vivaldi -mindepth 1 -maxdepth 1 -regextype posix-extended -regex ".*Profile [0-9]+" -type d | while read -r FILE_PATH ; do
  IFS="/" SECTIONS=($FILE_PATH)
  bakAndSymlink vimium/000003.log "$HOME/.config/vivaldi/${SECTIONS[-1]}/Local Extension Settings/dbepggeogbaibhgnhhndojpepiihcmeb/000003.log"
done
