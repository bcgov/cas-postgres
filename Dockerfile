FROM registry.opensource.zalan.do/acid/spilo-12:1.6-p5
LABEL maintainer="Matthieu Foucault <matthieu@button.is>"

COPY root /

# TODO: pg needs to be running to check TAP install
# make installcheck && \
RUN apt-get update && \
    # OpenSSL needs manual update from the base image, to address a couple of CVEs
    apt-get install -y openssl && \
    apt-get install -y git make perl patch && \
    apt-get clean && \
    git clone -b 'v1.0.0' --single-branch https://github.com/theory/pgtap.git && \
    cd pgtap  && \
    make && \
    make install && \
    cd .. && \
    rm -r pgtap
