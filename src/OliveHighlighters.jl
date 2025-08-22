"""
#### OliveHighlighters
- Created in March, 2025 by [chifi](https://github.com/orgs/ChifiSource)
- This software is MIT-licensed.

`OliveHighlighters` is a `ToolipsServables`-based highlighting system created 
primarily with the intention of serving the `Olive` parametric notebook 
editor. This package explicitly provides clean, in-line stylized output and 
declarative syntax in the hopes that this might make it easier for the future 
language and syntax specifications to be implemeneted within `Olive`.
Needless to say, this project turns out to also be useful in a variety of other 
contexts.

Usage revolves primarily around the `Highlighter` or `TextStyleModifier`. 
These are loaded with styles, and then sent through marking functions to 
create the highlighting system.
```example
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading, the styles will be saved -- we call `mark_julia!` instead of `julia_block!`.
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)

style!(tm, :sample, "color" => "red")

display("text/html", string(tm))
```
##### provides
- **Base**
- `TextModifier`
- `TextStyleModifier`
- `Highlighter`
- `classes`
- `remove!`
- `set_text!`
- `clear!`
- `style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...)`
- `style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) = push!(tm.styles, marks => sty)`
- `string(tm::TextStyleModifier; args ...)`
- **marking functions**
- `mark_all!(tm::TextModifier, s::String, label::Symbol)`
- `mark_all!(tm::TextModifier, c::Char, label::Symbol)`
- `mark_between!(tm::TextModifier, s::String, label::Symbol)`
- `mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)`
- `mark_before!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)`
- `mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_r::Int64 = 0,
    includedims_l::Int64 = 0)`
- `mark_inside!(f::Function, tm::TextModifier, label::Symbol)`
- `mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol)`
- `mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)`
- **included highlighters**
- `mark_julia!(tm::TextModifier)`
- `style_julia!(tm::TextStyleModifier)`
- `julia_block!(tm::TextStyleModifier)`
- `mark_markdown!(tm::OliveHighlighters.TextModifier)`
- `style_markdown!(tm::OliveHighlighters.TextStyleModifier)`
- `mark_toml!(tm::OliveHighlighters.TextModifier)`
- `style_toml!(tm::OliveHighlighters.TextStyleModifier)`
- **internal**
- `rep_str`
- `_grapheme_starts`
- `_bytepos_to_grapheme_index`
- `_byte_range_to_grapheme_range`
- `_grapheme_range_to_byte_range`
- `_is_offender`
"""
module OliveHighlighters
using ToolipsServables
using Unicode
import ToolipsServables: Modifier, String, AbstractComponent, set_text!, push!, style!, string, set_text!, remove!

const repeat_offenders = ('\n', ' ', ',', '(', ')', ';', '\"', ']', '[')

rep_str(s::String) = replace(s,
    " "  => "&nbsp;",
    "\n" => "<br>",
    "\\" => "&bsol;",
    "&#61;" => "=")

# ---------------------------
# Helper utilities for Unicode-safe indexing
# ---------------------------

# Return a vector of starting *byte* indices for each grapheme cluster in s.
# starts[i] is the byte index of the start of the i-th grapheme (1-based).
function _grapheme_starts(s::String)
    starts = Int[]
    i = firstindex(s)
    while i <= lastindex(s)
        push!(starts, i)
        i = nextind(s, i)
    end
    return starts
end

# Convert a byte position (index into the String) to a grapheme index (1-based)
# using the `starts` vector created above.
function _bytepos_to_grapheme_index(starts::Vector{Int}, bytepos::Int)
    # find last start <= bytepos
    idx = findlast(x -> x <= bytepos, starts)
    return isnothing(idx) ? 1 : idx
end

# Convert a UnitRange{Int} over *bytes* (as returned by findall) to
# a UnitRange{Int} over grapheme indices.
function _byte_range_to_grapheme_range(starts::Vector{Int}, r::UnitRange{Int})
    a = _bytepos_to_grapheme_index(starts, first(r))
    b = _bytepos_to_grapheme_index(starts, last(r))
    return a:b
end

# Convert a grapheme-range (a:b) to a byte-range in the original string
# using the starts vector.
function _grapheme_range_to_byte_range(starts::Vector{Int}, gr::UnitRange{Int}, s::String)
    if isempty(starts)
        return firstindex(s):lastindex(s)
    end
    start_byte = starts[first(gr)]
    # find the byte index after the last grapheme, then subtract 1
    if last(gr) < length(starts)
        end_byte = prevind(s, starts[last(gr) + 1])  # last byte of the grapheme
    else
        end_byte = lastindex(s)
    end
    return start_byte:end_byte
end

# Helper to check whether a grapheme string (like " " or "\n" etc.) is in repeat_offenders
function _is_offender(grapheme_str::AbstractString)
    for c in repeat_offenders
        if grapheme_str == string(c)
            return true
        end
    end
    return false
end

"""
```julia
abstract TextModifier <: ToolipsServables.Modifier
```
TextModifiers are modifiers that change outgoing text into different forms,
whether this be in servables or web-formatted strings. These are unique in that
they can be provided to `itmd` (`0.1.3`+) in order to create interpolated tmd
blocks, or just handle these things on their own.
```julia
# consistencies
raw::String
marks::Dict{UnitRange{Int64}, Symbol}
```
- See also: `TextStyleModifier`, `mark_all!`, `julia_block!`
"""
abstract type TextModifier <: Modifier end

"""
```julia
TextStyleModifier <: TextModifier
```
- raw**::String**
- taken**::Vector{Int64}**
- marks**::Dict{UnitRange{Int64}, Symbol}**
- styles**::Dict{Symbol, Vector{Pair{String, String}}}**

The `TextStyleModifier` is used to lex text and change its style. This `Modifier` is passed through a mutating function, for example 
`mark_all!`. `mark_all!` will mark all of the positions with the symbols we provide, then we use `ToolipsServables.style!(tm, ::Symbol, pairs ...)` to style 
those marks. These can be listed with `OliveHighlighters.classes` and removed with `ToolipsServables.remove!`. The `TextStyleModifier` is also aliased as 
`Highlighter`, and this type is exported whereas `TextStyleModifier` is not.

`OliveHighlighters` provides some pre-built highlighters:
- `mark_toml!`
- `toml_style!`
- `mark_markdown!`
- `markdown_style!`
- `style_julia!`
- `mark_julia!`
- `julia_block!` < combines highlight and mark for Julia.
The `TextStyleModifier`'s marks are cleared with `clear!`, but are also removed when the
text is set with `set_text!`. To get the final result, simply call 
`string` on the `TextStyleModifier`.
```julia
TextStyleModifier(::String = "")
```
example
```julia
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)
style!(tm, :sample, "color" => "red")
display("text/html", string(tm))
```
- See also: `classes`, `set_text!`, `julia_block!`, `mark_between!`
"""
mutable struct TextStyleModifier <: TextModifier
    raw::String
    taken::Vector{Int64}
    marks::Dict{UnitRange{Int64}, Symbol}
    styles::Dict{Symbol, Vector{Pair{String, String}}}
    function TextStyleModifier(raw::String = "")
        marks = Dict{UnitRange{Int64}, Symbol}()
        styles = Dict{Symbol, Vector{Pair{String, String}}}()
        new(ToolipsServables.rep_in(raw), Vector{Int64}(), marks, styles)
    end
end

const Highlighter = TextStyleModifier

"""
```julia
classes(tm::TextStyleModifier) -> Base.Generator
```
Returns a `Tuple` generator for the classes currently styled in the `TextStyleModifier`. This 
    is equivalent of getting the keys of the `styles` field. `remove!` can also be used to remove classes. 
    (To allocate the generator simply provide it to a `Vector`)
```julia
using OliveHighlighters; TextStyleModifier, style_julia!
tm = TextStyleModifier("")
style_julia!(tm)

classes(tm)

# allocated:
my_classes = [classes(tm) ...]
```
- See also: `set_text!`, `TextStyleModifier`, `clear!`, `remove!(tm::TextStyleModifier, key::Symbol)`
"""
classes(tm::TextStyleModifier) = (key for key in keys(tm.styles))

"""
```julia
remove!(tm::TextStyleModifier, key::Symbol)
```
Removes a given style string from a `TextStyleModifier`
```julia
using OliveHighlighters; TextStyleModifier, style_julia!
tm = TextStyleModifier("")
style_julia!(tm)

# check classes:
classes(tm)

# remove class:
remove!(tm, :default)
```
- See also: `set_text!`, `TextStyleModifier`, `clear!`
"""
remove!(tm::TextStyleModifier, key::Symbol) = delete!(tm.styles, key)

"""
- `OliveHighlighters` binding
```julia
set_text!(tm::TextStyleModifier, s::String) -> ::String
```
Sets the text of a `TextStyleModifier`. This is an extra-convenient function, 
it calls `rep_in` -- an internal function used to replace client-side characters -- and 
sets the result as the text of `TextStyleModifier`, then it makes a call to `clear!` to clear the 
current marks. This allows for the same highlighters with the same styles to be used with new text.
```julia
using OliveHighlighters
my_tm = Highlighter("function example() end")

OliveHighlighters.julia_block!(my_tm)

that_code = string(my_tm)

OliveHighlighters.set_text!(my_tm, "arg::Int64 = 5")

# julia_block! includes highlights, because we used `set_text!` we can remark the same highlighter:
OliveHighlighters.mark_julia!(my_tm)

new_code = string(my_tm)
```
- See also: `clear!`, `Highlighter`, `classes`
"""
set_text!(tm::TextModifier, s::String) = begin
    tm.raw = ToolipsServables.rep_in(s)
    clear!(tm)
    nothing::Nothing
end

"""
```julia
clear!(tm::TextStyleModifier) -> ::Nothing
```
`clear!` is used to remove the current set of `marks` from a `TextStyleModifier`. 
This will allow for new marks to be loaded with a fresh call to a marking function. This 
    function is automatically called by `set_text!`, so unless we want to clear the marks without 
    changing the text, that would be the more convenient function to call.
```julia
using OliveHighlighters
my_tm = Highlighter("function example() end")

OliveHighlighters.julia_block!(my_tm)

that_code = string(my_tm)

# avoiding `set_text!`
OliveHighlighters.clear!(my_tm)
my_tm.raw = "function sample()\\n x = 5 \\nend"

# julia_block! includes highlights, because we used `set_text!` we can remark the same highlighter:
OliveHighlighters.mark_julia!(my_tm)

new_code = string(my_tm)
```
- See also: `set_text!`, `style!`
"""
clear!(tm::TextStyleModifier) = begin
    tm.marks = Dict{UnitRange{Int64}, Symbol}()
    tm.taken = Vector{Int64}()
    nothing::Nothing
end

function push!(tm::TextStyleModifier, p::Pair{UnitRange{Int64}, Symbol})
    r = p[1]
    found = findfirst(mark -> mark in r, tm.taken)
    if isnothing(found)
        push!(tm.marks, p)
        vecp = Vector(p[1])
        tm.taken = vcat(tm.taken, vecp)
        return
    end
    nothing::Nothing
end

function push!(tm::TextStyleModifier, p::Pair{Int64, Symbol})
    if ~(p[1] in tm.taken)
        push!(tm.marks, p[1]:p[1] => p[2])
        push!(tm.taken, p[1])
    end
    nothing::Nothing
end

"""
```julia
style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...) -> ::Nothing
style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) -> ::Nothing
```
These `style!` bindings belong to `OliveHighlighters`.These will set the style for a particular class on a `TextStyleModifier` to `sty`.
```julia
using OliveHighlighters

sample_str = "[key]"

hl = Highlighter(sample_str)

style!(hl, :key, "color" => "blue")

mark_between!(hl, "[", "]", :key)

string(hl)
```
- See also: `mark_all!`, `string(::TextStyleModifier)`, `clear!`, `set_text!`
"""
function style!(tm::TextStyleModifier, marks::Symbol, sty::Pair{String, String} ...)
    style!(tm, marks, [sty ...])
end

style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}}) = push!(tm.styles, marks => sty)

"""
```julia
mark_all!(tm::TextModifier, ...) -> ::Nothing
```
`mark_all!` marks every instance of a certain sequence in `tm.raw` with the style provided in `label`.
```julia
# mark all (`String`)
mark_all!(tm::TextModifier, s::String, label::Symbol) -> ::Nothing
# mark all (`Char`)
mark_all!(tm::TextModifier, c::Char, label::Symbol) -> ::Nothing
```
```julia
using OliveHighlighters

sample_str = "function example end mutable struct end"

hl = Highlighter(sample_str)

style!(hl, :end, "color" => "darkred")

mark_all!(hl, "end", :end)

string(hl)
```
- See also: `mark_between!`, `mark_before!`, `mark_after!`
"""
function mark_all!(tm::TextModifier, s::String, label::Symbol)
    starts = _grapheme_starts(tm.raw)
    offender = raw"[^\p{L}\p{N}]"
    quoted = "\\Q" * s * "\\E"
    pattern = "(?:\\A|(?<=$offender))" * quoted * "(?:\\z|(?=$offender))"
    pat = Regex(pattern)

    for m in eachmatch(pat, tm.raw)
        byte_range = m.offset:(m.offset + ncodeunits(m.match) - 1)
        gr = _byte_range_to_grapheme_range(starts, byte_range)
        push!(tm, gr => label)
    end
    nothing
end

function mark_all!(tm::TextModifier, c::Char, label::Symbol; is_number_only::Bool=false)
	starts = _grapheme_starts(tm.raw)
	esc_c = "\\Q" * string(c) * "\\E"

	if is_number_only && isnumeric(c)
		pattern = "(?:\\A|(?<=[^\\p{L}]))" * esc_c * "(?:\\z|(?=[^\\p{L}]))"
		pat = Regex(pattern)
	else
		pat = Regex(esc_c)
	end

	for m in eachmatch(pat, tm.raw)
		byte_range = m.offset:(m.offset + ncodeunits(m.match) - 1)
		gr = _byte_range_to_grapheme_range(starts, byte_range)
		push!(tm, gr => label)
	end

	nothing::Nothing
end


"""
```julia
mark_between!(tm::TextModifier, s::String, ...) -> ::Nothing
```
`mark_between!` marks between the provided `String` or `String`s.
```julia
# mark between duplicates of the same character:
mark_between!(tm::TextModifier, s::String, label::Symbol)
# mark between two different characters
mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)
```
```julia
using OliveHighlighters

sample_str = "[key]"

hl = Highlighter(sample_str)

style!(hl, :key, "color" => "blue")

mark_between!(hl, "[", "]", :key)

string(hl)
```
- See also: `TextStyleModifier`, `mark_all!`, `julia_block!`, `clear!`
"""
function mark_between!(tm::TextModifier, s::String, label::Symbol)
    starts = _grapheme_starts(tm.raw)
    positions = findall(s, tm.raw)
    for pos in positions
        # find the next delim in positions that starts after this pos
        nd = findfirst(p -> first(p) > last(pos), positions)
        if nd !== nothing
            nd_pos = positions[nd]
            start_g = _byte_range_to_grapheme_range(starts, pos)
            end_g   = _byte_range_to_grapheme_range(starts, nd_pos)
            push!(tm, minimum(start_g):maximum(end_g) => label)
        else
            start_g = _byte_range_to_grapheme_range(starts, pos)
            push!(tm, minimum(start_g):length(_grapheme_starts(tm.raw)) => label)
        end
    end
    nothing::Nothing
end

function mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)
    starts = _grapheme_starts(tm.raw)
    positions = findall(s, tm.raw)
    positions2 = findall(s2, tm.raw)
    for pos in positions
        # find first occurrence in positions2 whose start > last(pos)
        nd_i = findfirst(p -> first(p) > last(pos), positions2)
        if nd_i !== nothing
            nd_pos = positions2[nd_i]
            start_g = _byte_range_to_grapheme_range(starts, pos)
            end_g   = _byte_range_to_grapheme_range(starts, nd_pos)
            push!(tm, minimum(start_g):maximum(end_g) => label)
        else
            start_g = _byte_range_to_grapheme_range(starts, pos)
            push!(tm, minimum(start_g):length(starts) => label)
        end
    end
    nothing::Nothing
end

"""
```julia
mark_before!(tm::TextModifier, s::String, label::Symbol; until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0, 
includedims_r::Int64 = 0) -> ::Nothing
```
`mark_before` will mark the values before a label -- a good example of this is a `Function`, we would `mark_before` the parenthesis, 
`until` a space or new line. `includedims` will include that number of characters before and after what you want to include -- for example, 
for a multi-line string we would set this to 3 (if we wanted to use `mark_before!` for that.) In most cases, this argument won't be used.
```julia
mark_julia!(tm::TextModifier) = begin
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)
    mark_line_after!(tm, "#", :comment)
    # strings + string interpolation
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    # functions

    mark_before!(tm, "(", :funcn, until = UNTILS)
    ...
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_before!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = repeat_offenders, includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)
    starts = _grapheme_starts(tm.raw)
    chars = collect(graphemes(tm.raw))
    positions = findall(s, tm.raw)
    until_positions = Dict{String, Vector{UnitRange{Int}}}()
    for d in until
        until_positions[d] = findall(d, tm.raw)
    end

    for labelrange_byte in positions
        # convert label byte range to grapheme
        label_gr = _byte_range_to_grapheme_range(starts, labelrange_byte)
        start_gr = first(label_gr)
        prev_positions = Int[]
        if !isempty(until)
            for d in until
                poslist = until_positions[d]
                if isempty(poslist)
                    push!(prev_positions, 1)
                    continue
                end
                # find last pos in poslist that ends before start of current label
                found_idx = findlast(p -> last(p) < first(labelrange_byte), poslist)
                if isnothing(found_idx)
                    push!(prev_positions, 1)
                else
                    found_byte_range = poslist[found_idx]
                    found_gr = _byte_range_to_grapheme_range(starts, found_byte_range)
                    # take the grapheme position after the matched until token
                    push!(prev_positions, maximum(found_gr) + 1)
                end
            end
            previous = maximum(prev_positions)
        else
            previous = 1
        end

        # clamp previous to at least 1
        previous = max(1, previous - includedims_l)

        pos = (previous):(maximum(label_gr) - 1 + includedims_r)
        if length(pos) == 0
            continue
        end
        push!(tm, pos => label)
    end

    return nothing
end

"""
```julia
mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_r::Int64 = 0,
    includedims_l::Int64 = 0) -> ::Nothing
```
Marks after `s` for every occurance of `s` in tm.raw. For example, for type annotations we could mark after `::` until 
    space or `\\n`. `includedims` will include that number of characters before and after what you want to include -- for example, 
for a multi-line string we would set this to 3 (if we wanted to use `mark_before!` for that.) In most cases, this argument won't be used.
```julia
# this is the function used to mark types in the Julia highlighter, for example:
mark_julia!(tm::TextModifier) = begin
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)
    mark_line_after!(tm, "#", :comment)
    # strings + string interpolation
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    # functions

    mark_before!(tm, "(", :funcn, until = UNTILS)
    # type annotations
    mark_after!(tm, "::", :type, until = UNTILS)
 #   ....
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)
    starts = _grapheme_starts(tm.raw)
    chars = collect(graphemes(tm.raw))
    positions = findall(s, tm.raw)
    until_positions = Dict{String, Vector{UnitRange{Int}}}()
    for d in until
        until_positions[d] = findall(d, tm.raw)
    end
    total_gr = length(starts)
    for labelrange_byte in positions
        label_gr = _byte_range_to_grapheme_range(starts, labelrange_byte)
        ending_gr = total_gr

        # if there is a plain-space terminator after label in byte-space:
        sp_byte = findnext(" ", tm.raw, last(labelrange_byte))
        if sp_byte === nothing
            ending_gr = total_gr
        else
            ending_gr = _bytepos_to_grapheme_index(starts, sp_byte[1])
        end
        if length(until) > 0
            lens = Int[]
            for d in until
                poslist = until_positions[d]
                cand_idx = findfirst(p -> first(p) > last(labelrange_byte), poslist)
                if ~(isnothing(cand_idx))
                    p = poslist[cand_idx]
                    # convert to grapheme and take start position - 1
                    pgr = _byte_range_to_grapheme_range(starts, p)
                    push!(lens, minimum(pgr) - 1)
                else
                    push!(lens, total_gr)
                end
            end
            ending_gr = minimum(lens)
        end
        pos = (minimum(label_gr) - includedims_l):(ending_gr - includedims_r)
        push!(tm, pos => label)
    end
    nothing::Nothing
end

"""
```julia
mark_inside!(f::Function, tm::TextModifier, label::Symbol) -> ::Nothing
```
For every occurance of `label`, we will open `f` and pass a new `TextStyleModifier` through it. 
This will highlight the inside of the label. In the Julia example, this is used to highlight 
the inside of string interpolators.
The new `TextStyleModifier` will be passed the styles from the provided `TextStyleModifier`.
```julia
# julia string interpolation highlighting:
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
```
- See also: mark_after!, clear!, `mark_for!`, `string(::TextStyleModifier)`, `julia_block!`
"""
function mark_inside!(f::Function, tm::TextModifier, label::Symbol)
    starts = _grapheme_starts(tm.raw)
    total = length(starts)
    keys_to_process = [k for (k,v) in tm.marks if v == label && length(k) > 0 && maximum(k) <= total]
    for key in keys_to_process
        # extract substring corresponding to the grapheme-range
        br = _grapheme_range_to_byte_range(starts, key, tm.raw)
        sub = tm.raw[br]
        new_tm = TextStyleModifier(sub)
        new_tm.styles = tm.styles
        f(new_tm)
        base_pos = minimum(key)
        kmax = maximum(key)
        converted = Vector{Pair{UnitRange{Int64}, Symbol}}()
        for (r, lbl) in new_tm.marks
            new_r = (minimum(r) + base_pos - 1):(maximum(r) + base_pos - 1)
            push!(converted, new_r => lbl)
        end
        sorted_c = sort(converted, by = x -> x[1])
        cursor = base_pos
        final_marks = Vector{Pair{UnitRange{Int64}, Symbol}}()
        for p in sorted_c
            r = p[1]; lbl = p[2]
            if cursor < minimum(r)
                push!(final_marks, cursor:(minimum(r) - 1) => label)
            end
            push!(final_marks, r => lbl)
            cursor = maximum(r) + 1
        end
        if cursor <= kmax
            push!(final_marks, cursor:kmax => label)
        end
        delete!(tm.marks, key)
        push!(tm.marks, final_marks...)
    end
    nothing::Nothing
end

"""
```julia
mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol) -> ::Nothing
```
Marks beyond the characters `ch` for `f` bytes as `label`.
```julia
using OliveHighlighters

tm = Highlighter("sample \\n")

mark_for!(tm, "\\", 1, :exit)
style!(tm, :exit, "color" => "lightblue")

string(tm)
```
- See also: `mark_line_after!`, `mark_julia!`, `string(::TextStyleModifier)`
"""
function mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol)
    starts = _grapheme_starts(tm.raw)
    total = length(starts)
    if total <= 1
        return
    end
    chars = findall(ch, tm.raw)
    for pos_byte in chars
        gr = _byte_range_to_grapheme_range(starts, pos_byte)
        existing = length(findall(i -> length(findall(n -> (n in i), pos_byte)) > 0, collect(keys(tm.marks))))
        if ~(existing > 0)
            push!(tm.marks, minimum(gr):(maximum(gr) + f) => label)
        end
    end
    nothing::Nothing
end

"""
```julia
mark_line_after!(tm::TextModifier, ch::String, label::Symbol) -> ::Nothing
```
Marks the line after a certain `String` with the `Symbol` `label` in `tm.marks`.
```julia
using OliveHighlighters

julia_code = "julia"
tm = Highlighter(julia_code)

mark_line_after!(tm, "#", :comment)

style!(tm, :comment, "color" => "gray", "font-weight" => "bold")
string(tm)
```
- See also: `mark_line_after!`, `mark_for!`
"""
mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)

OPS::Vector{SubString} = split("""<: = == < > => -> || -= += + / * - ~ <= >= &&""", " ")
UNTILS::Vector{String} = [" ", ",", ")", "\n", "<br>", "&nbsp;", ";", "(", "{", "}"]

"""
```julia
mark_julia!(tm::TextModifier) -> ::Nothing
```
Performs the marking portion of highlighting for Julia code.
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# calls `mark_julia!` and `style_julia!`
OliveHighlighters.julia_block!(lighter)

# clears marks from `mark_julia` using `clear!` and updates `lighter.raw`
set_text!(lighter, "struct Example\\nfield::Any\\nend")

OliveHighlighters.mark_julia!(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_between!`, `TextStyleModifier`
"""
function mark_julia!(tm::TextModifier)
    tm.raw = replace(tm.raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ")
    # comments
    mark_between!(tm, "#=", "=#", :comment)

    # strings + string interpolation
    mark_between!(tm, "\"\"\"", :string)
    mark_line_after!(tm, "#", :comment)
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3::TextStyleModifier
            mark_julia!(tm3)
            nothing::Nothing
        end
        mark_after!(tm2, "\\", :exit)
    end
    mark_between!(tm, "'", :char)
    # functions
    mark_after!(tm, "::", :type, until = UNTILS)
    mark_before!(tm, "(", :funcn, until = UNTILS)
    mark_after!(tm, " :", :symbol, until = UNTILS)
    mark_after!(tm, "\n:", :symbol, until = UNTILS)
    mark_after!(tm, ",:", :symbol, until = UNTILS)
    mark_after!(tm, "(:", :symbol, until = UNTILS)
    mark_between!(tm, "{", "}", :params)
    mark_inside!(tm, :params) do tm2::TextStyleModifier
        mark_after!(tm2, ":", :symbol, until = UNTILS)
        for dig in digits(1234567890)
            mark_all!(tm2, Char('0' + dig), :number, is_number_only = true)
        end
        mark_all!(tm2, "true", :number)
        mark_all!(tm2, "false", :number)
    end
    mark_before!(tm, "{", :type, until = UNTILS)
    # macros
    mark_after!(tm, "@", :macro, until = UNTILS)
    # keywords
    mark_all!(tm, "function", :func)
    mark_all!(tm, "import", :import)
    mark_all!(tm, "using", :using)
    mark_all!(tm, "end", :end)
    mark_all!(tm, "struct", :struct)
    mark_all!(tm, "const", :using)
    mark_all!(tm, "global", :global)
    mark_all!(tm, "abstract", :abstract)
    mark_all!(tm, "mutable", :mutable)
    mark_all!(tm, "if", :if)
    mark_all!(tm, "else", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "in", :in)
    mark_all!(tm, "export", :using)
    mark_all!(tm, "try", :if)
    mark_all!(tm, "catch", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "for", :for)
    mark_all!(tm, "while", :for)
    mark_all!(tm, "quote", :for)
    mark_all!(tm, "begin", :begin)
    mark_all!(tm, "module", :module)
    # math
    for dig in digits(1234567890)
        mark_all!(tm, Char('0' + dig), :number, is_number_only = true)
    end
    mark_all!(tm, "true", :number)
    mark_all!(tm, "false", :number)
    for op in OPS
        mark_all!(tm, string(op), :op)
    end
    mark_between!(tm, "#=", "=#", :comment)
    nothing::Nothing
end

"""
```julia
style_julia!(tm::TextStyleModifier) -> ::Nothing
```
Performs the styling for a Julia highlighter. Note this function only needs to be called once on 
    a given highlighter; after styled, we can use `set_text!`
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# mark and style separately, these are also combined into `julia_block!`

OliveHighlighters.mark_julia!(lighter)
OliveHighlighters.style_julia!(lighter)

my_result::String = string(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_between!`, `TextStyleModifier`
"""
function style_julia!(tm::TextStyleModifier; exclude_default::Bool = false)
    if ~(exclude_default)
        style!(tm, :default, ["color" => "#3D3D3D"])
    end
    style!(tm, :func, ["color" => "#944d94"])
    style!(tm, :funcn, ["color" => "#2d65a8"])
    style!(tm, :using, ["color" => "#006C67"])
    style!(tm, :import, ["color" => "#fc038c"])
    style!(tm, :end, ["color" => "#b81870"])
    style!(tm, :mutable, ["color" => "#a82d38"])
    style!(tm, :struct, ["color" => "#944d94"])
    style!(tm, :begin, ["color" => "#a82d38"])
    style!(tm, :module, ["color" => "#b81870"])
    style!(tm, :string, ["color" => "#4e944d"])
    style!(tm, :if, ["color" => "#944d94"])
    style!(tm, :for, ["color" => "#944d94"])
    style!(tm, :in, ["color" => "#006C67"])
    style!(tm, :abstract, ["color" => "#a82d38"])
    style!(tm, :number, ["color" => "#8b0000"])
    style!(tm, :char, ["color" => "#8b0000"])
    style!(tm, :type, ["color" => "#D67229"])
    style!(tm, :exit, ["color" => "#cc0099"])
    style!(tm, :op, ["color" => "#0C023E"])
    style!(tm, :macro, ["color" => "#43B3AE"])
    style!(tm, :params, ["color" => "#00008B"])
    style!(tm, :symbol, ["color" => "#a154bf"])
    style!(tm, :comment, ["color" => "#808080"])
    style!(tm, :interp, ["color" => "#420000"])
    style!(tm, :global, ["color" => "#ff0066"])
    nothing::Nothing
end

"""
```julia
julia_block!(tm::TextStyleModifier) -> ::Nothing
```
Calls both `style_julia!` and `mark_julia!` in order to turn a loaded `TextStyleModifier` 
straight into highlighted Julia.
```julia
using OliveHighlighters

lighter = Highlighter("function example(x::Any)\\nend")

# calls `mark_julia!` and `style_julia!`
OliveHighlighters.julia_block!(lighter)

# clears marks from `mark_julia` using `clear!` and updates `lighter.raw`
set_text!(lighter, "struct Example\\nfield::Any\\nend")

OliveHighlighters.mark_julia!(lighter)
```
- See also: `mark_line_after!`, `style_julia!`, `mark_julia!`, `Highlighter`, `mark_julia`, `set_text!`
"""
function julia_block!(tm::TextStyleModifier)
    mark_julia!(tm)
    style_julia!(tm)
end

"""
```julia
mark_markdown!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Marks markdown highlights to `tm.marks`. `mark_julia!`, but for markdown.
```julia
using OliveHighlighters

md_hl = Highlighter()

OliveHighlighters.style_markdown!(md_hl)

set_text!(md_hl, "[key] = false")

OliveHighlighters.mark_markdown!(md_hl)

result::String = string(md_hl)
```
- See also: `mark_line_after!`, `style_markdown!`, `mark_julia!`, `TextStyleModifier`
"""
function mark_markdown!(tm::OliveHighlighters.TextModifier)
    mark_between!(tm, "```julia", "```", :julia)
    mark_inside!(tm, :julia) do tm2::TextModifier
        mark_julia!(tm2)
    end
    OliveHighlighters.mark_line_after!(tm, "\n#", :heading)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "(", ")", :link)
    OliveHighlighters.mark_between!(tm, "**", :bold)
    OliveHighlighters.mark_between!(tm, "*", :italic)
    OliveHighlighters.mark_between!(tm, "``", :code)
    OliveHighlighters.mark_between!(tm, "`", :code)
    nothing::Nothing
end

"""
```julia
style_markdown!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Adds markdown marking styles to `tm`.
```julia
using OliveHighlighters

md_hl = Highlighter()

OliveHighlighters.style_markdown!(md_hl)

set_text!(md_hl, "[key] = false")

OliveHighlighters.mark_markdown!(md_hl)

result::String = string(md_hl)
```
- See also: `mark_line_after!`, `mark_markdown!`, `mark_julia!`, `TextStyleModifier`
"""
function style_markdown!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :link, ["color" => "#D67229"])
    style!(tm, :heading, ["color" => "#954299"])
    style!(tm, :bold, ["color" => "#0f1e73"])
    style!(tm, :italic, ["color" => "#8b0000"])
    style!(tm, :keys, ["color" => "#ffc000"])
    style!(tm, :code, ["color" => "#8b0000"])
    style!(tm, :default, ["color" => "#1c0906"])
    style!(tm, :link, ["color" => "#8b0000"])
    style!(tm, :julia, ["color" => "#b52157"])
    style_julia!(tm, exclude_default = true)
end

"""
```julia
mark_toml!(tm::OliveHighlighters.TextModifier) -> ::Nothing
```
Marks all of the characters to highlight inside of raw TOML loaded into `tm.raw`.
```julia
using OliveHighlighters

toml_hl = Highlighter()

OliveHighlighters.style_toml!(toml_hl)

set_text!(toml_hl, "[key] = false")

OliveHighlighters.mark_toml!(toml_hl)

result::String = string(toml_hl)
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function mark_toml!(tm::OliveHighlighters.TextModifier)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "\"", :string)
    OliveHighlighters.mark_all!(tm, "=", :equals)
    for dig in digits(1234567890)
        OliveHighlighters.mark_all!(tm, string(dig)[1], :number, is_number_only = true)
    end
end

"""
```julia
style_toml!(tm::OliveHighlighters.TextStyleModifier) -> ::Nothing
```
Styles the default styles for a `TOML` highlighter.
```julia
using OliveHighlighters

toml_hl = Highlighter()

OliveHighlighters.style_toml!(toml_hl)

set_text!(toml_hl, "[key] = false")

OliveHighlighters.mark_toml!(toml_hl)

result::String = string(toml_hl)
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function style_toml!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :keys, ["color" => "#D67229"])
    style!(tm, :equals, ["color" => "#1f0c2e"])
    style!(tm, :string, ["color" => "#4e944d"])
    style!(tm, :default, ["color" => "#2d65a8"])
    style!(tm, :number, ["color" => "#8b0000"])
end

"""
```julia
# (this binding is from `OliveHighlighters`)
Base.string(tm::TextStyleModifier; args ...) -> ::String
```
This binding turns a `TextStyleModifier`'s text into a highlighted HTML 
result with inline styles. Make sure to *mark* **and** *style* the 
`TextStyleModifier` **before** sending it through this function. 
`args` allows us to provide key-word arguments to the current elements, 
for example we could use this to set the `class`.
```julia
using OliveHighlighters

tm = TextStyleModifier("function example(x::Any = 5) end")

OliveHighlighters.julia_block!(tm)

style!(tm, :default, "color" => "#333333")

display("text/html", string(tm))

# reloading
set_text!(tm, "function sample end")

OliveHighlighters.mark_julia!(tm)

OliveHighlighters.mark_all(tm, "sample", :sample)
style!(tm, :sample, "color" => "red")
display("text/html", string(tm))
```
- See also: `TextStyleModifier`, `style_toml!`, `clear!`, `set_text!`
"""
function string(tm::TextStyleModifier; args...)
    filter!(mark -> ~(length(mark[1]) < 1), tm.marks)
    sortedmarks = sort(collect(tm.marks), by = x -> x[1])
    n::Int64 = length(sortedmarks)
    if n == 0
        txt = a("-", text = rep_str(tm.raw); args...)
        style!(txt, tm.styles[:default]...)
        return string(txt)
    end
    at_mark::Int64 = 1
    output::String = ""
    chars = collect(graphemes(tm.raw))
    total_chars = length(chars)

    mark_start = first(sortedmarks[1][1])
    if mark_start > 1
        txt = span("-", text = rep_str(join(chars[1:mark_start - 1])); args...)
        style!(txt, tm.styles[:default]...)
        output = string(txt)
    end

    while true
        mark_range = sortedmarks[at_mark][1]
        mark_style = sortedmarks[at_mark][2]

        startidx = first(mark_range)
        endidx = last(mark_range)

        # Text between marks
        if at_mark != 1
            last_range = sortedmarks[at_mark - 1][1]
            lastmax = last(last_range)
            if startidx - lastmax > 1
                txt = span("-", text = rep_str(join(chars[lastmax + 1:startidx - 1])); args...)
                style!(txt, tm.styles[:default]...)
                output *= string(txt)
            end
        end

        # Styled marked region
        try
            txt = span("-", text = rep_str(join(chars[startidx:endidx])); args...)
        catch e
            @warn "error with text: $tm.raw"
            @warn "positions: $mark_range"
            @warn "mark: $mark_style"
            at_mark += 1
            if at_mark == n
                if endidx < total_chars
                    txt = span("-", text = rep_str(join(chars[endidx + 1:end])); args...)
                    style!(txt, tm.styles[:default]...)
                    output *= string(txt)
                end
                break
            end
            continue
        end

        if haskey(tm.styles, mark_style)
            style!(txt, tm.styles[mark_style]...)
        else
            style!(txt, tm.styles[:default]...)
        end

        output *= string(txt)

        if at_mark == n
            if endidx < total_chars
                txt = span("-", text = rep_str(join(chars[endidx + 1:end])); args...)
                style!(txt, tm.styles[:default]...)
                output *= string(txt)
            end
            break
        end
        at_mark += 1
    end

    sortedmarks = nothing
    return output
end

export Highlighter, clear!, set_text!, classes, style!, remove!
end # module OliveHighlighters
