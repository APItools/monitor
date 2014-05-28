local PATH = (...):match("(.+%.)[^%.]+$") or ""
local Brain     = require(PATH .. 'brain')
local Host      = require(PATH .. 'host')
local Operation = require(PATH .. 'operation')
local Parameter = require(PATH .. 'parameter')

local autoswagger = {
  __VERSION     = 'autoswagger 0.5.0',
  __DESCRIPTION = 'Generate swagger specs from raw API traces in plain Lua',
  __URL         = 'https://github.com/kikito/autoswagger.lua',
  __LICENSE     = [[
    MIT LICENSE

    * Copyright (c) 2013 Enrique García Cota
    * Copyright (c) 2013 Raimon Grau

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
  Brain     = Brain,
  Host      = Host,
  Operation = Operation,
  Parameter = Parameter
}

return autoswagger
