#!/bin/bash
set -e
if [ -f "C:\\windows\\system32\\drivers\\etc\\hosts" ]; then
  choco install -y jdk8
  export JAVA_HOME="C:\\Program Files\\Java\\jdk1.8.0_211"
  powershell -executionpolicy bypass .\\installer.ps1
  chmod +x ~/.web3j/*/bin/web3j.bat

  ~/.web3j/*/bin/web3j.bat --version
  exit 0
fi

sh installer.sh
echo "Web3j source script content:"
cat $HOME/.web3j/source.sh
echo "Sourcing web3j source script"
source $HOME/.web3j/source.sh
echo "System path:"
echo $PATH
web3j --version
