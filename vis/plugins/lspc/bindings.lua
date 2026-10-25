-- Copyright (c) 2021 Florian Fischer. All rights reserved.
--
-- This file is part of vis-lspc.
--
-- vis-lspc is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later
-- version.
--
-- vis-lspc is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along with
-- vis-lspc found in the LICENSE file. If not, see <https://www.gnu.org/licenses/>.
--
-- vis-lspc default bindings
local lspc = ...

local function map(mode, key, action, help)
  vis:map(mode, key, function(...)
    if lspc.key_filter and not lspc.key_filter(mode, key) then return true end
    local win = vis.win
    if not win or not win.file or not win.file.path or not lspc.ls_map[win.syntax] then
      return
    end
    return action(...)
  end, help)
end

map(vis.modes.NORMAL, '<F2>', function()
  vis:command('lspc-start-server')
end, 'lspc: start lsp server')

map(vis.modes.NORMAL, '<F3>', function()
  vis:command('lspc-open')
end, 'lspc: open current file')

map(vis.modes.NORMAL, '<C-]>', function()
  vis:command('lspc-definition')
end, 'lspc: jump to definition')

map(vis.modes.NORMAL, '<C-t>', function()
  vis:command('lspc-back')
end, 'lspc: go back position stack')

map(vis.modes.NORMAL, '<C- >', function()
  vis:command('lspc-completion')
end, 'lspc: completion')

map(vis.modes.INSERT, '<C- >', function()
  vis:command('lspc-completion')
  vis.mode = vis.modes.INSERT
end, 'lspc: completion')

-- bindings inspired by nvim
-- https://github.com/neovim/nvim-lspconfig
map(vis.modes.NORMAL, 'gD', function()
  vis:command('lspc-declaration')
end, 'lspc: jump to declaration')

map(vis.modes.NORMAL, 'gd', function()
  vis:command('lspc-definition')
end, 'lspc: jump to definition')

map(vis.modes.NORMAL, 'gi', function()
  vis:command('lspc-implementation')
end, 'lspc: jump to implementation')

map(vis.modes.NORMAL, 'gr', function()
  vis:command('lspc-references')
end, 'lspc: show references')

map(vis.modes.NORMAL, ' D', function()
  vis:command('lspc-typeDefinition')
end, 'lspc: jump to type definition')

map(vis.modes.NORMAL, ' d', function()
  vis:command('lspc-show-diagnostics')
end, 'lspc: show diagnostic of current line')

map(vis.modes.NORMAL, ' n', function()
  vis:command('lspc-next-diagnostic')
end, 'lspc: jump to the next available diagnostic')

map(vis.modes.NORMAL, ' N', function()
  vis:command('lspc-prev-diagnostic')
end, 'lspc: jump to the previous available diagnostic')

map(vis.modes.NORMAL, 'K', function()
  vis:command('lspc-hover')
end, 'lspc: hover over current position')

map(vis.modes.NORMAL, '<C-K>', function()
  vis:command('lspc-signature-help')
end, 'lspc: signature help')

map(vis.modes.NORMAL, ' o', function()
  vis:command('lspc-navigate-symbols')
end, 'lspc: symbol navigation window')
