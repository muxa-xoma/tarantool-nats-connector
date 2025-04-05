package = "nats"
version = "scm-1"
source = {
    --url = "git+https://github.com/tarantool/expirationd.git",
    --branch = "master",
    url = "file:///tmp/nats.tar.gz"
}
description = {
    summary = "NATS connector for Tarantool",
    --homepage = "https://github.com/tarantool/expirationd",
    --license = "BSD2",
    --maintainer = "Oleg Jukovec <oleg.jukovec@tarantool.org>"
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
        ["nats.protocol.command"] = "protocol/command.lua",
        ["nats.protocol"] = "protocol/init.lua",
        ["nats"] = "init.lua"
    }
}