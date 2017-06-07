# Description
#   A team leaderboard for keeping scores that are specific per room, with team urls
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#
# Commands:
#   hubot score for <team> - Display the scores for the <team>
#   hubot top <amount> - Display the <amount> top teams from the leaderboard, <amount> is optional and defaults to 10
#   hubot bottom <amount> - Display the <amount> bottom teams from the leaderboard, <amount> is optional and defaults to 10
#
# Notes:
#
# Author:
#   xm-craig <cgulliver@xmatters.com>

_           = require('underscore')
clark       = require('clark')
querystring = require('querystring')

class ScoreKeeper
  constructor: (@robot) ->
    @cache =
      scoreLog: {}
      teamUrls: {}
      scores: {}
      ranks: {}
      prevRanks: {}

    if typeof @robot.brain.data == "object"
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.teamUrls ||= {}
      @robot.brain.data.ranks ||= {}
      @robot.brain.data.prevRanks ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog
      @cache.teamUrls = @robot.brain.data.teamUrls
      @cache.ranks = @robot.brain.data.ranks
      @cache.prevRanks = @robot.brain.data.prevRanks

    @robot.brain.on 'loaded', =>
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.teamUrls ||= {}
      @robot.brain.data.ranks ||= {}
      @robot.brain.data.prevRanks ||= {}
      @cache.scores = @robot.brain.data.scores
      @cache.scoreLog = @robot.brain.data.scoreLog
      @cache.teamUrls = @robot.brain.data.teamUrls
      @cache.ranks = @robot.brain.data.ranks
      @cache.prevRanks = @robot.brain.data.prevRanks

  getTeam: (team, room) ->
    unless typeof @cache.scores[room] == "object"
      @cache.scores[room] = {}
    unless typeof @cache.teamUrls[room] == "object"
      @cache.teamUrls[room] = {}
    unless typeof @cache.ranks[room] == "object"
      @cache.ranks[room] = {}
    unless typeof @cache.prevRanks[room] == "object"
      @cache.prevRanks[room] = {}

    @cache.scores[room][team] ||= 0
    @cache.ranks[room][team] ||= -1
    @cache.prevRanks[room][team] ||= -1
    @cache.teamUrls[room][team] ||= "EMPTY"
    team

  save: (room) ->
    @robot.brain.data.scores[room] = @cache.scores[room]
    @robot.brain.data.scoreLog[room] = @cache.scoreLog[room]
    @robot.brain.data.teamUrls[room] = @cache.teamUrls[room]
    @robot.brain.data.prevRanks[room] = @cache.prevRanks[room]
    @robot.brain.data.ranks[room] = @cache.ranks[room]
    @robot.brain.emit('save', @robot.brain.data)

  saveTeam: (team, room) ->
    @saveScoreLog(team, room)
    @save(room)
    @cache.scores[room][team]

  removeTeam: (team, room) ->
    if typeof @cache.scores[room] == "object"
      delete @cache.scores[room][team]
      delete @cache.teamUrls[room][team]
      if (@cache.scoreLog[room][team])
          delete @cache.scoreLog[room][team]
      @save(room)

  addTeam: (team, room, url) ->
    if @validate(team, room)
      team = @getTeam(team, room)
      @setTeamUrl(url, team, room)
      @save(team, room)
      @cache.scores[room][team]

  win: (team, room, points) ->
    if @exists(team, room) && !@isSpam(team, room)
      team = @getTeam(team, room)
      @cache.scores[room][team] = @cache.scores[room][team] + points;
      @saveTeam(team, room)

  loss: (team, room, points) ->
    if @exists(team, room) && !@isSpam(team, room)
      team = @getTeam(team, room)
      @cache.scores[room][team] = @cache.scores[room][team] - points;
      @saveTeam(team, room)

  scoreForTeam: (team, room) -> 
    team = @getTeam(team, room)
    @cache.scores[room][team]

  saveScoreLog: (team, room) ->
    unless typeof @cache.scoreLog[room] == "object"
      @cache.scoreLog[room] = {}
    @cache.scoreLog[room][team] = new Date()

  setTeamUrl: (url, team, room) ->
    unless typeof @cache.teamUrls[room] == "object"
      @cache.teamUrls[room] = {}
    @cache.teamUrls[room][team] = url

  setRank: (rank, team, room) ->
    unless typeof @cache.ranks[room] == "object"
      @cache.ranks[room] = {}

    if @cache.ranks[room][team] > -1
      @cache.prevRanks[room][team] = @cache.ranks[room][team]
    @cache.ranks[room][team] = rank

  isSpam: (team, room) ->
    @cache.scoreLog[room] ||= {}

    if !@cache.scoreLog[room][team]
      return false

    dateSubmitted = @cache.scoreLog[room][team]

    date = new Date(dateSubmitted)
    messageIsSpam = date.setSeconds(date.getSeconds() + 30) > new Date()

    # this makes no sense
    #if !messageIsSpam
    #  delete @cache.scoreLog[room][team] #clean it up

    messageIsSpam

  exists: (team, room) ->
    @cache.teamUrls[room] ||= {}
    if !@cache.teamUrls[room][team]
      return false
    @validate(team, room)

  validate: (team, room) ->
    team != room && team != ""

  length: () ->
    @cache.scoreLog.length

  registrationCount: (room) ->
    unless typeof @cache.scores[room] == "object"
      return 0
    _.size(@cache.scores[room])

  registrations: (room) ->
    regs = []
    for name, score of @cache.scores[room]
      regs.push(name: name, score: score, url: @cache.teamUrls[room][name], rank: @cache.ranks[room][name])
    _.sortBy( regs, 'name' )

  top: (amount, room) ->
    tops = []

    for name, score of @cache.scores[room]
      tops.push(name: name, score: score)

    tops.sort((a,b) -> b.score - a.score).slice(0,amount)

  bottom: (amount, room) ->
    all = @top(@cache.scores[room].length, room)
    all.sort((a,b) -> b.score - a.score).reverse().slice(0,amount)

module.exports = (robot) ->
  scoreKeeper = new ScoreKeeper(robot)
  reasonsKeyword = process.env.HUBOT_LEADERBOARD_REASONS or 'raisins'

  robot.respond /register (.+)?(\sfor\s)+(http.*\.com)+/i, (msg) ->
    name = msg.match[1].trim().toLowerCase()
    room = msg.message.room || 'escape'
    url = msg.match[3].trim()

    scoreKeeper.addTeam(name, room, url)
    msg.send "Your team #{name} has been registered for #{url}."

  robot.respond /register (.+)/i, (msg) ->
    name = msg.match[1].trim().toLowerCase()
    room = msg.message.room || 'escape'

    scoreKeeper.addTeam(name, room, "no url")
    msg.send "Your team #{name} has been registered."

  robot.respond /add (\d+) (points\s)+?(for\s)+?(.+)/i, (msg) ->
    points = parseInt(msg.match[1])
    name = msg.match[4].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.win(name, room, points)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /minus (\d+) (points\s)+?(for\s)+?(.+)/i, (msg) ->
    points = parseInt(msg.match[1])
    name = msg.match[4].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.loss(name, room, points)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /win (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.win(name, room, 1)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /loss (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    newScore = scoreKeeper.loss(name, room, 1)

    if newScore? then msg.send "Team #{name} has #{newScore} points."

  robot.respond /score (for\s)+?(.+)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    room = msg.message.room || 'escape'
    score = scoreKeeper.scoreForTeam(name, room)

    msg.send "Team #{name} has #{score} points."

  robot.respond /(top|bottom)(\s*)?(\d*)/i, (msg) ->
    amount = parseInt(msg.match[3]) || 10
    room = msg.message.room || 'escape'
    message = []

    console.log("FETCHING TOP for: " + room);

    if scoreKeeper.registrationCount(room) > 0
      tops = scoreKeeper[msg.match[1]](amount, room)

      for i in [0..tops.length-1]
        message.push("#{i+1}. #{tops[i].name} : #{tops[i].score} ")

      if(msg.match[1] == "top")
        graphSize = Math.min(tops.length, Math.min(amount, 20))
        message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")


  robot.respond /rank/i, (msg) ->
    room = msg.message.room || 'escape'
    message = []

    console.log("RANKING: " + room);

    if scoreKeeper.registrationCount(room) > 0
      tops = scoreKeeper.top(25, room)

      for i in [0..tops.length-1]
        scoreKeeper.setRank(i, tops[i].name, room)
      message.push("Ranks have been set.")
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")


  robot.respond /list/i, (msg) ->
    room = msg.message.room || 'escape'
    message = []

    if scoreKeeper.registrationCount(room) > 0
      regs = scoreKeeper.registrations(room)
      for i in [0..regs.length-1]
        message.push("#{i+1}. #{regs[i].name} : #{regs[i].url} : score #{regs[i].score} : rank #{regs[i].rank}  ")
    else
      message.push("No registrations yet.")

    msg.send message.join("\n")

  robot.respond /delete (.+)$/i, (msg) ->
    name = msg.match[1].trim().toLowerCase()
    room = msg.message.room || 'escape'

    if name
      scoreKeeper.removeTeam(name, room)
      msg.send "#{name} deleted from list"


  robot.router.get "/#{robot.name}/scores/:room", (req, res) ->
    room = req.params.room

    query = querystring.parse(req._parsedUrl.query)
    direction = query.direction || "top"
    amount = query.limit || 20

    tops = scoreKeeper[direction](amount, room)

    output = {};
    output.items = _.map(tops, (item) -> { label: item.name, value: item.score })

    console.log("FETCHING TOP: " + output);
    res.end JSON.stringify(output, null, 2)
