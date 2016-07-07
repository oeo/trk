<p align="center">
  <img src="https://taky.s3.amazonaws.com/61hnjexonow4.png" width="250"><br>
  <i>regression is forbidden!</i>
</p>

# trk
`trk` is an event based stats library for node.js that uses redis as a data store.

depending on the project, it can either be a total replacement for map/reduce
routines, or, at the very least, a catalystic compliment that allows you to
strike a performant balance between real-time data and hierarchical time
bucket(y) reporting.

## key concepts
- events are recorded as objects, the only requirement is that they have an
  `event` property
- counters are modified on the fly into different areas as events come in
- the granularity supported is _daily_
- there are 4 types of recording configuration for events
  1. `bmp` _("bitmap")_ counts unique values occurrences for this key
  1. `add` counts number of occurrences for each value of this key
  1. `addv` _("add value")_ sum of the values for all occurrences of this key
  1. `top` similar to `add` but returns the top occurrence values in order
- an interface to query data the data over date ranges is supplied
  (`.query()`,`.query_days()`) (see examples)
- querying does not require a config and can be done from other
  machines, recording requires a map configuration

the data structure in redis ends up looks something like this

<p>
  <img src="https://taky.s3.amazonaws.com/41hnmlp4xkoq.png" width="982">
</p>

## benefits
- _recording events is fast_ and can be done in a fire-and-forget fashion
- _queries are fast_ and can be done in real-time with no need for caching in
  most cases

## limitations
- no regression; the raw event is never stored, it is broken down and digested
  into specific locations based on configuration and then is hair-flipped

## install

using [npm](https://npmjs.org)

```
npm i trk --save
```

## usage
examples located in `src/examples`

## recording speed
`build/examples/record-events.iced` on a mbp i7(3.1)/16gb

```bash
$ node record-events.js
Finished recording 10000 events (series) in 7046ms
Series events digested/sec: 1419.244961680386
Finished recording 10000 events (parallel_limit) in 6449ms
Parallel events digested/sec: 1550.6280043417585
```

---

#### inspiration
- [statsd](https://github.com/etsy/statsd)

#### @todo
- tests
- `map.bmp` elaboration (support compound fields)
- data inflation routine for compound key result sets


