#!/bin/bash

set -ex -o pipefail

# setup conda: https://unix.stackexchange.com/questions/454957/cron-job-to-run-under-conda-virtual-environment
# add the following lines to `crontab -e`:
# SHELL=/bin/bash
# BASH_ENV=~/.bashrc_conda
# MAILTO=...@email.com
source ${HOME}/anaconda3/etc/profile.d/conda.sh
conda activate

# set the follow environment variables:
export LLVM_DIR=/usr/lib/llvm-8
export SRC_ROOT=${HOME}/src
export HTML_GIT_ROOT=${HOME}/www
export WORKING_ROOT=/tmp/codebrowser

export CODE_BROWSER_SRC_ROOT=${SRC_ROOT}/woboq_codebrowser
export CODE_BROWSER_BUILD_ROOT=${CODE_BROWSER_SRC_ROOT}/build
export STAGING_DIRECTORY=${WORKING_ROOT}/output_staging
export PUBLISH_DIRECTORY=${HTML_GIT_ROOT}/codebrowser

install_deps() {
  if [ -d ${LLVM_DIR} ]; then
    return
  fi
  sudo apt install llvm-8-dev
  sudo apt install libclang-8-dev
}

install_ccache() {
  sudo apt install -y ccache
  export PATH="/usr/lib/ccache:$PATH"
}

checkout_code_browser() {
  if [ -d ${CODE_BROWSER_SRC_ROOT} ]; then
    return
  fi
  git clone --recursive https://github.com/woboq/woboq_codebrowser.git ${CODE_BROWSER_SRC_ROOT}
}

build_code_browser() {
  if [ -d ${CODE_BROWSER_BUILD_ROOT} ]; then
    return
  fi
  mkdir -p ${CODE_BROWSER_BUILD_ROOT}
  cd ${CODE_BROWSER_BUILD_ROOT}
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  make
}

ensure_prerequisites() {
  install_deps
  install_ccache
  checkout_code_browser
  build_code_browser
}

call_code_browser() {
  VERSION=`cd ${SOURCE_DIRECTORY} && git describe --always --tags`

  echo "PROJECT NAME: ${PROJECT_NAME}"
  echo "SRC DIR: ${SOURCE_DIRECTORY}"
  echo "BUILD DIR: ${BUILD_DIRECTORY}"
  echo "VERSION: ${VERSION}"

  # generate result into staging directory
  rm -rf ${STAGING_DIRECTORY}/${PROJECT_NAME}

  ${CODE_BROWSER_BUILD_ROOT}/generator/codebrowser_generator \
      -b ${BUILD_DIRECTORY} \
      -a -o ${STAGING_DIRECTORY}/${PROJECT_NAME} \
      -p ${PROJECT_NAME}:${SOURCE_DIRECTORY}:${VERSION}

  ${CODE_BROWSER_BUILD_ROOT}/indexgenerator/codebrowser_indexgenerator \
      ${STAGING_DIRECTORY}/${PROJECT_NAME}

  # move from staging directory to publish directory
  rsync -a --delete --remove-source-files \
      ${STAGING_DIRECTORY}/${PROJECT_NAME} ${PUBLISH_DIRECTORY}

  rsync -a --delete \
      ${CODE_BROWSER_SRC_ROOT}/data ${PUBLISH_DIRECTORY}
}

clean_git() {
  if [ ! -d ${HTML_GIT_ROOT}/.git ]; then
    return
  fi
  cd ${HTML_GIT_ROOT}
  git reset --hard
  git clean -fd
  git pull --rebase
}

push_git() {
  if [ ! -d ${HTML_GIT_ROOT}/.git ]; then
    return
  fi
  cd ${HTML_GIT_ROOT}
  git add -A
  git commit -m "update codebrowser"
  git pull --rebase
  git push
}

index_code_browser() {
  PROJECT_NAME=codebrowser
  SOURCE_DIRECTORY=${CODE_BROWSER_SRC_ROOT}
  BUILD_DIRECTORY=${CODE_BROWSER_BUILD_ROOT}

  call_code_browser
}

index_code_browser_pytorch() {
  PROJECT_NAME=pytorch
  SOURCE_DIRECTORY=${WORKING_ROOT}/pytorch
  BUILD_DIRECTORY=${SOURCE_DIRECTORY}/build

  rm -rf ${SOURCE_DIRECTORY}
  git clone --recursive https://github.com/pytorch/pytorch.git ${SOURCE_DIRECTORY}

  cd ${SOURCE_DIRECTORY}
  python setup.py develop

  call_code_browser
}

ensure_prerequisites
clean_git
index_code_browser
index_code_browser_pytorch
push_git
