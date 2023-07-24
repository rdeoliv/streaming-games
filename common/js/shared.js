const ably = new Ably.Realtime.Promise(ABLY_API_KEY);
const userChannel = ably.channels.get('game-events')
const resultChannel = ably.channels.get('losses-events')

function produceToUserGame(user,gameName, score, lives, level) {
	/*
	var topic = "USER_GAME"
	var ksqlQuery =`INSERT INTO ${topic} (USER_KEY, GAME) VALUES ( STRUCT(USER:='${user}', GAME_NAME:='${gameName}'), STRUCT(SCORE:=${score},LIVES:=${lives},LEVEL:=${level}));`

	const request = new XMLHttpRequest();
	sendksqlDBStmt(request, ksqlQuery);
	*/

	//Publish update to Ably
	sendUpdateToAbly(userChannel, {'USER_KEY':{'USER':user,'GAME_NAME':'2048'},'GAME':{'SCORE':score,'LIVES':lives,'LEVEL':level}});
}

function produceToUserLosses(user,gameName) {

	/*
	var topic = "USER_LOSSES"
	var ksqlQuery =`INSERT INTO ${topic} (USER_KEY) VALUES ( STRUCT(USER:='${user}', GAME_NAME:='${gameName}') );`

	const request = new XMLHttpRequest();
	sendksqlDBStmt(request, ksqlQuery); */

	//Publish update to Ably
	sendUpdateToAbly(resultChannel,{'USER_KEY':{'USER':user,'GAME_NAME':'2048'}});

}


function loadHighestScore(gameName, user, ctx, callback ) {

	var highestScore ;

	ksqlQuery = `select  HIGHEST_SCORE from STATS_PER_USER WHERE USER_KEY=STRUCT(USER:='${user}', GAME_NAME:='${gameName}');`;

	var request = new XMLHttpRequest();
    request.onreadystatechange = function() {
        if (this.readyState == 4) {
			if (this.status == 200) {
				var result = JSON.parse(this.responseText);
				if (result[1] != undefined || result[1] != null) {
					var row = result[1];
					highestScore = row[0];
				}
            }
            callback(highestScore, ctx);
		}
	};
	sendksqlDBQuery(request, ksqlQuery);

}


function getScoreboardJson(gameName,callback) {
	console.log('testing - getScoreboardJson!');

	//var userListCsv = userList.map(user_key => `STRUCT(USER:='${user_key.USER}',GAME_NAME:='${user_key.GAME_NAME}')`).join(',');

	ksqlQuery = `select USER_KEY->USER, HIGHEST_SCORE, HIGHEST_LEVEL, TOTAL_LOSSES from STATS_PER_USER WHERE GAME_NAME='${gameName}';`;

	const request = new XMLHttpRequest();
	request.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			var result = JSON.parse(this.responseText);
			if (result[1] == undefined || result[1] == null) {
				logger('Empty Scoreboard')
				return;
			}

			//First element is the header
			result.shift();
			var playersScores = result.map((item) => ({ user: item[0], score:item[1],level:item[2],losses:item[3] }));

			playersScores = playersScores.sort(function(a, b) {
				var res=0

				if (a.score > b.score) res = 1;
				if (b.score > a.score) res = -1;
				if (a.score == b.score){
					if (a.level > b.level) res = 1;
					if (b.level > a.level) res = -1;
					if (a.level == b.level){
						if (a.losses < b.losses) res = 1;
						if (b.losses > a.losses) res = -1;
					}
				}
				return res * -1;
			});;
			callback(playersScores);
		}
	};

	sendksqlDBQuery(request, ksqlQuery);

}


function sendksqlDBStmt(request, ksqlQuery){
	console.log('testing - sendksqlDBStmt!');

	var query = {};
	query.ksql = ksqlQuery;
	query.endpoint = "ksql";
	request.open('POST', KSQLDB_QUERY_API, true);
	request.setRequestHeader('Accept', 'application/json');
	request.setRequestHeader('Content-Type', 'application/json');
	request.send(JSON.stringify(query));
}

async function sendksqlDBQuery(request, ksqlQuery){
	console.log('testing - sendksqlDBQuery!');

	var query = {};
	query.sql = ksqlQuery;
	query.endpoint = "query-stream";
	request.open('POST', KSQLDB_QUERY_API, true);
	request.setRequestHeader('Accept', 'application/json');
	request.setRequestHeader('Content-Type', 'application/json');
	request.send(JSON.stringify(query));


	// For the full code sample see here: https://github.com/ably/quickstart-js

}


function sendUpdateToAbly(channel, data){
	console.log(data);
	channel.publish('data', data);
}
