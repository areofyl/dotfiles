local fm = require('plugins/vis-fm')
require('plugins/vis-autoclose')
require('plugins/complete-filename')

local colorizer = require('plugins/vis-colorizer')
colorizer.three = true
colorizer.six = true

-- LSP is installed but intentionally disabled.
-- require('plugins/vis-lspc')

return { fm = fm }
