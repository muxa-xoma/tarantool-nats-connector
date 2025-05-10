FROM tarantool/tarantool:3.3.1 AS integration-tests
LABEL authors="Mikhael Fomenko"

RUN apt-get update && \
    apt-get -y install \
        git

RUN tt rocks install https://raw.githubusercontent.com/muxa-xoma/tarantool-nats-connector/refs/heads/dev/nats-dev-1.rockspec

FROM tarantool/tarantool:3.3.1 AS unit-tests
LABEL authors="Mikhael Fomenko"

RUN apt-get update && \
    apt-get -y install \
        git \
        cmake

RUN tt rocks install luatest && \
    tt rocks install luacov && \
    tt rocks install luacheck

COPY src/nats /opt/tarantool/nats

COPY tests /opt/tarantool/tests
COPY tests/local_spec/.luacov /opt/tarantool/.luacov

FROM tarantool/tarantool:3.3.1 AS dev
LABEL authors="Mikhael Fomenko"

COPY src /tmp/src
COPY tests/local_spec/nats-scm-1.rockspec /tmp/src/nats
COPY tests/local_spec/nats-scm-1.rockspec /tmp

RUN cd /tmp/src && tar czf /tmp/nats.tar.gz ./nats
RUN tt rocks install /tmp/nats-scm-1.rockspec



