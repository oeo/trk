# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
log = (x...) -> try console.log x...
lp = (x) -> log JSON.stringify(x,null,2)

_ = require('wegweg')({
  globals: off
})

require 'date-utils'

async = require 'async'
minimatch = require 'minimatch'

Members = require 'taky-redis-members'

ident = require './lib/redis-ident'

module.exports = class Metrics

  constructor: (opt={}) ->

    # define storage instances
    @redis = opt.redis ? opt.client ? _.redis()
    @memcached = opt.memcached ? opt.memcached ? _.memcached()

    @key = opt.key ? opt.prefix ? 'metrics'

    @members_keys = new Members {
      redis: @redis
      prefix: @key + ':k'
    }

    @map = {
      bmp: []
      add: []
      addv: []
      top: []
    }

    if opt.map
      @map[k] = v for k,v of opt.map

  # record an event using the metrics utility, perform redis
  # operations according to the constructed map configuration
  record: (event,cb) ->
    dkey = @key + ':' + (today = _.today())

    obj = _.clone event

    for x of obj
      for y of obj
        if x != y and !x.match(/\~/) and !y.match(/\~/)
          cat = [x,y].sort()
          key = cat.join('~')
          if not obj[key]
            obj[key] = obj[cat[0]] + '~' + obj[cat[1]]

    # function container
    arr = []

    # key membership queue
    keys_queue = []

    m = @redis.multi()

    if @map.bmp?.length
      for x in @map.bmp
        if x.match(/\~/)
          x = x.split(/\~/).sort().join('~')

        if obj[x]
          do (x) =>
            bmp_id = ident @redis, dkey + ':bmp:i:' + x
            bmp_key = dkey + ':bmp:' + x

            keys_queue.push bmp_key = dkey + ':bmp:' + x

            fns = [
              (c) => bmp_id obj[x], (e,id) -> c null, id
              (i,c) => @redis.setbit bmp_key, i, 1, (e,r) -> c null, r
            ]

            arr.push((c) -> async.waterfall fns, (e,r) -> c null, r)

            ###
            # hyperloglog implementation; no noticable performance benefit
            arr.push ((c) =>
              @redis.send_command 'pfadd', [bmp_key,obj[x]], c
            )
            ###

    if @map.add?.length
      for x in @map.add
        if x.match(/\~/)
          x = x.split(/\~/).sort().join('~')

        if obj[x]
          do (x) =>
            add_key = dkey + ':add:' + x

            keys_queue.push add_key

            m.hincrby add_key, obj[x], 1

    if @map.top?.length
      for x in @map.top
        if x.match(/\~/)
          x = x.split(/\~/).sort().join('~')

        if obj[x]
          do (x) =>
            set_key = dkey + ':top:' + x

            keys_queue.push set_key

            m.zincrby set_key, 1, obj[x]

    if @map.addv?.length
      for x in @map.addv
        if _.type(x) is 'object'
          label_key = x.key
          value_key = x.value ? x.val
        else
          label_key = x
          value_key = x

        if label_key.match(/\~/)
          label_key = label_key.split(/\~/).sort().join('~')

        if obj[label_key] and obj[value_key] and !isNaN(obj[value_key])

          do (label_key,value_key) =>
            add_key = dkey + ':addv:' + value_key + ':' + label_key
            tot_key = dkey + ':addv:' + value_key + ':' + 'i'

            keys_queue.push add_key
            keys_queue.push tot_key

            if label_key isnt value_key
              m.hincrby add_key, obj[label_key], pi(obj[value_key])

            m.hincrby tot_key, 'sum', pi(obj[value_key])
            m.hincrby tot_key, 'count', 1

    # write key members for the current day
    arr.push (c) =>
      @members_keys.add today, keys_queue, c

    # perform redis operations
    arr.push (c) ->
      m.exec (e,r) ->
        c null, r

    await _.par arr, defer e,r

    cb null, r if cb

  # primary query-style, unix_min, unix_max
  query: (min,max,opt,cb) ->
    if !cb and _.type(opt) is 'function'
      cb = opt
      opt = {}

    dkey = @key + ':' + _.today()

    if !cb
      cb = max
      max = min

    min_date = new Date min * 1000
    max_date = new Date max * 1000
    min_date.clearTime()
    max_date.clearTime()

    num_days = min_date.getDaysBetween max_date

    prefix = @key

    ret = {}
    arr = []

    all_days = []

    while max_date >= min_date
      do =>

        day = min_date.clone()
        day.clearTime()

        unix = Math.round day.getTime()/1000

        # get key memberships for this day
        arr.push (c) =>
          @members_keys.list unix, c

        all_days.push unix

        ret[unix] =
          date: day.toFormat 'MM/DD/YYYY'
          result: []

        min_date.addDays 1

    await _.par arr, defer e,r

    if !r?.length
      return cb null, ret

    jobs = @_jobs r
    fns = {}

    job_keys = []
    blacklist = []

    for k,v of jobs
      for path,func of v
        job_keys.push path

    # ignore/accept glob-style path matching
    opt.ignore ?= []
    opt.accept ?= (opt.allow ? [])

    if opt.ignore
      opt.ignore = [opt.ignore] if _.type(opt.ignore) is 'string'
      opt.ignore = opt.ignore

    if opt.accept
      opt.accept = [opt.accept] if _.type(opt.accept) is 'string'
      opt.accept = opt.accept

    if opt.ignore.length
      for x in job_keys
        raw = x.substr(@key.length + 1)

        parts = raw.split ':'
        parts.shift()

        raw = parts.join ':'

        for pattern in opt.ignore
          blacklist.push(x) if minimatch(raw,pattern)

    if opt.accept.length
      for x in job_keys
        continue if x in blacklist

        raw = x.substr(@key.length + 1)

        parts = raw.split ':'
        parts.shift()

        raw = parts.join ':'

        valid = no

        for pattern in opt.accept
          if minimatch(raw,pattern)
            valid = yes
            break

        blacklist.push x if !valid

    # return here if we only want the jobs back
    if opt.return_jobs
      if blacklist.length
        return cb null, (_.difference job_keys,blacklist)
      else
        return cb null, job_keys

    for k,v of jobs
      do (k,v) ->

        # delete job if the key is in our blacklist
        if blacklist.length
          for k2,v2 of v
            delete v[k2] if k2 in blacklist

        if opt.ignore_jobs
          for x in opt.ignore_jobs
            return if k.includes(x)

        fns[k] = ((c) ->
          _.series v, c
        )

    await _.par fns, defer e2,r2

    if e2 or !_.size(r2)
      return cb null, ret

    for type,results of r2
      do (results) ->
        for location,item of results
          do (item) ->
            return if !ret[item.day]
            item.key = location.split(':').pop().split '~'
            ret[item.day].result.push item

    return cb null, (@_format ret,no)

  # alternative query-style, days relative to today
  query_days: (num_days,cb) ->
    max_date = new Date
    min_date = new Date

    if num_days > 0 then num_days *= -1
    ++ num_days

    min_date.add days:num_days

    min = Math.round min_date.getTime()/1000
    max = Math.round max_date.getTime()/1000

    @query min, max, cb

  _query_keys: (keys,cb) ->
    start = new Date

    min = no
    max = no

    for x in keys
      do (x) ->
        time = x.split(':')[1]
        if !min or time < min then min = time
        if !max or time > max then max = time

    range = [min..max]
    days = (x for x in range by (3600 * 24)).reverse()

    fns = @_jobs keys
    afns = {}

    for k,v of fns
      do (k,v) ->

        afns[k] = (c) ->
          _.par fns[k], (e,r) ->
            c e, r

    _.par afns, (e,r) ->
      out = {
        days: {}
        min: min
        max: max
        elapsed: "#{new Date() - start}ms"
      }

      if _.keys(r).length
        for k,v of r
          do (k,v) =>
            for key,stats of v
              do (key,stats) =>

                if !out.days[stats.day]
                  out.days[stats.day] = {}

                if !out.days[stats.day][stats.type]
                  out.days[stats.day][stats.type] = {}

                map_key = stats.location.split /:/
                map_key = map_key.slice -1

                out.days[stats.day][stats.type][map_key] = stats

      for x in days
        do (x) ->
          if !out.days[x] then out.days[x] = {}
          out.days[x].date = new Date(x * 1000).toFormat 'MM/DD/YYYY'

      cb null, out

  # creates an object filled with functions for async to execute
  # based on the type of redis key for each item
  _jobs: (keys) ->
    fns =
      add: {}
      top: {}
      bmp: {}
      addv: {}

    keys = _.uniq _.flatten keys

    for y in keys
      do (y) =>

        # fix for keys with colons
        if @key.includes(':')
          y = y.split(@key).join('_tmp_')

        [key,time,type...,fields] = y.split /:/

        # fix for keys with colons
        if y.includes('_tmp_')
          y = y.split('_tmp_').join @key

        if _.first(type) is 'addv'
          type = ['addv']

        return if type.length is 2

        job =
          day: time
          type: type.shift()
          location: y
          cache_key: "_cache:#{y}"

        do_cache = no
        do_cache = yes if job.day < _.today()

        if job.type is 'add'
          fns.add[job.location] = (c) =>
            if do_cache
              await @memcached.get job.cache_key, defer e,cache_r
              if cache_r then return c null, cache_r

            @redis.hgetall job.location, (e,r) =>
              job.result = r

              await @memcached.set job.cache_key, job, 0, defer() if do_cache

              c null, job

        if job.type is 'addv'
          fns.add[job.location] = (c) =>
            if do_cache
              await @memcached.get job.cache_key, defer e,cache_r
              if cache_r then return c null, cache_r

            @redis.hgetall job.location, (e,r) =>
              job.result = r

              await @memcached.set job.cache_key, job, 0, defer() if do_cache

              c null, job

        else if job.type is 'bmp'
          fns.bmp[job.location] = (c) =>
            if do_cache
              await @memcached.get job.cache_key, defer e,cache_r
              if cache_r then return c null, cache_r

            @redis.bitcount job.location, (e,r) =>
              job.result = r

              await @memcached.set job.cache_key, job, 0, defer() if do_cache

              c null, job

        else if job.type is 'top'
          fns.top[job.location] = (c) =>

            if do_cache
              await @memcached.get job.cache_key, defer e,cache_r
              if cache_r then return c null, cache_r

            args = [
              job.location
              '+inf'
              '-inf'
              'WITHSCORES'
              'LIMIT'
              0
              250
            ]

            @redis.zrevrangebyscore args, (e,r) =>
              ret = {}

              if r?.length
                last = null

                i = 0; for z in r
                  do (z) =>
                    ++i; if i % 2
                      ret[z] = null
                      last = z
                    else
                      ret[last] = parseInt z

              job.result = ret

              await @memcached.set job.cache_key, job, 0, defer() if do_cache

              c null, job
    return fns

  # output formatting, creates and attached a filter function to easily
  # sort the result object data for reporting use
  _format: (obj,cached) ->
    merge_numeric = ((uno,dos) ->
      return dos if !uno and dos
      return uno if uno and !dos

      for k,v of dos
        uno[k] ?= 0
        uno[k] += (+v)

      return uno
    )

    output =
      days: obj
      cache: (if cached then 'hit' else 'miss')
      find: (o) ->
        opt = {
          type: null
          key: null
          day: no
          merge: no
        }

        if typeof o is 'object'
          if o.keys and !o.key
            o.key = o.keys
            delete o.keys
          opt = _.merge o
        else
          parts = o.split '/'
          opt.type = parts.shift()
          opt.key = parts.shift()
          if parts.length
            opt.day = parts.shift()

        opt.key = opt.key.split('~').sort().join '~'

        if opt.day
          if !obj[opt.day]?.result?
            return null

          for v in obj[opt.day].result
            if v.type is opt.type
              if v.location.substr((opt.key.length + 1) * -1) is ":#{opt.key}"
                return v.result

          return null

        else
          ret = {}

          for unix,item of obj
            if opt.type is 'bmp'
              val = 0
            else if opt.type in ['top','add']
              val = {}
            else if opt.type is 'addv'
              val = {}
            ret[item.date] = val

            continue if !item?.result?.length

            for v in item.result
              if v.type is opt.type
                if v.location.substr((opt.key.length + 1) * -1) is ":#{opt.key}"
                  ret[item.date] = v.result

          if opt.merge
            tot = {}
            arr = _.vals ret
            for x in arr
              do (x) ->
                tot = merge_numeric tot, x
            tot
          else
            ret

##
if !module.parent
  log /DEVEL/
  process.exit 0

