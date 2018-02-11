(function () {
    'use strict';

    // Clear document body before start
    while (document.body.hasChildNodes()) {
        document.body.removeChild(document.body.lastChild);
    }

    // Initialize Elm app
    var Elm = require('../src/Main'),
        width = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth,
        height = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;

    Elm.Main.embed(document.body, { width: width, height: height });
})();