# helpers
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
function echo_ok { echo -e "${GREEN} $1 ${NC}"; }
function echo_warn { echo -e "${ORANGE} $1 ${NC}"; }
function echo_error  { echo -e "${RED}ERROR: $1 ${NC}"; }

#==============
# Install all the packages
# Ask for the administrator password upfront
#==============
sudo -v
# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Only try to change ownership if /usr/local exists and we have permission
if [ -d "/usr/local" ] && [ -w "/usr/local" ]; then
    sudo chown -R $(whoami):admin /usr/local
fi

# Check for Homebrew,
# Install if we don't have it
if test ! $(which brew); then
  echo_ok "Installing homebrew... 🍺"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo_ok "🍺Homebrew already installed"
fi

(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/$USER/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

echo_ok "Running Brew Doctor... 👨‍⚕️"
brew doctor

# Update homebrew recipes
echo_ok "Updating homebrew..."
brew update

# So we use all of the packages we are about to install
echo "export PATH='/usr/local/bin:$PATH'\n" >> ~/.bashrc
source ~/.bashrc

echo "Creating an SSH key for you..."
read -p "Enter your full name for Git: " USER_NAME
read -p "Enter your email address for SSH key and Git: " USER_EMAIL
ssh-keygen -t rsa -b 4096 -C "$USER_EMAIL"

echo_warn "Please add this public key to Github \n"
echo_ok "https://github.com/settings/keys \n"
read -p "Press [Enter] key after this..."

if test ! $(which g++); then
  echo_ok "Installing xcode-stuff"
  sudo rm -rf /Library/Developer/CommandLineTools
  xcode-select --install
else
  echo_ok "xcode cl tools already installed"
fi

sudo xcodebuild -license accept # Accepts the Xcode license

#==============
# Remove old dot flies
#==============
sudo rm -rf ~/.bashrc > /dev/null 2>&1
sudo rm -rf ~/.zsh_prompt > /dev/null 2>&1
sudo rm -rf ~/.zshrc > /dev/null 2>&1
sudo rm -rf ~/.gitconfig > /dev/null 2>&1
sudo rm -rf ~/.gitignore_global > /dev/null 2>&1
sudo rm -rf ~/.psqlrc > /dev/null 2>&1
sudo rm -rf ~/.config > /dev/null 2>&1
sudo rm -rf ~/Brewfile > /dev/null 2>&1
sudo rm -rf ~/.tmux > /dev/null 2>&1
sudo rm -rf ~/.tmux.conf > /dev/null 2>&1


#==============
# Create symlinks in the home folder
# Allow overriding with files of matching names in the custom-configs dir
#==============
SYMLINKS=()
ln -sf ~/dotfiles/bashrc ~/.bashrc
SYMLINKS+=('.bashrc')
ln -sf ~/dotfiles/zsh/zsh_prompt ~/.zsh_prompt
SYMLINKS+=('.zsh_prompt')
ln -sf ~/dotfiles/zsh/zshrc ~/.zshrc
SYMLINKS+=('.zshrc')
ln -sf ~/dotfiles/config ~/.config
SYMLINKS+=('.config')
ln -sf ~/dotfiles/homebrew/Brewfile ~/Brewfile
SYMLINKS+=('Brewfile')
ln -sf ~/dotfiles/tmux ~/.tmux
SYMLINKS+=('.tmux')
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
SYMLINKS+=('.tmux.conf')


if [ -d ~/dotfiles/custom-configs ] && [ -n "$(find ~/dotfiles/custom-configs -name gitconfig 2>/dev/null)" ]; then
    ln -s "$(find ~/dotfiles/custom-configs -name gitconfig | head -1)" ~/.gitconfig
else
    ln -s ~/dotfiles/gitconfig ~/.gitconfig
fi
SYMLINKS+=('.gitconfig')

if [ -d ~/dotfiles/custom-configs ] && [ -n "$(find ~/dotfiles/custom-configs -name gitignore_global 2>/dev/null)" ]; then
    ln -s "$(find ~/dotfiles/custom-configs -name gitignore_global | head -1)" ~/.gitignore_global
else
    ln -s ~/dotfiles/custom-configs/gitignore_global ~/.gitignore_global
fi
SYMLINKS+=('.gitignore_global')

if [ -d ~/dotfiles/custom-configs ] && [ -n "$(find ~/dotfiles/custom-configs -name psqlrc 2>/dev/null)" ]; then
    ln -s "$(find ~/dotfiles/custom-configs -name psqlrc | head -1)" ~/.psqlrc
else
    ln -s ~/dotfiles/psqlrc ~/.psqlrc
fi
SYMLINKS+=('.psqlrc')

echo_ok "Symlinks: " ${SYMLINKS[@]}

# Replace placeholders in gitconfig with actual user values
echo_ok "Configuring Git with your information..."
sed -i '' "s/{{USER_NAME}}/$USER_NAME/g" ~/.gitconfig
sed -i '' "s/{{USER_EMAIL}}/$USER_EMAIL/g" ~/.gitconfig
sed -i '' "s|{{HOME_PATH}}|$HOME|g" ~/.gitconfig

# # hack for... I'm not even sure what... sqlite working in Python with pyenv?
# sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /

cd ~
echo_ok "Installing apps from Brewfile 🙌"
brew bundle
cd -

echo "source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc

brew cleanup
brew doctor

echo_warn "Open Firefox and set as default browser 💻"
read -p "Press [Enter] once this is done."

echo_ok "Installing Python related items 🐍"
echo " * installing virtualenv via pip with --break-system-packages"
sudo pip3 install virtualenv --break-system-packages
echo " * installing uv (fast Python package installer)"
curl -LsSf https://astral.sh/uv/install.sh | sh
echo " * installing direnv"
# http://direnv.net/
brew install direnv



# echo_warn "Login to Dropbox and have the Dropbox folder in the $HOME directory."
# read -p "Press [Enter] once this is done."

echo_warn "Find the settings for iTerm2 in Dropbox and link each one of these applications with their corresponding settings file."
read -p "Press [Enter] once this is done."

# echo_ok "Installing Angular CLI"
# npm install -g @angular/cli

# Check FileVault status
echo "--> Checking full-disk encryption status:"
if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
  echo_ok "OK 👌"
else
  echo_warn "Enabling full-disk encryption on next reboot:"
  sudo fdesetup enable -user "$USER" \
    | tee ~/Desktop/"FileVault Recovery Key.txt"
  echo_ok "OK 👌"
fi

echo_ok "Expanding the save panel by default"
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

echo_ok "Automatically quit printer app once the print jobs complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

echo_ok "Showing icons for hard drives, servers, and removable media on the desktop"
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

echo_ok "Disabling the warning when changing a file extension"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

echo_ok "Setting the icon sizes of Dock items"
defaults write com.apple.dock tilesize -int 34
defaults write com.apple.dock largesize -int 55
defaults write com.apple.dock magnification -bool true

echo_ok "Setting Dock to auto-hide and removing the auto-hiding delay"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

echo_ok "Preventing Time Machine from prompting to use new hard drives as backup volume"
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

echo_ok "Show path in finder windows"
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true;

echo_ok "Setting fast key repeat rate and short delay"
defaults write -g InitialKeyRepeat -int 15  # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 2          # normal minimum is 2 (30 ms)

echo_ok "Enabling full keyboard access (Tab to navigate all controls)"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

killall Dock
killall Finder

#==============
# And we are done
#==============
echo -e "\n====== All Done!! ======\n"
echo
echo "Enjoy -Davis"
