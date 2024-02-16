FROM registry.opensource.zalan.do/acid/spilo-14:2.1-p2
LABEL maintainer="GGIRCS Team <ggircs@gov.bc.ca>"

# For this version of the patroni image, the postgres packages have been archived
# and the apt sources need to point at the archived repo
# https://www.postgresql.org/message-id/ZN4OigxPJA236qlg%40msg.df7cb.de
RUN <<EOF
cat > /etc/apt/sources.list.d/pgdg.list << EOL
deb https://apt-archive.postgresql.org/pub/repos/apt bionic-pgdg main
deb-src https://apt-archive.postgresql.org/pub/repos/apt bionic-pgdg main
EOL
EOF

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
