FROM registry.opensource.zalan.do/acid/spilo-12:1.6-p3
LABEL maintainer="Matthieu Foucault <matthieu@button.is>"

COPY root /

RUN /usr/libexec/fix-permissions "$PGHOME"

# TODO: pg needs to be running to check TAP install
# make installcheck && \
RUN apt-get update && \
    apt-get install -y git make perl patch && \
    apt-get clean && \
    git clone -b 'v1.0.0' --single-branch https://github.com/theory/pgtap.git && \
    cd pgtap  && \
    make && \
    make install && \
    cd .. && \
    rm -r pgtap

# libnss-wrapper is needed for openshift anyuid support
RUN apt-get install libnss-wrapper && apt-get clean

# Get prefix path to scripts rather than hard-code it
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/postgresql

COPY /usr/share/container-scripts/postgresql/callback_endpoint.py /scripts

ENTRYPOINT ["container-entrypoint"]

CMD ["/bin/sh", "/launch.sh", "init"]
