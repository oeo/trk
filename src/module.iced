# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2
log = (x...) -> try console.log x...

_ = require('wegweg')({
  globals: no
  shelljs: no
})

module.exports = lib = {

}

##
if !module.parent
  log /DEVEL/
  process.exit 0

