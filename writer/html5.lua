-- Custom HTML 5 writer
-- Modified from the example to closer meet the standard

--
-- Copyright (C) 2006-2013 John MacFarlane <jgm at berkeley dot edu>
-- Copyright 2014 Alex Szczuczko
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

-- HTML 5 sectioning
local function html5section(body, add)

    local lineBuffer={}
    local lines = string.gmatch(body, "([^\n]*)\n?")

    local function process(level)
        -- Grab the first line
        local line = (table.remove(lineBuffer) or lines())
        -- For disabling indentation
        local noIndent = false
        -- Iterate until there are no more lines
        while line do
            -- Handle blank lines
            if string.match(line, "^ *$") then
                add(line)
            else
                -- Check for a header tag on this line
                local headerlevel = tonumber(string.match(line, "<h([1-6])"))
                if headerlevel then
                    if headerlevel <= level then
                        -- Pass the line up to parent (base case)
                        table.insert(lineBuffer, line)
                        return
                    else
                        if headerlevel > level + 1 then
                            -- Header order enforced: Must move up header levels one at a time
                            -- (h1->h2 ok), but can move down at any rate (h6->h1 ok)
                            error("HTML 5 sectioning error: headers should only increase one level at a time")
                        end

                        add('<section>', level)
                        add(line, headerlevel)
                        process(headerlevel)
                        add('</section>', level)
                    end
                else -- no header tag
                    if noIndent then
                        add(line)
                    else
                        add(line, level)
                    end

                    --Handle pre tags (no extra indentation inside)
                    if string.match(line, "<pre[^/]*>") then
                        noIndent = true
                    end
                    if string.match(line, "</pre") then
                        noIndent = false
                    end
                end
            end

            -- Grab the next line
            line = (table.remove(lineBuffer) or lines())
        end
    end

    process(1)
end

-- Character escaping
local function escape(s, in_attribute)
    return s:gsub("[<>&\"']",
    function(x)
        if x == '<' then
            return '&lt;'
        elseif x == '>' then
            return '&gt;'
        elseif x == '&' then
            return '&amp;'
        elseif x == '"' then
            return '&quot;'
        elseif x == "'" then
            return '&#39;'
        else
            return x
        end
    end)
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
    local attr_table = {}
    for x,y in pairs(attr) do
        if y and y ~= "" then
            table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
        end
    end
    return table.concat(attr_table)
end

-- Run cmd on a temporary file containing inp and return result.
local function pipe(cmd, inp)
    local tmp = os.tmpname()
    local tmph = io.open(tmp, "w")
    tmph:write(inp)
    tmph:close()
    local outh = io.popen(cmd .. " " .. tmp,"r")
    local result = outh:read("*all")
    outh:close()
    os.remove(tmp)
    return result
end

-- Run cmd with arguments
local function exec(cmd, args)
    local args_concat = table.concat(args, " ")
    local file = io.popen(cmd .. " " ..  args_concat, "r")
    local result = {}
    for line in file:lines() do
        table.insert(result, line)
    end
    file:close()
    return result
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
    return "\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- One could use some kind of templating
-- system here; this just gives you a simple standalone HTML file.
function Doc(body, metadata, variables)
    local buffer = {}
    local function add(s, level)
        table.insert(buffer, string.rep('    ', (level or 0)) .. s)
    end
    -- https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/HTML5/HTML5_element_list
    add('<!DOCTYPE html>')
    add('<html lang="en">')
    add('<head>')
    add('<meta charset="utf-8" />')
    add('<title>' .. (metadata['title'] or '') .. '</title>')
    add('<link rel="stylesheet" href="/css/sitewide.css" type="text/css" />')
    add('</head>')
    add('<body>')
    -- http://www.w3.org/html/wg/drafts/html/master/common-idioms.html
    add('<article>')
    if metadata['title'] and metadata['title'] ~= "" then
        add('<h1>' .. metadata['title'] .. '</h1>', 1)
    end
    if metadata['author'] and metadata['author'] ~= {} then
        add('<address>', 1)
        add('<ul>', 2)
        for _, author in pairs(metadata['author'] or {}) do
            add('<li><a rel="author">' .. author .. '</a></li>', 3)
        end
        add('</ul>', 2)
        add('</address>', 1)
    end
    if metadata['date'] and metadata['date'] ~= "" then
        -- Get ISO 8601 format
        local iso8601 = exec("date", {"--iso-8601=minutes", "-d '" .. metadata.date .. "'"})
        -- Get RFC 3339 format (html's datetime preference?)
        local rfc3339 = exec("date", {"--rfc-3339=seconds", "-d '" .. metadata.date .. "'"})
        add('<time datetime="' .. rfc3339[1] .. '">' .. iso8601[1] .. '</time>', 1)
    end
    -- Process the body to do indentation and section tags
    html5section(body, add)
    if #notes > 0 then
        add('<section>', 1)
        for _,note in pairs(notes) do
            add(note, 2)
        end
        add('</section>', 1)
    end
    add('</article>')
    add('</body>')
    add('</html>')
    return table.concat(buffer,'\n')
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
    return escape(s)
end

function Space()
    return " "
end

function LineBreak()
    return "<br />"
end

function Emph(s)
    return "<em>" .. s .. "</em>"
end

function Strong(s)
    return "<strong>" .. s .. "</strong>"
end

function Subscript(s)
    return "<sub>" .. s .. "</sub>"
end

function Superscript(s)
    return "<sup>" .. s .. "</sup>"
end

function SmallCaps(s)
    return '<span style="font-variant: small-caps;">' .. s .. '</span>' -- TODO
end

function Strikeout(s)
    return '<del>' .. s .. '</del>'
end

function Link(s, src, tit)
    return "<a href='" .. escape(src,true) .. "' title='" .. escape(tit,true) .. "'>" .. s .. "</a>"
end

function Image(s, src, tit)
    return "<img src='" .. escape(src,true) .. "' title='" .. escape(tit,true) .. "'/>"
end

function Code(s, attr)
    return "<code" .. attributes(attr) .. ">" .. escape(s) .. "</code>"
end

function InlineMath(s)
    return "\\(" .. escape(s) .. "\\)" -- TODO
end

function DisplayMath(s)
    return "\\[" .. escape(s) .. "\\]" -- TODO
end

function Note(s)
    local num = #notes + 1
    -- Remove tags
    s = string.gsub(s, '</?[a-z]*>', '')
    -- add a list item with the note to the note table.
    table.insert(notes, '<p id="fn' .. num .. '">' .. s .. ' <a href="#fnref' .. num ..  '">[' .. num .. ']</a></p>')
    -- return the footnote reference, linked to the note.
    return '<sup><a id="fnref' .. num .. '" href="#fn' .. num .. '">' .. num .. '</a></sup>'
end

function Span(s, attr)
    return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
end

function Cite(s)
    return "<cite>" .. s .. "</cite>"
end

function Plain(s)
    return s
end

function Para(s)
    return "<p>" .. s .. "</p>"
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
    return "<h" .. lev .. attributes(attr) ..  ">" .. s .. "</h" .. lev .. ">"
end

function BlockQuote(s)
    return "<blockquote>\n" .. s .. "\n</blockquote>"
end

function HorizontalRule()
    return "<hr />"
end

function CodeBlock(s, attr) -- TODO
    -- If code block has class 'dot', pipe the contents through dot
    -- and base64, and include the base64-encoded png as a data: URL.
    if attr.class and string.match(' ' .. attr.class .. ' ',' dot ') then
        local png = pipe("base64", pipe("dot -Tpng", s))
        return '<img src="data:image/png;base64,' .. png .. '"/>'
        -- otherwise treat as code (one could pipe through a highlighter)
    else
        return "<code" .. attributes(attr) .. "><pre>" .. escape(s) ..
        "</pre></code>"
    end
end

function BulletList(items)
    local buffer = {}
    for _, item in pairs(items) do
        table.insert(buffer, "    <li>" .. item .. "</li>")
    end
    return "<ul>\n" .. table.concat(buffer, "\n") .. "\n</ul>"
end

function OrderedList(items)
    local buffer = {}
    for _, item in pairs(items) do
        table.insert(buffer, "    <li>" .. item .. "</li>")
    end
    return "<ol>\n" .. table.concat(buffer, "\n") .. "\n</ol>"
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
    local buffer = {}
    for _,item in pairs(items) do
        for k, v in pairs(item) do
            table.insert(buffer,"    <dt>" .. k .. "</dt>\n    <dd>" .. table.concat(v,"</dd>\n    <dd>") .. "</dd>")
        end
    end
    return "<dl>\n" .. table.concat(buffer, "\n") .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
    if align == 'AlignLeft' then
        return 'left'
    elseif align == 'AlignRight' then
        return 'right'
    elseif align == 'AlignCenter' then
        return 'center'
    else
        return 'left'
    end
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
    local buffer = {}
    local function add(s)
        table.insert(buffer, s)
    end
    add("<table>")
    if caption ~= "" then
        add("<caption>" .. caption .. "</caption>")
    end
    if widths and widths[1] ~= 0 then
        for _, w in pairs(widths) do
            add('<col width="' .. string.format("%d%%", w * 100) .. '" />')
        end
    end
    local header_row = {}
    local empty_header = true
    for i, h in pairs(headers) do
        local align = html_align(aligns[i])
        table.insert(header_row,'<th align="' .. align .. '">' .. h .. '</th>')
        empty_header = empty_header and h == ""
    end
    if empty_header then
        head = ""
    else
        add('<tr class="header">')
        for _,h in pairs(header_row) do
            add(h)
        end
        add('</tr>')
    end
    local class = "even"
    for _, row in pairs(rows) do
        class = (class == "even" and "odd") or "even"
        add('<tr class="' .. class .. '">')
        for i,c in pairs(row) do
            add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
        end
        add('</tr>')
    end
    add('</table')
    return table.concat(buffer,'\n')
end

function Div(s, attr)
    return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end

function RawInline(syntax, raw)
    return ""
end

function RawBlock(syntax, raw)
    return raw
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
end
setmetatable(_G, meta)

