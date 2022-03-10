# -*- mode: dockerfile; eval: (follow-mode) -*-
FROM graygnuorg/pies:debian-2.8.1 as pies
FROM perl:5.34.0-buster

ENV DEBIAN_FRONTEND=noninteractive \
    \
    TZ='UTC' \
    SET_X='-'

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ARG BUILD_DEPS="libssl-dev git make gcc"
ARG DEBUG_DEPS="vim net-tools procps busybox"

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    busybox-syslogd \
    ca-certificates \
    debconf-utils \
    gnupg2 \
    lsb-release \
    net-tools \
    curl \
    jq \
    tzdata \
    ${BUILD_DEPS} \
    ${DEBUG_DEPS} \
    && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3602B07F55D0C732 79FFD94BFCE230B1 && \
    echo "deb [arch=amd64] https://debian.archive.norse.digital/$(lsb_release -sc) $(lsb_release -sc) main" > /etc/apt/sources.list.d/norse.list \
    && \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    micron \
    tallyman

COPY tree/Crypt-Curve25519-0.06-fmul.diff /usr/src/
RUN cd /usr/src && \
    curl -oCrypt-Curve25519-0.06.tar.gz https://cpan.metacpan.org/authors/id/A/AJ/AJGB/Crypt-Curve25519-0.06.tar.gz && \
    tar xf Crypt-Curve25519-0.06.tar.gz && \
    cd Crypt-Curve25519-0.06 && \
    patch -p1 < ../Crypt-Curve25519-0.06-fmul.diff && \
    perl Makefile.PL && \
    make && make install

RUN cpan -T -i \
    Test::More \
    Array::Utils \
    Catalyst::Runtime \
    Cache::FastMmap \
    Cache::Memory \
    Catalyst::Model::Factory::PerRequest \
    Catalyst::Action::RenderView \
    Catalyst::Authentication::Store::LDAP \
    Catalyst::Plugin::Authentication \
    Catalyst::Plugin::Authorization::ACL \
    Catalyst::Plugin::Authorization::Roles \
    Catalyst::Plugin::Cache \
    Catalyst::Plugin::ConfigLoader \
    Catalyst::Plugin::Session::Store::FastMmap \
    Catalyst::Plugin::StackTrace \
    Catalyst::Plugin::Static::Simple \
    Catalyst::Plugin::StatusMessage \
    Catalyst::Plugin::Unicode \
    Catalyst::View::Download \
    Catalyst::View::JSON \
    Catalyst::View::TT \
    Compress::LZ4 \
    Config::General \
    Crypt::GeneratePassword \
    Crypt::HSXKPasswd \
    Crypt::RSA \
    Crypt::X509 \
    Crypt::X509::CRL \
    Data::Entropy \
    Data::Printer \
    DateTime::Format::Duration \
    Digest::SHA1 \
    GD::Barcode::QRcode \
    Lingua::Translit \
    Log::Contextual \
    Log::Dispatch \
    Log::Log4perl \
    MIME::Base64 \
    MikroTik::API \
    Math::Random::Secure \
    Module::Install \
    Module::Install::Catalyst \
    Moose \
    Net::CIDR::Set \
    Net::LDAP \
    Net::Netmask \
    Set::Object \
    Template::Plugin::JSON \
    Text::Diff::HTML \
    Text::Unidecode \
    Sub::Identify \
    HTML::Entities \
    HTML::FormHandler::Moose \
    YAML \
    Net::SSH::Perl

RUN git clone https://github.com/z-eos/umi.git && \
    catalyst.pl umi && \
    cd /umi && perl Makefile.PL && make

ADD  tree/umi*          /umi/
ADD  tree/conf		/umi/conf
COPY --from=pies /pies  /pies
ADD  tree/pies/pies.d/* /pies/conf.d/

WORKDIR /umi

ENV PATH="/pies/sbin:/pies/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

HEALTHCHECK --interval=30s --timeout=10s  --retries=5 \
    CMD /usr/bin/tallyman -- "${TALLYMAN_SRVID}"

EXPOSE 80 8073

# the entrypoint used in pies image
ENTRYPOINT ["/pies/conf/rc"]

RUN rm -rf /usr/src/* && \
    apt-get purge -y --auto-remove ${BUILD_DEPS} && \
    rm -rf /var/lib/apt/lists/*

# https://opencontainers.org/
# https://github.com/opencontainers/image-spec/blob/master/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.vendor="Norse Digital" \
    org.opencontainers.image.title="Base php image" \
    org.opencontainers.image.authors="gray@ zp@ vlad.tuznichenko@" \
    org.opencontainers.image.documentation="Base for creating images with components managed by GNU Pies" \
    org.opencontainers.image.description="\
    sofware.xenv.url=http://ps.gnu.org.ua/software/xenv/; \
    sofware.micron.url=https://ps.gnu.org.ua/software/micron/; \
    sofware.cachetool.url=https://github.com/gordalina/cachetool/; \
    sofware.nginx.port=80,443; \
    sofware.nginx.url=https://www.nginx.com/; \
    sofware.pies.port=8073; \
    sofware.pies.url=http://ps.gnu.org.ua/software/pies/;"

