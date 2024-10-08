#!/bin/sh
cat "$0" || cat /dev/fd/0

# URL to the checksum file
CHECKSUM_URL="https://raw.githubusercontent.com/hyperledger/web3j-installer/main/checksum-linux.txt"

# Function to fetch the pre-calculated checksum from GitHub
fetch_checksum() {
    curl --silent "$CHECKSUM_URL"
}

# Function to calculate checksum from script content (works for in-memory or file-based)
calculate_checksum() {
    script_content="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "$script_content" | sed '/^CHECKSUM_URL=/d' | shasum -a 256 | awk '{print $1}'
    else
      echo "$script_content" | sed '/^CHECKSUM_URL=/d' | sha256sum | awk '{print $1}'
    fi
}

# Verify the integrity of the script
verify_checksum() {
  script_content="$1"
  FETCHED_CHECKSUM=$(fetch_checksum)
  CURRENT_CHECKSUM=$(calculate_checksum "$script_content")

  if [ "$CURRENT_CHECKSUM" = "$FETCHED_CHECKSUM" ]; then
    echo "Checksum verification passed!"
  else
    echo "Script verification failed!"
    exit 1
  fi
}

main() {
  # Check if the script is being piped (i.e., in-memory execution)
  if [ -p /dev/stdin ]; then
    script_content=$(cat /dev/fd/0)
    verify_checksum "$script_content"

    # Execute the script content
    echo "$script_content" | sh
  else
    script_content=$(cat "$0")
    verify_checksum "$script_content"
    # Proceed to the actual logic after checksum verification
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
  if [ "$(curl --write-out "%{http_code}" --silent --output /dev/null "https://github.com/hyperledger/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.tar")" -eq 302 ]; then
    curl -# -L -o "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar" "https://github.com/hyperledger/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.tar"
    echo "Installing Web3j..."
    tar -xf "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar" -C "$HOME/.web3j"
    echo "export PATH=\$PATH:$HOME/.web3j" >"$HOME/.web3j/source.sh"
    chmod +x "$HOME/.web3j/source.sh"
    echo "Removing downloaded archive..."
    rm "$HOME/.web3j/web3j-cli-shadow-${web3j_version}.tar"
  else
    echo "Looks like there was an error while trying to download Web3j."
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
  # Add similar checks for other shell configurations
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
  printf "$RESET"
  exit 0
}

check_java_version() {
  java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  echo "Your current java version is ${java_version}"
  major_version=$(echo "$java_version" | cut -d'.' -f1)
  if [ "$major_version" -ge 17 ]; then
    echo "Your Java version is compatible with Web3j CLI."
  else
    echo "The Web3j CLI requires a Java version equals with 17 or higher."
    read -r -s -n 1 -p "Press any key to continue, or press Ctrl+C to cancel the installation." </dev/tty
  fi
}

# Execute main
main