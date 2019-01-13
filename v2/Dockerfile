FROM ubuntu:xenial

RUN apt-get update &&  apt-get install -y software-properties-common python python-pip \
    git make curl build-essential

# Install Ansible
RUN apt-add-repository ppa:ansible/ansible -y && apt-get update && apt-get install ansible -y
RUN pip install pywinrm

# Install Golang

RUN curl -O https://storage.googleapis.com/golang/go1.11.2.linux-amd64.tar.gz
RUN tar -xvf go1.11.2.linux-amd64.tar.gz
RUN mv go /usr/local
RUN rm -rf go
RUN rm go1.11.2.linux-amd64.tar.gz
ENV GOPATH "/go"
ENV PATH "$PATH:/usr/local/go/bin:$GOPATH/bin"
RUN mkdir -p /go/src

RUN pip install configargparse

