FROM centos:7

LABEL org.label-schema.vcs-url="https://github.com/giovtorres/slurm-docker-cluster" \
      org.label-schema.docker.cmd="docker-compose up -d" \
      org.label-schema.name="slurm-docker-cluster" \
      org.label-schema.description="Slurm Docker cluster on CentOS 7" \
      maintainer="Giovanni Torres"

RUN yum makecache fast \
    && yum -y install epel-release
RUN groupadd -r slurm --gid=2001 && useradd -r -g slurm --uid=2001 slurm
RUN yum -y install \
          bash-completion \
          bzip2 \
          gcc \
          gcc-c++\
          git \
          hwloc hwloc-devel \
          lua-devel \
          make \
          mariadb-devel \
          mariadb-server \
          munge \
          munge-devel \
          net-tools \
          numactl-devel \
          openssh-server \
          perl \
          pmix-devel \
          psmisc \
          python-devel \
          python-pip \
          vim-enhanced \
          wget

RUN yum -y install https://centos7.iuscommunity.org/ius-release.rpm
RUN yum -y install \
           python36u \
           python36u-devel \
           python36u-pip

RUN ln -sf /usr/bin/python3.6 /usr/bin/python3
RUN ln -sf /usr/bin/pip3.6 /usr/bin/pip3

RUN yum clean all \
    && rm -rf /var/cache/yum

RUN pip install Cython nose \
    && pip3 install Cython nose

ARG GOSU_VERSION=1.10

RUN set -x \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ARG SLURM_VERSION=17.11.7
ARG SLURM_DOWNLOAD_MD5=6452300949ba375c3898ba7ce7959f05
ARG SLURM_DOWNLOAD_URL=https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2

RUN set -x \
    && wget -O slurm.tar.bz2 "$SLURM_DOWNLOAD_URL" \
    && echo "$SLURM_DOWNLOAD_MD5" slurm.tar.bz2 | md5sum -c - \
    && mkdir /usr/local/src/slurm \
    && tar jxf slurm.tar.bz2 -C /usr/local/src/slurm --strip-components=1 \
    && rm slurm.tar.bz2

ARG SLURM_PREFIX=/opt/software/slurm
ENV PATH ${SLURM_PREFIX}/bin:${SLURM_PREFIX}/sbin:$PATH

RUN cd /usr/local/src/slurm \
    && ./configure \
    --enable-debug \
    --prefix=${SLURM_PREFIX} \
    --sysconfdir=/etc/slurm \
    --with-mysql_config=/usr/bin \
    --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurm.epilog.clean /etc/slurm/slurm.epilog.clean \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh

RUN mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

# SSHD
RUN /usr/bin/ssh-keygen -A
RUN groupadd --gid=5000 usertest && useradd --gid=5000 --uid=5000 usertest

# Plugins
WORKDIR /usr/local/src
RUN git clone https://github.com/stanford-rc/slurm-spank-lua
WORKDIR slurm-spank-lua

RUN cc -I/usr/local/src/slurm/ -o spank_lua.o -fPIC -c lua.c \
    && cc -o lib/list.o -fPIC -c lib/list.c \
    && cc -shared -fPIC -o spank_lua.so spank_lua.o lib/list.o -llua \
    && cp spank_lua.so /usr/lib64/spank_lua.so

WORKDIR /usr/local/src
RUN git clone https://github.com/quantumhpc/slurm-spank-stunnel
WORKDIR slurm-spank-stunnel
RUN gcc -I/usr/local/src/slurm/ -shared -fPIC -o slurm-spank-stunnel.so slurm-spank-stunnel.c \
    && cp slurm-spank-stunnel.so /usr/lib64/slurm-spank-stunnel.so

WORKDIR /

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
