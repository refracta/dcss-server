#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const patchPath = path.resolve(
    __dirname, "../../etc/webserver-patches/housing-session.patch");
const lines = fs.readFileSync(patchPath, "utf8").split(/\r?\n/);
const marker = "+    function housing_lobby_place(data)";
const start = lines.indexOf(marker);
assert.notEqual(start, -1, "Housing lobby place helper is missing");

const sourceLines = [];
for (let index = start; index < lines.length; index += 1)
{
    if (!lines[index].startsWith("+"))
        break;
    sourceLines.push(lines[index].slice(1));
    if (lines[index] === "+    }")
        break;
}
const context = {};
vm.runInNewContext(sourceLines.join("\n"), context);
const displayPlace = context.housing_lobby_place;
assert.equal(typeof displayPlace, "function");

assert.equal(displayPlace({place: "D:1"}), "D:1");
assert.equal(displayPlace({place: "D:1", housing_place: "Bob:gallery"}),
             "Bob:gallery");
assert.equal(displayPlace({place: "D:1", housing_place: ""}), "D:1");
assert.equal(displayPlace({place: "D:1", housing_place: 17}), "D:1");

const patch = lines.join("\n");
assert.match(patch, /set\("place", housing_lobby_place\(data\)\);/);
