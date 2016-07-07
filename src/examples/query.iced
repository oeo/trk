# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
log = (x...) -> try console.log x...

_ = require('wegweg')({
  globals: off
})

Trk = require './../module'

trk = new Trk {
  redis: _.redis()
  key: 'examples'
}

###
# return stats from a single day (today)
trk.query _.today(), (e,r) -> log r

# return stats from today (relative-days style)
trk.query_days 1, (e,r) -> log r

# return stats from the last 10 days (min,max unix-style)
trk.query (_.today() - (3600 * 24 * 10)), _.today(), (e,r) -> log r

# return stats from the last 2 days
trk.query_days 2, (e,r) -> log r
###

# return stats from the last ten days
trk.query_days -10, (e,r) ->
  if e then throw e

  # get unique visitor counts
  unique = r.find {
    type: 'bmp'
    key: 'ip'
  }

  log unique

  ###
  { '12/01/2013': 0,
    '12/02/2013': 0,
    '12/03/2013': 5000,
    '12/04/2013': 0,
    '12/05/2013': 2500,
    '12/06/2013': 0,
    '12/07/2013': 0,
    '12/08/2013': 0,
    '12/09/2013': 0,
    '12/10/2013': 20000 }
  ###

  # get merged event counts for time duration of query
  impressions = r.find {
    type: 'add'
    key: 'event'
    merge: no
  }

  log impressions

  ###
  { offer_conversion: '3942',
    offer_impression: '12044',
    offer_click: '4014' }
  ###

  # get the top referring hostnames each day, ordered by frequency
  # argument is in alternative-shorthand syntax delimited by `/`
  # syntax: <type>/<keys>/[timestamp]
  top_geos = r.find 'top/geo'

  log top_geos

  ###
  { '06/28/2016': {},
  '06/29/2016': {},
  '06/30/2016': {},
  '07/01/2016': {},
  '07/02/2016': {},
  '07/03/2016': {},
  '07/04/2016': {},
  '07/05/2016': {},
  '07/06/2016': {},
  '07/07/2016': { US: 21107, UK: 7020 } }
  ###

  process.exit 0

