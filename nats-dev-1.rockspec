package = "nats"
version = "dev-1"
source = {
    url = "git+https://github.com/muxa-xoma/tarantool-nats-connector.git",
    branch = "dev",
}
description = {
    summary = "NATS connector for Tarantool",
    homepage = "https://github.com/muxa-xoma/tarantool-nats-connector",
    license = "Apache-2.0",
    maintainer = "Mikhael Fomenko <muxa-xoma@mail.ru>"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        ["nats.utils.version"] = "src/nats/utils/version/init.lua",
        ["nats.utils.errors"] = "src/nats/utils/errors/init.lua",
        ["nats.utils.nuid"] = "src/nats/utils/nuid/init.lua",
        ["nats.utils.result"] = "src/nats/utils/result/init.lua",
        ["nats.transport.tcp"] = "src/nats/transport/tcp.lua",
        ["nats.transport"] = "src/nats/transport/init.lua",
        ["nats.protocol.server_info"] = "src/nats/protocol/server_info.lua",
        ["nats.protocol.connection_parameters"] = "src/nats/protocol/connection_parameters.lua",
        ["nats.protocol.constants"] = "src/nats/protocol/constants.lua",
        ["nats.protocol.command"] = "src/nats/protocol/command.lua",
        ["nats.protocol.parser"] = "src/nats/protocol/parser.lua",
        ["nats.protocol"] = "src/nats/protocol/init.lua",
        ["nats.client.server"] = "src/nats/client/server.lua",
        ["nats.client.message"] = "src/nats/client/message.lua",
        ["nats.client.subscription"] = "src/nats/client/subscription.lua",
        ["nats.client.options"] = "src/nats/client/options.lua",
        ["nats.client"] = "src/nats/client/init.lua",
        ["nats.version"] = "src/nats/version.lua",
        ["nats"] = "src/nats/init.lua"
    }
}