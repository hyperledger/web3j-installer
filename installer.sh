#!/bin/sh
web3j_version=${1:-$(curl https://internal.services.web3labs.com/api/epirus/versions/latest)}
installed_flag=0
installed_version=""

check_if_installed() {
  if [ -x "$(command -v web3j)" ] >/dev/null 2>&1; then
    printf 'An Web3j installation exists on your system.\n'
    installed_flag=1
  fi
}

setup_color() {
  # Only use colors if connected to a terminal
  if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    BOLD=$(printf '\033[1m')
    RESET=$(printf '\033[m')
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
  fi
}

install_web3j() {
  echo "Downloading Web3j ..."
  mkdir -p "$HOME/.web3j"
  if [ "$(curl --write-out "%{http_code}" --silent --output /dev/null "https://github.com/web3j/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.tar")" -eq 302 ]; then
    curl -# -L -o "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar" "https://github.com/web3j/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.tar"
    echo "Installing Web3j..."
    echo "https://github.com/web3j/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.tar"
    tar -xf "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar" -C "$HOME/.web3j"
    echo "export PATH=\$PATH:$HOME/.web3j" >"$HOME/.web3j/source.sh"
    chmod +x "$HOME/.web3j/source.sh"
    echo "Removing downloaded archive..."
    rm "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar"
  else
    echo "Looks like there was an error while trying to download web3j"
    exit 0
  fi
}
get_user_input() {
  while echo "Would you like to update Web3j [Y/n]" && read -r user_input </dev/tty ; do
    case $user_input in
    n)
      echo "Aborting installation ..."
      exit 0
      ;;
    *)
       echo "Updating Web3j ..."
       break
       ;;
    esac
  done
}

check_version() {
  installed_version=$(web3j --version | grep Version | awk -F" " '{print $NF}')
  if [ "$installed_version" = "$web3j_version" ]; then
      echo "You have the latest version of Web3j (${installed_version}). Exiting."
      exit 0
    else
      echo "Your Web3j version is not up to date."
      get_user_input
  fi
}

source_web3j() {
  SOURCE_Web3j="\n[ -s \"$HOME/.web3j/source.sh\" ] && source \"$HOME/.web3j/source.sh\""
  if [ -f "$HOME/.bashrc" ]; then
    bash_rc="$HOME/.bashrc"
    touch "${bash_rc}"
    if ! grep -qc '.web3j/source.sh' "${bash_rc}"; then
      echo "Adding source string to ${bash_rc}"
      printf "${SOURCE_Web3j}\n" >>"${bash_rc}"
    else
      echo "Skipped update of ${bash_rc} (source string already present)"
    fi
  fi
  if [ -f "$HOME/.bash_profile" ]; then
    bash_profile="${HOME}/.bash_profile"
    touch "${bash_profile}"
    if ! grep -qc '.web3j/source.sh' "${bash_profile}"; then
      echo "Adding source string to ${bash_profile}"
      printf "${SOURCE_Web3j}\n" >>"${bash_profile}"
    else
      echo "Skipped update of ${bash_profile} (source string already present)"
    fi
  fi
  if [ -f "$HOME/.bash_login" ]; then
    bash_login="$HOME/.bash_login"
    touch "${bash_login}"
    if ! grep -qc '.web3j/source.sh' "${bash_login}"; then
      echo "Adding source string to ${bash_login}"
      printf "${SOURCE_Web3j}\n" >>"${bash_login}"
    else
      echo "Skipped update of ${bash_login} (source string already present)"
    fi
  fi
  if [ -f "$HOME/.profile" ]; then
    profile="$HOME/.profile"
    touch "${profile}"
    if ! grep -qc '.web3j/source.sh' "${profile}"; then
      echo "Adding source string to ${profile}"
      printf "$SOURCE_Web3j\n" >>"${profile}"
    else
      echo "Skipped update of ${profile} (source string already present)"
    fi
  fi

  if [ -f "$(command -v zsh 2>/dev/null)" ]; then
    file="$HOME/.zshrc"
    touch "${file}"
    if ! grep -qc '.web3j/source.sh' "${file}"; then
      echo "Adding source string to ${file}"
      printf "$SOURCE_Web3j\n" >>"${file}"
    else
      echo "Skipped update of ${file} (source string already present)"
    fi
  fi
}

check_if_web3j_homebrew() {
  if (command -v brew && ! (brew info web3j 2>&1 | grep -e "Not installed\|No available formula") >/dev/null 2>&1); then
    echo "Looks like Web3j is installed with Homebrew. Please use Homebrew to update. Exiting."
    exit 0
  fi
}

clean_up() {
  if [ -d "$HOME/.web3j" ]; then
    rm -f "$HOME/.web3j/source.sh"
    rm -rf "$HOME/.web3j/web3j-cli-shadow-$installed_version" >/dev/null 2>&1
    echo "Deleting older installation ..."
  fi
}

completed() {
  cd "$HOME/.web3j"
  ln -sf "web3j-cli-shadow-$web3j_version/bin/web3j" web3j
  printf '\n'
  printf "$GREEN" 
  echo "Web3j was successfully installed."
  echo "To use web3j in your current shell run:"
  echo "source \$HOME/.web3j/source.sh"
  echo "When you open a new shell this will be performed automatically."
  echo "To see what Web3j's CLI can do you can check the documentation bellow."
  echo "https://docs.web3j.io/latest/command_line_tools/"
  printf "$RESET" 
  exit 0
}

check_java_version() {
  java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  echo "Your current java version is ${java_version}"
  is_compatible=$(curl "https://internal.services.web3labs.com/api/epirus/compatibility/${java_version}")
  if [ "$is_compatible" != "True" ]; then
    echo "The Web3j CLI requires a Java version between 1.8 and 12. Please ensure you have a compatible Java version before installing Web3j for full functionality."
    read -s -n 1 -p "Press any key to continue, or press Ctrl+C to cancel the installation." </dev/tty 
  fi
}

main() {
  setup_color
  check_java_version
  check_if_installed
  if [ $installed_flag -eq 1 ]; then
    check_if_web3j_homebrew
    check_version
    clean_up
    install_web3j
    source_web3j
    completed
  else
    install_web3j
    source_web3j
    completed    
  fi
}

main
