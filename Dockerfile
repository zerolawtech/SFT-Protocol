# run with:
# docker build -f Dockerfile -t brownie .
# docker run -v $PWD:/usr/src brownie brownie test

FROM ubuntu:bionic
WORKDIR /usr/src

RUN  apt-get update

RUN apt-get install -y python3.6 python3-pip python3-venv wget curl git npm nodejs
RUN pip3 install wheel pip setuptools virtualenv

RUN npm install -g ganache-cli

# apt provided versions of solc doesn't have the version
# we use so use this route to get our specific version
# NB: py-solc only supports up to 0.4.X at the moment 
ARG SOLC_VERSION=v0.5.3
RUN wget --quiet --output-document /usr/local/bin/solc https://github.com/ethereum/solidity/releases/download/${SOLC_VERSION}/solc-static-linux \
    && chmod a+x /usr/local/bin/solc

RUN curl https://raw.githubusercontent.com/iamdefinitelyahuman/brownie/master/brownie-install.sh | sh

# Brownie installs compilers at runtime so ensure the updates are
# in the compiled image so it doesn't do this every time
RUN brownie init; true
RUN brownie test

# Fix UnicodeEncodeError error when running tests
ENV PYTHONIOENCODING=utf-8
