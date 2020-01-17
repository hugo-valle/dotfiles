#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

arg1="${1:-}"

#--  FUNCTION  ----------------------------------------------------------------
#          NAME:  DetectOS
#   DESCRIPTION:  Set variables detecting the OS type
#    PARAMETERS:  None
#       RETURNS:  None
#-------------------------------------------------------------------------------
#
DetectOS()
{
    # IDs help ---> https://github.com/zyga/os-release-zoo
    supported_distros="ubuntu, linuxmint, debian, elementary OS, neon, peppermint, Zorin OS"

    source /etc/os-release    #Load OS VARS
    # :TRICKY:03/01/2019 05:12:09 PM:hvalle: Overwrite OS system variable based on OSTYPE
    case "$OSTYPE" in
        solaris*)   OS="SOLARIS" ;;
        darwin*)    OS="OSX" ;;
        linux*)     OS="LINUX" ;;
        bsd*)       OS="BSD" ;;
        msys*)      OS="WINDOWS" ;;
        cygwin*)    OS="WINDOWS" ;;
        *)          echo "unknown: $OSTYPE" 
                    OS="unknown" ;;
    esac

    if [[ $OS == "unknown" ]]; then
        read -p "${BOLD}${RED}Unknown OSTYPE: $OS,${RESET} the script might not work. Do you want to procced <y/N>? " weird_os
            case "$weird_os" in
                y|Y ) : ;;
                n|N|* ) echo "$RESET" exit -1;;
            esac
    fi

    if [[  $OS == 'LINUX' ]]; then
        if [[  $supported_distros != *$ID* ]]; then
            echo "$BOLD${RED}ERROR:$RESET Undetect Linux: $ID $RESET"
            echo "Supported:$BOLD$BLUE $supported_distros $RESET"
            read -n 1 -p "Attempt to continue? $RESET (y/N): $GREEN" choice
            echo "$RESET"
            case "$choice" in
                y|Y ) :;;
                n|N|* ) echo "$RESET";exit -1;;
            esac
        else
            if [[  -z "$PRETTY_NAME" ]]; then
                echo "Linux Detected:$BOLD$GREEN $ID $RESET"
            else
                echo "Linux Detected:$BOLD$GREEN $PRETTY_NAME $RESET"
            fi
        fi

    elif [[  "$OS" == "OSX" ]]; then
        echo "OSX Detected $RESET"
        if which brew 2> /dev/null; then
            echo "$BOLD${YELLOW}Note!$RESET Missing Packages will installed using BREW"
            BREW=1;
        else
            BREW=0
            echo "$BOLD${YELLOW}Note:$RESET OSX:$BOLD$BLUE HomeBrew (https://brew.sh/)$RESET is required for auto install."
            echo "$BOLD${YELLOW}Note:$RESET Missing Packages will be listed."
        fi

    elif [[  "$OS" == "WINDOWS" ]]; then
        echo "Windows Detected $RESET"
        if which pact 2> /dev/null; then
            echo "$BOLD${YELLOW}Note!$RESET Missing Packages will installed using babun"
            PACT=1;
        else
            PACT=0
            echo "$BOLD${YELLOW}Note:$RESET WINDOWS:$BOLD$BLUE HomeBrew (https://babun.github.io/)$RESET is required for auto install."
            echo "$BOLD${YELLOW}Note:$RESET Missing Packages will be listed."
        fi
    fi

    # Set Package Manager
    if [[ $OS == 'LINUX' ]]; then
        APTCMD='sudo apt -o Dpkg::Progress-Fancy="1" -y install'
    elif [[ $OS == 'OSX' ]]; then
        APTCMD='brew install'
    elif [[ $OS == 'WINDOWS' ]]; then
        APTCMD='pact install'
    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  ScriptSettings
#   DESCRIPTION:  Setup the settings for this script
#    PARAMETERS:  None
#       RETURNS:  None
#-------------------------------------------------------------------------------
ScriptSettings()
{
    SCRIPTNAME="WSU Dr. V VIM IDE"

    #Directory Setup
    DOTFILES=$HOME/dotfiles
    LOCALBIN=~/.local/bin
    ENV_FILES=($HOME/.bash_profile 
                $HOME/.bash_login 
                $HOME/.profile 
                $HOME/.bashrc)

    #Optional
    OPTPKGS='zsh vim-gnome clang cppcheck libxml2-utils lua-check jsonlint pylint python3-pip python3-doc ctags cppman libbz2-dev'
    PIPPKGS='vim-vint proselint sphinx virtualenvwrapper numpy pandas'
    PKGS='git vim python3 curl bc build-essential cmake libboost-all-dev doxygen'

    # Note these two arrays must match by index number
    FILES=($DOTFILES/vim/vimrc 
            $DOTFILES/vim 
            $DOTFILES/tmux/tmux.conf 
            $DOTFILES/vim/vimrc 
            $DOTFILES/git/gitconfig)
    LINKS=( ~/.vimrc
            ~/.vim 
            ~/.tmux.conf
            ~/.vimrc
            ~/.gitconfig)

    #Global Vars (Auto Set - Changing will have BAD effects)
    ADMIN=0
    TMUX=0
    ZSH=0
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  PrintHelp
#   DESCRIPTION:  Help Function for script. Invoked with --help
#    PARAMETERS:  None
#       RETURNS:  None
#-------------------------------------------------------------------------------
PrintHelp()
{
    echo "${RESET}usage: $0 [--administrator] [--remove] [--upgrade] [--decrypt] [--encrypt]$RESET"
    exit 0
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  Remove
#   DESCRIPTION:  Removes current setup files. Invoke with --remove
#    PARAMETERS:  None
#       RETURNS:  None
#          Note:  There is NO backup.
#-------------------------------------------------------------------------------
Remove()
{
    # :TODO:03/01/2019 05:39:44 PM:hvalle: Need to add a backup/restore option
    echo "$RESET${RED}REMOVE$RESET Selected$RESET"
    echo "NOTE: There is no backup make are you sure?$RESET"
    read -n 1 -p "$BOLD${BLUE}Remove all configuration and files?$RESET (y/N): $GREEN" choice
    echo ""
    case "$choice" in
        y|Y ) :;;
        n|N ) echo "Canceled$RESET";exit 0;;
        * ) echo "Canceled$RESET";exit 0;;
    esac

    #Unlimk FILES
    for LINK in ${LINKS[@]}; do
        unlink $LINK 2>/dev/null
    done

    #Delete generated DIRS
    rm -rf $DOTFILES/vim/bundle
    rm -rf $DOTFILES/vim/autoload
    rm -rf $DOTFILES/vim/colors

    #Detete FILE created by the setup
    rm -f $DOTFILES/git/gitconfig
    rm -f $DOTFILES/vim/template/personal.template

    echo "Remove Complete$RESET"
    echo ""
    exit -1
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  Upgrade
#   DESCRIPTION:  Upgrade current setup after doing a git pull --upgrade
#    PARAMETERS:  None
#       RETURNS:  None
#          Note:  Might just do a Plug clean install etc
#-------------------------------------------------------------------------------
Upgrade()
{
    # :TODO:03/01/2019 05:41:45 PM:hvalle: Need to test this more. Do I link back?
    unlink ~/.bash_aliases
    unlink ~/.zsh_aliases
    vim +PlugInstall +PlugUpdate +PlugClean +qall
    exit 0
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  DecryptSecure
#   DESCRIPTION:  Decrypt secure file NOTE Must be called after AddToEnvironment
#    PARAMETERS:  none
#       RETURNS:  Success(0) or none
#-------------------------------------------------------------------------------
DecryptSecure()
{
    read -n 1 -p "$BOLD${BLUE}Use secure valut?$RESET (You must have a git repository setup) (y/N): $GREEN" choice
    echo "$RESET"
    case "$choice" in
        y|Y ) :;;
        n|N|* ) return;;
    esac
    read -p "${RESET}Enter$BOLD$BLUE git repository of secure vault$RESET ex\"https://github.com/<user name>/secure.git\": $GREEN" REPO

    (cd $DOTFILES && exec git clone $REPO)
    (exec $DOTFILES/scripts/unlock.sh)
    exit 0
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  EncryptSecure
#   DESCRIPTION:  Encrypt secure file NOTE Must be called after AddToEnvironment
#    PARAMETERS:  none
#       RETURNS:  Success(0) or none
#-------------------------------------------------------------------------------
EncryptSecure()
{
    read -n 1 -p "$BOLD${BLUE}Use secure valut?$RESET (You must have a git repository setup) (y/N): $GREEN" choice
    echo "$RESET"
    case "$choice" in
        y|Y ) :;;
        n|N|* ) return;;
    esac

    (exec $DOTFILES/scripts/lock.sh)

    exit 0
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  Init
#   DESCRIPTION:  Initialization of script. Color setup. Folder configuration.
#    PARAMETERS:  $@ Program input choices.
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
Init()
{
    #Check if running as sudo
    if [[  $EUID == 0 ]]
    then
        echo "Do ${RED}NOT$RESET run this script as root or with sudo$RESET"
        PrintHelp
    fi

    #Check and process command line arguments
    while [[  $# > 0 ]]; do
        case $1 in
            --administrator) ADMIN=1;;
            --remove) Remove;;
            --upgrade) Upgrade;;
            --decrypt) DecryptSecure;;
            --encrypt) EncryptSecure;;
            -h|--help|*) PrintHelp;;
        esac;
        shift;
    done

    echo "Installing$BOLD$BLUE $SCRIPTNAME$RESET"

    if [[ $ADMIN == 1 ]]; then
        echo "Admin Mode is:$BOLD$GREEN ON $RESET"
    fi
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  CheckOptional
#   DESCRIPTION:  Check for recommended but optional packages
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
CheckOptional()
{
    echo -n "Checking for optional packages:$RESET"
    ERRFLAG=false

    for PKG in $OPTPKGS; do
        if which $PKG 1>/dev/null 2>/dev/null; then
            echo -n "$BOLD$GREEN $PKG$RESET"
        else
            echo -n "$BOLD$YELLOW $PKG$RESET"
            ERRFLAG=true
        fi
    done
    echo ""
    if [[  $ERRFLAG ]]; then
        echo "$BOLD${YELLOW}Note:$RESET Recommended$BOLD$YELLOW NOT$RESET required package missing."
        unset ERRFLAG
    fi
    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  CheckDeps
#   DESCRIPTION:  Verifies system dependencies
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
CheckDeps()
{
    printf "Checking for Required Packages:$RESET"
    ERRFLAG=0

    for PKG in $PKGS; do
        if which $PKG 1>/dev/null 2>/dev/null; then
            printf "$BOLD$GREEN $PKG$RESET"
        else
            printf "$BOLD$RED $PKG$RESET"
            ERRFLAG=1
        fi
    done
    echo ""

    #if [[ $ERRFLAG == 1 ]] && [[ $ADMIN == 0 ]]; then
    if (( $ERRFLAG )) && (( ! $ADMIN )); then
            echo ""
            echo "$BOLD${RED}ERROR:$RESET Missing Required Package: RUN:$BOLD$BLUE \"$0 --administrator\"$RESET attempt to fix $RESET"
            echo ""
            exit -1
    fi
    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  SetupSys
#   DESCRIPTION:  Setup function for tmux, zsh
#    PARAMETERS:  None
#       RETURNS:  If selected, appends package setup to OSXPKGS or PKGS
#-------------------------------------------------------------------------------
SetupSys()
{

    read -n 1 -p "Setup$BOLD$BLUE tmux$RESET (Y/n): $GREEN" choice
    echo "$RESET"
    case "$choice" in
        n|N ) :;;
        y|Y|* ) PKGS+=" tmux"; TMUX=true;;
    esac

    read -n 1 -p "Setup$BOLD$BLUE zsh$RESET (Y/n): $GREEN" choice
    echo "$RESET"
    case "$choice" in
        n|N ) :;;
        y|Y|* ) PKGS+=" zsh"; ZSH=true;;
    esac

    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  AdminSetup
#   DESCRIPTION:  Administrator setup. Will required sudo access to the machine
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#          NOTE:  Only needed once on each computer
#-------------------------------------------------------------------------------
AdminSetup()
{
    echo "$BOLD${BLUE}Admin Setup$RESET ($OS)"
    ERRFLAG=false
    APTOPT=''

    echo -n "$BOLD${BLUE}Installing Packages: $RESET"
    for PKG in $PKGS; do
        if which $PKG 1>/dev/null 2>/dev/null; then
            echo -n "$BOLD$GREEN $PKG$RESET"
        else
            echo "$BOLD$YELLOW $PKG$RESET"
            $APTCMD $APTOPT $PKG
        fi
    done
    echo ""

    read -n 1 -p "Try to install$BOLD$BLUE Optional$RESET Packages (y/N): $GREEN" choice
    echo "$RESET"
    case "$choice" in
        y|Y ) :;;
        n|N|* ) echo ""; echo ""; return;;
    esac

    echo -n "$BOLD${BLUE}Installing Optional Packages: $RESET"
    for PKG in $OPTPKGS; do
        if which $PKG 1>/dev/null 2>/dev/null; then
            echo -n "$BOLD$GREEN $PKG$RESET"
        else
            echo "$BOLD$YELLOW $PKG$RESET"
            $APTCMD $APTOPT $PKG
        fi
    done

    echo ""
    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  GetUserInfo
#   DESCRIPTION:  Capture User information. This is required to setup the
#                 vim and git templates.
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
GetUserInfo()
{
    read -p "${RESET}Enter$BOLD$BLUE Full Name$RESET ex\"Waldo Doe\": $GREEN" name
    # Author ref
    author_ref=(${name// / })
    author_name="${author_ref[0]:0:1}${author_ref[1]}"  # take initialFirstName + lastName
    author_name="${author_name,,}"          # Make it lower case
    read -p "${RESET}Enter$BOLD$BLUE Author Ref$RESET (hit enter for default): \"$author_name\": $GREEN" ref
    ref="${ref:-$author_name}"              # Set default
    # Email
    tmp_email="${author_ref[0],,}${author_ref[1],,}@weber.mail.edu"  
    read -p "${RESET}Enter$BOLD$BLUE Email Address$RESET (hit enter for default): \"$tmp_email\": $GREEN" email
    email="${email:-$tmp_email}"
    # Organization
    read -p "${RESET}Enter$BOLD$BLUE Oganization$RESET (hit enter for default): \"WSU\": $GREEN" org
    org="${org:-WSU}"
    # Company
    read -p "${RESET}Enter$BOLD$BLUE Company$RESET (hit enter for default): \"WSU\": $GREEN" com
    com="${com:-WSU}"
    # License
    read -p "${RESET}Enter$BOLD$BLUE Default License$RESET (hit enter for default): $GREEN" license
    if [[  -z "$license" ]]; then
        license='this program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>\n.'
    fi
    printf "$RESET"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  InstallPowerLineFonts
#   DESCRIPTION:  Install Powerline Fonts. This is required to display all
#                 special characters in the status bar inside vim.
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
InstallPowerlineFonts()
{
    echo "$RESET"
    # clone fonts
    git clone https://github.com/powerline/fonts.git
    # install fonts
    cd fonts
    ./install.sh
    # clean-up a bit
    cd ..
    rm -rf fonts

    dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/font "'DejaVu Sans Mono for Powerline Book 12'"
    dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/use-system-font "false"
}



#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  CreatePersonalTemplate
#   DESCRIPTION:  Create personal vim templates for c, perl, bash, etc
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
CreatePersonalTemplate()
{
    echo "Creaing User Template File:$BOLD$BLUE $DOTFILES/vim/templates/personal.template$RESET"

printf "§ =============================================================
§  Personal Information
§ =============================================================

SetMacro( 'AUTHOR',       '%s' )
SetMacro( 'AUTHORREF',    '%s' )
SetMacro( 'EMAIL',        '%s' )
SetMacro( 'ORGANIZATION', '%s' )
SetMacro( 'COMPANY',      '%s' )
SetMacro( 'COPYRIGHT',    'Copyright (c) |YEAR|, |AUTHOR|' )
SetMacro( 'LICENSE',      '%s' )

§ =============================================================
§  Date and Time Format
§ =============================================================

§SetFormat( 'DATE', '%%x' )
§SetFormat( 'TIME', '%%H:%%M' )
§SetFormat( 'YEAR', '%%Y' )
" "$name" "$ref" "$email" "$org" "$com" > $DOTFILES/vim/templates/personal.template
}



#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  CreateGitConfig
#   DESCRIPTION:  Creates basic git configuration file based on input
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
CreateGitConfig()
{
    echo "Creating User Git Config:$BOLD$BLUE $DOTFILES/git/gitconfig$RESET"

    printf "
[user]
    name = %s
    email = %s
[core]
    editor = vim
    autocrlf= input
[diff]
    tool = vimdiff
[difftool]
    prompt = false
[merge]
    tool = vimdiff
[help]
    autocorrect = 1
[color]
    ui = auto
    branch = auto
    diff = auto
    interactive = auto
    status = auto
[push]
    default = matching
[credential]
    helper = cache --timeout=28800
[alias]
    export = archive -o latest.tar.gz -9 --prefix=latest/
    amend = !git log -n 1 --pretty=tformat:%%s%%n%%n%%b | git commit -F - --amend
    details = log -n1 -p --format=fuller
    logpretty = log --graph --decorate --pretty=format:'%%C(yellow)%%h%%Creset -%%C(auto)%%h %%d%%Creset %%s %%C(green)(%%cr) %%C(blue)<%%an>%%Creset' --abbrev-commit
    s = status
[url \"https://github.com/\"]
    insteadOf = gh:
" "$name" "$email" > $DOTFILES/git/gitconfig
}



#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  ManageFilesAndLinks
#   DESCRIPTION:  Create symbolic links to your ~/dotfiles directory
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
ManageFilesAndLinks()
{
    echo "Creating$BOLD$GREEN symlinks$RESET"
    for ((i=0; i<=${#LINKS[@]}-1;i++))
    do
        echo "Linked$BOLD$GREEN ${LINKS[${i}]} $RESET->$BOLD$BLUE ${FILES[${i}]} $RESET"
        ln -s ${FILES[${i}]} ${LINKS[${i}]}
    done

    echo "Downloading Colors wombat256mod.vim"
    mkdir -p $DOTFILES/vim/colors
    wget -O $DOTFILES/vim/colors/wombat256mod.vim http://www.vim.org/scripts/download_script.php?src_id=13400

    # :TODO:03/01/2019 06:21:52 PM:hvalle: Move this to the prezto function to set zsh there
    #if [[  -f ~/.zshrc && $ZSH == true ]]; then
    #    echo "Appending soruces to$BOLD$GREEN ~/.zshrc$RESET"
    #    echo "source ~/.zsh_aliases" >> ~/.zshrc
    #fi

    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  PatchPlugs
#   DESCRIPTION:  Patch Plugins
#    PARAMETERS:  None
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
PatchPlugs()
{
    echo "Patching NerdTree:$RESET$BOLD$BLUE $DOTFILES/vim/bundle/nerdtree/nerdtree_plugin/NerdTreePatch.vim$RESET"
    mkdir -p $DOTFILES/vim/bundle/nerdtree/nerdtree_plugin
    ln -s $DOTFILES/vim/patches/NerdTreePatch.vim $DOTFILES/vim/bundle/nerdtree/nerdtree_plugin/NerdTreePatch.vim
    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  AddToEnvironment
#   DESCRIPTION:  Add need variables to environment
#    PARAMETERS:  none
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
AddToEnvironment()
{
    echo "Add Environment Var:$RESET$BOLD$BLUE \$DOTFILES=$RESET$DOTFILES"

    for RCFILE in "${ENV_FILES[@]}"
    do
        if [[  -e ${RCFILE} ]]; then
            if grep -q "export DOTFILES=" "$RCFILE" 2>/dev/null; then
                echo "$BOLD$GREEN $RCFILE$RESET:$BOLD$BLUE Already added$RESET skipping"
            else
                echo "Adding to file:$BOLD$GREEN $RCFILE$RESET"
                echo "export DOTFILES=\"$DOTFILES\"" >> $RCFILE
                echo "export PATH=\"\$PATH:$DOTFILES/scripts\"" >> $RCFILE
                echo "source $DOTFILES/shell/autorun.sh" >> $RCFILE
            fi
        else
           echo "$YELLOW${BOLD}Note:$RESET$BOLD $RCFILE$RESET does not exist"
        fi
   done

    if [[  $OS == 'OSX' ]]; then
        touch ~/.bash_profile
        RCFILE="~/.bash_profile"
        echo "Adding to file:$BOLD$GREEN $RCFILE$RESET"
        echo "export DOTFILES=\"$DOTFILES\"" >> $RCFILE
        echo "export PATH=\"\$PATH:$DOTFILES/scripts\"" >> $RCFILE
        echo "source $DOTFILES/shell/autorun.sh" >> $RCFILE
    fi

    #Also export then for any subscript this script runs
    export DOTFILES="$DOTFILES"
    export PATH="$PATH:$DOTFILES/scripts"
    echo ""
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  main
#   DESCRIPTION:  This is the main driver function.
#    PARAMETERS:  Optional parameters: --help, --administrator, --remove
#       RETURNS:  Success or Error
#-------------------------------------------------------------------------------
main()
{
    source ./scripts/colors.sh
    
    DetectOS
    
    ScriptSettings
    
    Init "$@"     # Remember to pass the command line args $@
    
    SetupSys
    
    CheckDeps

    if [[ $ADMIN == 1 ]]
    then
	    CheckOptional
        AdminSetup
    fi
    
    GetUserInfo   # Get user information

    ManageFilesAndLinks   #Create Dirs Copy Files and Make Links

    AddToEnvironment

    #Install Powerline Fonts?
    read -n 1 -p  "Install$BOLD$BLUE PowerLine Fonts$RESET (Y/n): $GREEN" choice
    case "$choice" in
        n|N ) :;;
        y|Y|* ) InstallPowerlineFonts;;

    esac
    echo "$RESET"

    CreatePersonalTemplate
    CreateGitConfig

    vim +PlugInstall +qall #Installs the vim plugin system and updates all plugins

    PatchPlugs
    DecryptSecure

#    if [[ "$ZSH" == true ]]; then
#        echo "Downloading and installing: oh-my-zsh"
#        sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
#        AddToEnvironment
#    fi

    echo '      _       _                 _     _         '
    echo '     (_)_   _(_)_ __ ___       (_) __| | ___    '
    echo '     | \ \ / / | `_ ` _ \ _____| |/ _` |/ _ \   '
    echo '     | |\ V /| | | | | | |_____| | (_| |  __/   '
    echo '    _/ | \_/ |_|_| |_| |_|     |_|\__,_|\___|   '
    echo '   |__/                    ${BOLD}Enjoy a better vim$RESET   '
    echo ''

}

# Main Program
main "$@"     #remember to pass all command line args
exit 0
