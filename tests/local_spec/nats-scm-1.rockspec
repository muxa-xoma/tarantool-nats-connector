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
        ["nats"] = "init.lua",
        ["nats.version"] = "version/init.lua",
        ["nats.errors"] = "errors/init.lua",
    }
}