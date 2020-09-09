#!/bin/sh
# Use this script to checkout pytorch source and build it locally.

set -eux

ROOT="$( cd "$(dirname "$0")" ; pwd -P)"
PYTORCH_ROOT="${PYTORCH_ROOT:-$ROOT/pytorch}"

install_dependencies() {
  # Follow PyTorch local build instruction: https://github.com/pytorch/pytorch#from-source
  echo "Install conda dependencies..."
  conda install numpy ninja pyyaml mkl mkl-include setuptools cmake cffi
}

checkout_pytorch() {
  if [ ! -d "$PYTORCH_ROOT" ]; then
    echo "PyTorch src folder doesn't exist: $PYTORCH_ROOT. Downloading..."
    echo "You can use existing PyTorch src by 'export PYTORCH_ROOT=<path>'"
    mkdir -p "$PYTORCH_ROOT"
    git clone --recursive https://github.com/pytorch/pytorch "$PYTORCH_ROOT"
  else
    echo "Using PyTorch source code at: $PYTORCH_ROOT"
  fi
}

build_pytorch() {
  echo "Building PyTorch..."
  echo "!!! You might need run 'python setup.py clean' if the last build failed."

  cd $PYTORCH_ROOT

  REL_WITH_DEB_INFO=ON \
    BUILD_CAFFE2_OPS=OFF \
    BUILD_BINARY=OFF \
    BUILD_TEST=OFF \
    USE_DISTRIBUTED=OFF \
    python3 setup.py develop
}

#install_dependencies
checkout_pytorch
build_pytorch
