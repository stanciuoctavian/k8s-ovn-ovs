FROM ubuntu:xenial

RUN apt-get update && apt-get install -y build-essential git libssl-dev libffi-dev python-dev python-openssl python-pip && \
    pip install --upgrade setuptools && \
    pip install python-openstackclient && \
    pip install python-novaclient && \
    pip install crudini

# Install jq
RUN apt-get install -y jq

# Install gcloud

RUN apt-get install -y wget

ENV PATH=/google-cloud-sdk/bin:/workspace:${PATH} \
    CLOUDSDK_CORE_DISABLE_PROMPTS=1

RUN wget -q https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz && \
    tar xzf google-cloud-sdk.tar.gz -C / && \
    rm google-cloud-sdk.tar.gz && \
    /google-cloud-sdk/install.sh \
        --disable-installation-options \
        --bash-completion=false \
        --path-update=false \
        --usage-reporting=false && \
    gcloud components install alpha beta && \
    gcloud info | tee /gcloud-info.txt

ADD ./bootstrap.sh .
ADD ./started_template.jq .
ADD ./finished_template.jq .

ENTRYPOINT ["./bootstrap.sh"]
