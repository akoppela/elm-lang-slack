(function () {
    // Initialize Elm app
    var width = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth;
    var height = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
    var Main = require('./Main.elm').Elm.Main;

    Main.init({
        node: document.getElementById('loading'),
        flags: {
            width: width,
            height: height,
        },
    });
}());