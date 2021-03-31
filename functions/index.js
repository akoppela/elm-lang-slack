var functions = require('firebase-functions');
var admin = require('firebase-admin');
var cors = require('cors')({ origin: true });
var querystring = require('querystring');
var request = require('request');
var config = functions.config();

// Initialize app
admin.initializeApp(config.firebase);

var usersRef = admin.firestore().collection('members').doc('data');
var channelsRef = admin.firestore().collection('channels').doc('data');

/**
 * Exports `updateUsers` function to Firebase
 */
exports.updateUsers = functions.https.onRequest(function (request, response) {
    cors(request, response, function () {});

    makeHttpRequest('users.list', {}, function (data) {
        if (data.members) {
            var timeZones = data.members
                .filter(function (member) {
                    return member.tz_offset;
                })
                .map(function (member) {
                    return member.tz_offset / 3600;
                })
                .sort(function (a, b) {
                    return a - b;
                })
                .reduce(function (accumulator, timeZone) {
                    var lastGroup = accumulator[accumulator.length - 1];

                    if (lastGroup && lastGroup.timeZone === timeZone) {
                        lastGroup.number++;
                    } else {
                        accumulator.push({
                            timeZone: timeZone,
                            number: 1,
                        });
                    }

                    return accumulator;
                }, []);

            usersRef.set({
                total: data.members.length.toString(),
                timeZones: timeZones,
            });
        }

        response.end();
    });
});

/**
 * Exports `updateChannels` function to Firebase
 */
exports.updateChannels = functions.https.onRequest(function (request, response) {
    var params = {
        exclude_archived: true,
        exclude_members: true,
    };

    cors(request, response, function () {});

    makeHttpRequest('channels.list', params, function (data) {
        if (data.channels) {
            var channels = data.channels
                .map(function (channel) {
                    return {
                        id: channel.id,
                        name: channel.name,
                        topic: channel.topic.value,
                        members: channel.num_members,
                    };
                })
                .sort(function (a, b) {
                    return b.members - a.members;
                })
                .slice(0, 6);

            channelsRef.set({ entries: channels });
        }

        response.end();
    });
});

/**
 * Exports `getData` function to Firebase
 */
exports.getData = functions.https.onRequest(function (request, response) {
    var docRef = request.query.document === 'users' ? usersRef : channelsRef;

    cors(request, response, function () {});

    docRef.get()
        .then(function (doc) {
            response.send(doc.data());
        })
        .catch(function () {
            response.status(500).send();
        });
});

/**
 * Makes HTTP request to Slack API
 */
function makeHttpRequest(path, params, callback) {
    params = params || {};
    params.token = config.slack.token;

    var url = 'https://slack.com/api/' + path + '?' + querystring.stringify(params);

    request(url, function (error, response, body) {
        callback(JSON.parse(body));
    });
}