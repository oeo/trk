# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
_ = require('wegweg')({
  globals: on
})

cache = null

module.exports = (client,key) ->
  key = 'id-map' if !key

  script = """
    local identity = redis.call("ZSCORE", KEYS[1], ARGV[1])
    if not identity then
      identity = redis.call("ZCARD", KEYS[1])
      redis.call("ZADD", KEYS[1], identity, ARGV[1])
    end
    return identity
  """

  (id,cb) ->
    return cb new Error "`id` required" if !id

    eval_sha = ->
      client.evalsha [cache,1,key,id], (e,r) ->
        if e then return cb e
        cb null, parseInt(r,10)

    if !cache
      client.send_command 'SCRIPT', ['LOAD',script], (e,r) ->
        if e then return cb e
        cache = r
        eval_sha()
    else
      eval_sha()

##
if !module.parent
  log /DEVEL/
  process.exit 0

