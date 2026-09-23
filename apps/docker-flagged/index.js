"use strict";
const semver = require("semver");
module.exports = () => semver.valid("1.0.0") ? "isplt-docker-flagged" : "invalid";
