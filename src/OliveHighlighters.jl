module OliveHighlighters
using ToolipsServables
import ToolipsServables: Modifier, String, AbstractComponent, set_text!, push!, style!, string, set_text!

const repeat_offenders = ('\n', ' ', ',', '(', ')', ';', '\"', ']', '[')

"""
```julia
# (internal)
rep_in(s::String) -> ::String
```
`rep_in` is an internal `OliveHighlighters` function that is used to replace client-side 
character sequences with their Julia counter-parts. HTML DOMs will optimize the text by 
putting it through a filter where certain special characters are represented with character codes. 
This function replaces those with normal Unicode or ASCII characters.
```julia
```
- See also: `rep_str`, `TextStyleModifier`, `TextModifier`,
"""
rep_in(s::String) = replace(s, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ", 
"&#40;" => "(", "&#41;" => ")", "&#34;" => "\"", "&#60;" => "<", "&#62;" => ">", 
"&#36;" => "\$", "&lt;" => "<", "&gt;" => ">")

rep_str(s::String) = replace(s, " "  => "&nbsp;",
"\n"  =>  "<br>", "\\" => "&bsol;", "&#61;" => "=")

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
`mark_all!`. `mark_all!` will mark all of the positions with the symbols we provide, then we use `style!(tm, pairs ...)` to style 
those marks. `OliveHighlighters` also provides some pre-built highlighters:
- `mark_toml!`
- `toml_style!`
- `mark_markdown!`
- `markdown_style!`
- `highlight_julia!`
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
- See also: `list_classes`, `set_text!`, `julia_block!`, `mark_between!`
"""
mutable struct TextStyleModifier <: TextModifier
    raw::String
    taken::Vector{Int64}
    marks::Dict{UnitRange{Int64}, Symbol}
    styles::Dict{Symbol, Vector{Pair{String, String}}}
    function TextStyleModifier(raw::String = "")
        marks = Dict{Symbol, UnitRange{Int64}}()
        styles = Dict{Symbol, Vector{Pair{String, String}}}()
        new(replace(raw, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ", 
        "&#40;" => "(", "&#41;" => ")"), Vector{Int64}(), marks, styles)
    end
end

"""
```julia
list_classes(tm::TextStyleModifier) -> Base.Generator)
```
Returns a `Tuple` generator for the classes currently styled in the `TextStyleModifier`. This 
    is equivalent of getting the keys of the `styles` field.
```julia
using OliveHighlighters; TextStyleModifier, style_julia!
tm = TextStyleModifier("")
highlight_julia!(tm)

list_classes(tm)
```
- See also: `set_text!`, `TextStyleModifier`, `clear!`
"""
list_classes(tm::TextStyleModifier) = (key for key in keys(styles))

"""
```julia
set_text!(tm::TextStyleModifier, s::String) -> ::String
```
Sets the text of a `TextStyleModifier`. This is an extra-convenient function, 
it calls `rep_in` -- an internal function used to replace client-side characters -- and 
sets the result as the text of `TextStyleModifier`, then it makes a call to `clear!` to clear the 
current marks. This allows for the same highlighters with the same styles to be used with new text.
```julia
```
- See also: 
"""
set_text!(tm::TextModifier, s::String) = begin 
    tm.raw = rep_in(s)
    clear!(tm)
    nothing::Nothing
end

"""
```julia
clear!(tm::TextStyleModifier) -> ::Nothing
```
`clear!` is used to remove the current set of `marks` from a `TextStyleModifier`. 
This will allow for new marks to be loaded with a fresh call to a marking function.
```julia
```
- See also: 
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
        [push!(tm.taken, val) for val in p[1]]
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
Sets the style for a particular class on a `TextStyleModifier` to `sty`.
```julia
```
- See also: 
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
- See also: 
"""
function mark_all!(tm::TextModifier, s::String, label::Symbol)
    [begin
        if maximum(v) == length(tm.raw) && minimum(v) == 1
            push!(tm, v => label)
        elseif maximum(v) == length(tm.raw)
            if tm.raw[v[1] - 1] in repeat_offenders
                push!(tm, v => label)
            end
        elseif minimum(v) == 1
            if tm.raw[maximum(v) + 1] in repeat_offenders
                push!(tm, v => label)
            end
        else
            if tm.raw[v[1] - 1] in repeat_offenders && tm.raw[maximum(v) + 1] in repeat_offenders
                push!(tm, v => label)
            end
        end
     end for v in findall(s, tm.raw)]
    nothing::Nothing
end


function mark_all!(tm::TextModifier, c::Char, label::Symbol)
    [begin
        push!(tm, v => label)
    end for v in findall(c, tm.raw)]
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
- See also: `TextStyleModifier`, `mark_all!`, `julia_block!`, `clear!`
"""
function mark_between!(tm::TextModifier, s::String, label::Symbol)
    positions::Vector{UnitRange{Int64}} = findall(s, tm.raw)
    discounted::Vector{UnitRange{Int64}} = Vector{Int64}()
    [begin
        nd = findnext(s, tm.raw, maximum(pos) + 1)
        if isnothing(nd)
            push!(tm, pos[1]:length(tm.raw) => label)
        else
            push!(discounted, nd)
            push!(tm, minimum(pos):minimum(nd) => label)
        end
    end for pos in positions]
    nothing::Nothing
end

function mark_between!(tm::TextModifier, s::String, s2::String, label::Symbol)
    positions::Vector{UnitRange{Int64}} = findall(s, tm.raw)
    [begin
        nd = findnext(s2, tm.raw, maximum(pos) + 1)
        if isnothing(nd)
            push!(tm, pos[1]:length(tm.raw) => label)
        else
            push!(tm, minimum(pos):maximum(nd) => label)
        end
    end for pos in positions]
    nothing::Nothing
end


"""
```julia
mark_before!(tm::TextModifier, s::String, label::Symbol; until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0, 
includedims_r::Int64 = 0) -> ::Nothing
```
`mark_before` will mark the values before a label -- a good example of this is a `Function`, we would `mark_before` the parenthesis, 
`until` a space or new line.
```julia
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_before!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0,
    includedims_r::Int64 = 0)
    chars = findall(s, tm.raw)
    for labelrange in chars
        previous = findprev(" ", tm.raw,  labelrange[1])
         if isnothing(previous)
            previous  = length(tm.raw)
        else
            previous = previous[1]
        end
        if length(until) > 0
            lens =  [begin
                    point = findprev(d, tm.raw,  minimum(labelrange) - 1)
                    if ~(isnothing(point))
                        minimum(point) + length(d)
                    else
                        1
                    end
                    end for d in until]
            previous = maximum(lens)
        end
        pos = previous - includedims_l:maximum(labelrange) - 1 + includedims_r
        push!(tm, pos => label)
    end
    nothing::Nothing
end

"""
```julia
mark_before!(tm::TextModifier, s::String, label::Symbol; until::Vector{String} = Vector{String}(), includedims_l::Int64 = 0, 
includedims_r::Int64 = 0) -> ::Nothing
```
Marks after `s` for every occurance of `s` in tm.raw. For example, for type annotations we could mark after `::` until 
    space or `\\n`.
```julia
```
- See also: `TextStyleModifier`, `mark_between!`, `mark_all!`, `clear!`, `set_text!`
"""
function mark_after!(tm::TextModifier, s::String, label::Symbol;
    until::Vector{String} = Vector{String}(), includedims_r::Int64 = 0,
    includedims_l::Int64 = 0)
    chars = findall(s, tm.raw)
    for labelrange in chars
        ending = findnext(" ", tm.raw,  labelrange[1])
        if isnothing(ending)
            ending  = length(tm.raw)
        else
            ending = ending[1]
        end
        if length(until) > 0
            lens =  [begin
                    point = findnext(d, tm.raw,  maximum(labelrange) + 1)
                    if ~(isnothing(point))
                        maximum(point) - length(d)
                    else
                        length(tm.raw)
                    end
                    end for d in until]
            ending = minimum(lens)
        end
        pos = minimum(labelrange) - includedims_l:ending - includedims_r
        push!(tm,
        pos => label)
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
```
- See also: mark_after!, clear!, `mark_for!`, `string(::TextStyleModifier)`, `julia_block!`
"""
function mark_inside!(f::Function, tm::TextModifier, label::Symbol)
    only_these_marks = filter(mark -> mark[2] == label, tm.marks)
    for key in keys(only_these_marks)
        # Create a new TextModifier for the subrange and apply the function
        new_tm = TextStyleModifier(tm.raw[key])
        new_tm.styles = tm.styles
        f(new_tm)

        # Prepare to adjust marks
        base_pos = minimum(key)
        lendiff = base_pos - 1
        new_marks = Dict(
            (minimum(range) + lendiff):(maximum(range) + lendiff) => lbl
            for (range, lbl) in new_tm.marks
        )
        sortedmarks = sort(collect(new_marks), by=x -> x[1])

        # Initialize variables for processing
        final_marks = Vector{Pair{UnitRange{Int64}, Symbol}}()
        at_mark = 1
        n = length(sortedmarks)
        kmax = maximum(key)

        # Process the marks and avoid duplicates
        while true
            if at_mark > n || n == 0
                # Push remaining range up to kmax, if any
                if base_pos <= kmax
                    push!(final_marks, base_pos:kmax => label)
                end
                break
            end

            this_mark = sortedmarks[at_mark]
            new_min = minimum(this_mark[1])

            # Add range from base_pos to the start of this_mark, if non-empty
            if base_pos < new_min
                push!(final_marks, base_pos:(new_min - 1) => label)
            end

            # Add the current mark and update base_pos to its end
            push!(final_marks, this_mark[1] => this_mark[2])
            base_pos = maximum(this_mark[1]) + 1

            at_mark += 1
        end

        # Replace the marks for the current key with updated ranges
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
```
- See also: `mark_line_after!`, 
"""
function mark_for!(tm::TextModifier, ch::String, f::Int64, label::Symbol)
    if length(tm.raw) == 1
        return
    end
    chars = findall(ch, tm.raw)
    [begin
    if ~(length(findall(i -> length(findall(n -> n in i, pos)) > 0,
     collect(keys(tm.marks)))) > 0)
        push!(tm.marks, minimum(pos):maximum(pos) + f => label)
    end
    end for pos in chars]
    nothing::Nothing
end


mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)

"""
**Toolips Markdown**
### mark_julia!(tm::TextModifier)
------------------
Marks julia syntax.
#### example
```

```
"""
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
    mark_before!(tm, "(", :funcn, until = [" ", "\n", ",", ".", "\"", "&nbsp;",
    "<br>", "("])
    # type annotations
    mark_after!(tm, "::", :type, until = [" ", ",", ")", "\n", "<br>", "&nbsp;", "&nbsp;",
    ";"])
    # macros
    mark_after!(tm, "@", :type, until = [" ", ",", ")", "\n", "<br>", "&nbsp;", "&nbsp;",
    ";"])
    mark_between!(tm, "'", :char)
    # keywords
    mark_all!(tm, "function", :func)
    mark_all!(tm, "import", :import)
    mark_all!(tm, "using", :using)
    mark_all!(tm, "end", :end)
    mark_all!(tm, "struct", :struct)
    mark_all!(tm, "abstract", :abstract)
    mark_all!(tm, "mutable", :mutable)
    mark_all!(tm, "if", :if)
    mark_all!(tm, "else", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "in", :in)
    mark_all!(tm, "export ", :using)
    mark_all!(tm, "try ", :if)
    mark_all!(tm, "catch ", :if)
    mark_all!(tm, "elseif", :if)
    mark_all!(tm, "for", :for)
    mark_all!(tm, "while", :for)
    mark_all!(tm, "quote", :for)
    mark_all!(tm, "begin", :begin)
    mark_all!(tm, "module", :module)
    # math
    [mark_all!(tm, Char('0' + dig), :number) for dig in digits(1234567890)]
    mark_all!(tm, "true", :number)
    mark_all!(tm, "false", :number)
    [mark_all!(tm, string(op), :op) for op in split(
    """<: = == < > => -> || -= += + / * - ~ <= >= &&""", " ")]
    mark_between!(tm, "#=", "=#", :comment)
end

"""
**Toolips Markdown**
### highlight_julia!(tm::TextModifier)
------------------
Marks default style for julia code.
#### example
```

```
"""
highlight_julia!(tm::TextStyleModifier) = begin
    style!(tm, :default, ["color" => "#3D3D3D"])
    style!(tm, :func, ["color" => "#fc038c"])
    style!(tm, :funcn, ["color" => "#2F387B"])
    style!(tm, :using, ["color" => "#006C67"])
    style!(tm, :import, ["color" => "#fc038c"])
    style!(tm, :end, ["color" => "#b81870"])
    style!(tm, :mutable, ["color" => "#006C67"])
    style!(tm, :struct, ["color" => "#fc038c"])
    style!(tm, :begin, ["color" => "#fc038c"])
    style!(tm, :module, ["color" => "#b81870"])
    style!(tm, :string, ["color" => "#007958"])
    style!(tm, :if, ["color" => "#fc038c"])
    style!(tm, :for, ["color" => "#fc038c"])
    style!(tm, :in, ["color" => "#006C67"])
    style!(tm, :abstract, ["color" => "#006C67"])
    style!(tm, :number, ["color" => "#8b0000"])
    style!(tm, :char, ["color" => "#8b0000"])
    style!(tm, :type, ["color" => "#D67229"])
    style!(tm, :exit, ["color" => "#cc0099"])
    style!(tm, :op, ["color" => "#0C023E"])
    style!(tm, :comment, ["color" => "#808080"])
    style!(tm, :interp, ["color" => "#420000"])
end

"""
**Toolips Markdown**
### julia_block!(tm::TextModifier)
------------------
Marks default style for julia code.
#### example
```

```
"""
function julia_block!(tm::TextStyleModifier)
    mark_julia!(tm)
    highlight_julia!(tm)
end

function mark_markdown!(tm::OliveHighlighters.TextModifier)
    OliveHighlighters.mark_after!(tm, "# ", until = ["\n"], :heading)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "(", ")", :link)
    OliveHighlighters.mark_between!(tm, "**", :bold)
    OliveHighlighters.mark_between!(tm, "*", :italic)
    OliveHighlighters.mark_between!(tm, "``", :code)
end

function markdown_style!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :link, ["color" => "#D67229"])
    style!(tm, :heading, ["color" => "purple"])
    style!(tm, :point, ["color" => "darkgreen"])
    style!(tm, :bold, ["color" => "darkblue"])
    style!(tm, :italic, ["color" => "#8b0000"])
    style!(tm, :keys, ["color" => "#ffc00"])
    style!(tm, :code, ["color" => "#8b0000"])
    style!(tm, :default, ["color" => "brown"])
    style!(tm, :link, ["color" => "#8b0000"])
end

function mark_toml!(tm::OliveHighlighters.TextModifier)
    OliveHighlighters.mark_between!(tm, "[", "]", :keys)
    OliveHighlighters.mark_between!(tm, "\"", :string)
    OliveHighlighters.mark_all!(tm, "=", :equals)
    [OliveHighlighters.mark_all!(tm, string(dig), :number) for dig in digits(1234567890)]
end

function toml_style!(tm::OliveHighlighters.TextStyleModifier)
    style!(tm, :keys, ["color" => "#D67229"])
    style!(tm, :equals, ["color" => "purple"])
    style!(tm, :string, ["color" => "#007958"])
    style!(tm, :default, ["color" => "darkblue"])
    style!(tm, :number, ["color" => "#8b0000"])
end

function string(tm::TextStyleModifier)
    filter!(mark -> ~(length(mark[1]) < 1), tm.marks)
    sortedmarks = sort(collect(tm.marks), by=x->x[1])
    n::Int64 = length(sortedmarks)
    if n == 0
        txt = a("modiftxt", text = rep_str(tm.raw))
        style!(txt, tm.styles[:default] ...)
        return(string(txt))::String
    end
    at_mark::Int64 = 1
    output::String = ""
    mark_start = minimum(sortedmarks[1][1])
    if mark_start > 1
        txt = span("modiftxt", text = rep_str(tm.raw[1: mark_start - 1]))
        style!(txt, tm.styles[:default] ...)
        output = string(txt)
    end
    while true
        mark = sortedmarks[at_mark][1]
        if at_mark != 1
            last_mark = sortedmarks[at_mark - 1][1]
            lastmax = maximum(last_mark)
            if minimum(mark) - lastmax > 0
                txt = span("modiftxt", text = rep_str(tm.raw[lastmax + 1:minimum(mark) - 1]))
                style!(txt, tm.styles[:default] ...)
                output = output * string(txt)
            end
        end
        styname = sortedmarks[at_mark][2]
        try
            txt = span("modiftxt", text = rep_str(tm.raw[mark]))
        catch e
            Base.showerror(stdout, e)
            @warn "error with text: " * tm.raw
            @warn "positions: $mark"
            @warn "mark: $styname"
        end
        if styname in keys(tm.styles)
            style!(txt, tm.styles[styname] ...)   
        else
            style!(txt, tm.styles[:default] ...)
        end
        output = output * string(txt)
        if at_mark == n
            if maximum(mark) != length(tm.raw)
                txt = span("modiftxt", text = rep_str(tm.raw[maximum(mark) + 1:length(tm.raw)]))
                style!(txt, tm.styles[:default] ...)
                output = output * string(txt)
            end
            break
        end
        at_mark += 1
    end
    return output
end


export TextStyleModifier, clear!, set_text!
end # module OliveHighlighters
