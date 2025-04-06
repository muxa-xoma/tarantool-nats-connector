package = "nats"
version = "scm-1"
source = {
    --url = "git+https://github.com/tarantool/expirationd.git",
    --branch = "master",
    url = "file:///tmp/nats.tar.gz"
}
description = {
    summary = "NATS connector for Tarantool",
    homepage = "https://github.com/muxa-xoma/tarantool-nats-connector",
    license = "Apache-2.0",
    maintainer = "Mikhael Fomenko <muxa-xoma@mail.ru>"
}
dependencies = {
    "lua >= 5.1",
    --"checks >= 2.1",
}
build = {
    type = "builtin",
    modules = {
        ["nats.utils.version"] = "utils/version/init.lua",
        ["nats.utils.errors"] = "utils/errors/init.lua",
        ["nats.utils.nuid"] = "utils/nuid/init.lua",
        ["nats.utils.result"] = "utils/result/init.lua",
        ["nats.utils.server"] = "utils/server/init.lua",
        ["nats.transport.tcp"] = "transport/tcp.lua",
        ["nats.transport"] = "transport/init.lua",
        ["nats.protocol.constants"] = "protocol/constants.lua",
        ["nats.protocol.command"] = "protocol/command.lua",
        ["nats.protocol.parser"] = "protocol/parser.lua",
        ["nats.protocol"] = "protocol/init.lua",
        ["nats.client.server"] = "client/server.lua",
        ["nats"] = "init.lua"
    }
}