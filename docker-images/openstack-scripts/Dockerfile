FROM debian:jessie

RUN apt-get update && apt-get install -y build-essential git libssl-dev libffi-dev python-dev python-openssl python-pip && \
    pip install --upgrade pip && \
    pip install --upgrade setuptools && \
    pip install python-openstackclient && \
    pip install python-novaclient && \
    pip install crudini

ADD ./bootstrap.sh .

ENTRYPOINT ["./bootstrap.sh"]
