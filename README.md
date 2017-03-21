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

# key concepts
- events are recorded as objects (`.record()`), the only requirement is it has an
  `event` property
- redis counters are modified on the fly into different areas as events come in
- the time granularity supported is _daily_
- there are 4 types of configurable properties for recording events
  1. `bmp` _("bitmap")_ counts unique values occurrences for this key
  1. `add` counts number of occurrences for each value of this key
  1. `addv` _("add value")_ sum of the values for all occurrences of this key
  1. `top` similar to `add` but returns the top occurrence values in order and
     limits the result set to 250
- compound keys are supported by mapping them with a `~` delimiter
- an interface to query data over date ranges is supplied
  (`.query()`,`.query_days()`), see examples
- querying does not require a config and can be done from other
  machines, recording requires a map configuration

the data structure in redis ends up looks something like this

<p>
  <img src="https://taky.s3.amazonaws.com/21hnn3z4tgo5.png" width="982">
</p>

and for compound key combinations, if you choose to use them, like this

<p>
  <img src="https://taky.s3.amazonaws.com/21hnnmjuyg0i.png" width="1116">
</p>

# benefits
- recording an event is :zap: fast and can be done in a fire-and-forget fashion
- queries are :zap: fast and can be done in real-time with no need for caching in
  most cases

# limitations
- **no regression.** the raw event is never stored, it is broken down and digested
  into specific locations based on configuration and then is hair-flipped

# install

using [npm](https://npmjs.org)

```
npm i trk --save
```

# usage
examples are located in `src/examples`

# recording speed
`build/examples/record-events.iced` on a mbp i7(3.1)/16gb

```bash
$ node record-events.js
Finished recording 10000 events (series) in 7046ms
Series events digested/sec: 1419.244961680386
Finished recording 10000 events (parallel_limit) in 6449ms
Parallel events digested/sec: 1550.6280043417585
```

# inspiration
- [statsd](https://github.com/etsy/statsd)

# todo
- tests
- `map.bmp` elaboration (support compound fields)
- data inflation routine for compound key result sets
- winston implementation for debug logging

---

### License: MIT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
