# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
_ = require('wegweg')({
  globals: on
})

# create a new instance of trk
Trk = require './../module'

trk = new Trk {
  redis: _.redis()
  key: 'examples'
  map: {
    bmp: [
      'ip'
    ]
    add: [
      'event'
      'event~offer'
      'event~offer~creative'
      'event~offer~channel'
      'event~offer~s1'
      'event~offer~s2'
      'event~offer~s3'
      'event~offer~creative~s1'
      'event~offer~creative~s2'
      'event~offer~creative~s3'
    ]
    top: [
      'geo'
      'offer'
      'geo~offer'
      'offer~creative'
      'offer~host'
      'offer~ref'
    ]
  }
}

# subfunctions to generate random event properties
random_ip = (-> [_.rand(1,128),_.rand(0,255),_.rand(0,255),_.rand(0,255)].join('.'))
random_arr = (a) -> _.first(_.shuffle a)

events = [
  'offer_impression'
  'offer_impression'
  'offer_impression'
  'offer_click'
  'offer_conversion'
]

offers =[
  '526aa9fff3e8b600000000e5'
  '526aa9fff3e8b60000000002'
  '526aa9fff3e8b6000000000b'
  '526aa9fff3e8b6000000000b'
  '526aa9fff3e8b6000000000b'
]

creatives = ['c_0','c_1','c_2']

domains = [
  'aol.com'
  'google.com'
  'gmail.com'
  'hotmail.com'
  'example.com'
]

# store events in an array before recording so we don't pervert the recording
# elapsed duration
data = []

num_events = 10000

for x in [1..num_events]
  data.push {
    ip: random_ip()
    event: random_arr events
    geo: random_arr ['US','US','US','UK']
    chan: random_arr ['any','text','text']
    offer: random_arr offers
    creative: random_arr creatives
    ua: 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.94 Safari/537.36'
    host: random_arr domains
    ref_host: random_arr domains
  }

# "synchronous", record events one after the other
start = new Date

for event_obj in data
  await trk.record event_obj, defer e,r
  if e then throw e

log "Finished recording #{num_events} events (series) in #{elapsed = new Date - start}ms "
log "Series events digested/sec: #{num_events/(elapsed/1000)}"

# parallel, record X at a time
fns = []

for event_obj in data
  fns.push ((c) -> trk.record(event_obj,c))

start = new Date
await _.parl fns, 10, defer()

log "Finished recording #{num_events} events (parallel_limit) in #{elapsed = new Date - start}ms"
log "Parallel events digested/sec: #{num_events/(elapsed/1000)}"

##
process.exit 0

