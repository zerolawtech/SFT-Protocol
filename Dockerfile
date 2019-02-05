# run with:
# docker build -f Dockerfile -t brownie .
# docker run -v $PWD:/usr/src brownie brownie test
# If you need to update the version of brownie then add the --no-cache
#  flag to the docker build command

FROM ubuntu:bionic
WORKDIR /usr/src

RUN  apt-get update

RUN apt-get install -y python3.6 python3-pip python3-venv wget curl git npm nodejs
RUN pip3 install wheel pip setuptools virtualenv

RUN npm install -g ganache-cli@6.2.5

RUN curl https://raw.githubusercontent.com/iamdefinitelyahuman/brownie/master/brownie-install.sh | sh

# Brownie installs compilers at runtime so ensure the updates are
# in the compiled image so it doesn't do this every time
RUN brownie init; true
RUN brownie test

# Fix UnicodeEncodeError error when running tests
ENV PYTHONIOENCODING=utf-8
