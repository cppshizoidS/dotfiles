#!/bin/bash
# Проверка типа дистрибутива
if [ -x "$(command -v apt-get)" ]; then
    # Debian/Ubuntu-based дистрибутив
    sudo apt-get update
    sudo apt-get install -y build-essential neofetch git clang clang-tools gcc cmake ninja-build lld lldb valgrind python3-pip doxygen neovim

elif [ -x "$(command -v dnf)" ]; then
    sudo dnf install -y @development-tools neofetch git clang clang-tools-extra gcc cmake ninja-build lld lldb valgrind python3-pip doxygen neovim


else
    echo "Не удалось определить дистрибутив и установщик пакетов."
    exit 1
fi

pip3 install conan

set -e
set -x

BASEDIR=$(dirname "$0")
pushd "$BASEDIR"

rm -rf build

conan install . --output-folder=build --build=missing
cd build
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build .
./test


