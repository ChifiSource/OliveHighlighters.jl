module OliveHighlighters
using ToolipsServables
import ToolipsServables: Modifier, String, AbstractComponent, set_text!, push!, style!, string, set_text!

"""
### abstract type TextModifier <: Toolips.Modifier
TextModifiers are modifiers that change outgoing text into different forms,
whether this be in servables or web-formatted strings. These are unique in that
they can be provided to `itmd` (`0.1.3`+) in order to create interpolated tmd
blocks, or just handle these things on their own.
##### Consistencies
- raw**::String**
- marks**::Dict{UnitRange{Int64}, Symbol}**
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
##### example
```
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
------------------
##### constructors
- TextStyleModifier(::String = "")
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

set_text!(tm::TextModifier, s::String) = begin 
    tm.raw = rep_in(s)
    clear!(tm)
end

rep_in(s::String) = replace(s, "<br>" => "\n", "</br>" => "\n", "&nbsp;" => " ", 
"&#40;" => "(", "&#41;" => ")", "&#34;" => "\"", "&#60;" => "<", "&#62;" => ">", 
"&#36;" => "\$", "&lt;" => "<", "&gt;" => ">")

clear!(tm::TextStyleModifier) = begin
    tm.marks = Dict{UnitRange{Int64}, Symbol}()
    tm.taken = Vector{Int64}()
end

function push!(tm::TextStyleModifier, p::Pair{UnitRange{Int64}, Symbol})
    r = p[1]
    found = findfirst(mark -> mark in r, tm.taken)
    if isnothing(found)
        push!(tm.marks, p)
        vecp = Vector(p[1])
        [push!(tm.taken, val) for val in p[1]]
    end
end

function push!(tm::TextStyleModifier, p::Pair{Int64, Symbol})
    if ~(p[1] in tm.taken)
        push!(tm.marks, p[1]:p[1] => p[2])
        push!(tm.taken, p[1])
    end
end
"""
**Toolips Markdown**
### style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}})
------------------
Styles marks assigned with symbol `marks` to `sty`.
#### example
```

```
"""
function style!(tm::TextStyleModifier, marks::Symbol, sty::Vector{Pair{String, String}})
    push!(tm.styles, marks => sty)
end

repeat_offenders = ['\n', ' ', ',', '(', ')', ';', '\"', ']', '[']

"""
**Toolips Markdown**
### mark_all!(tm::TextModifier, s::String, label::Symbol)
------------------
Marks all instances of `s` in `tm.raw` as `label`.
#### example
```

```
"""
function mark_all!(tm::TextModifier, s::String, label::Symbol)::Nothing
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
    nothing
end


function mark_all!(tm::TextModifier, c::Char, label::Symbol)
    [begin
        push!(tm, v => label)
    end for v in findall(c, tm.raw)]
end

"""
**Toolips Markdown**
### mark_between!(tm::TextModifier, s::String, label::Symbol; exclude::String = "\\"", excludedim::Int64 = 2)
------------------
Marks between each delimeter, unique in that this is done with by dividing the
count by two.
#### example
```

```
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
    nothing
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
    nothing
end


"""
**Toolips Markdown**
```julia
mark_before!(tm::TextModifier, s::String, label::Symbol; until::Vector{String},
includedims_l::Int64 = 0, includedims_r::Int64 = 0)
```
------------------
marks before a given string until hitting any value in `until`.
#### example
```

```
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
end

"""
**Toolips Markdown**
```julia
mark_after!(tm::TextModifier, s::String, label::Symbol; until::Vector{String},
includedims_l::Int64 = 0, includedims_r::Int64 = 0)
```
------------------
marks after a given string until hitting any value in `until`.
#### example
```

```
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
end

"""
**Toolips Markdown**
```julia
mark_inside!(f::Function, tm::TextModifier)
```
------------------
marks before a given string until hitting any value in `until`.
#### example
```

```
"""
function mark_inside!(f::Function, tm::TextModifier, label::Symbol)
    only_these_marks = filter(mark -> mark[2] == label, tm.marks)
    for key in keys(only_these_marks)
        # Create a new TextModifier for the subrange and apply the function
        new_tm = TextStyleModifier(tm.raw[key])
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
end



"""
**Toolips Markdown**
### mark_for!(tm::TextModifier, s::String, f::Int64, label::Symbol)
------------------
Marks a certain number of characters after a given value.
#### example
```

```
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
end


mark_line_after!(tm::TextModifier, ch::String, label::Symbol) = mark_between!(tm, ch, "\n", label)

function mark_line_startswith!(tm::TextModifier, ch::String, label::Symbol)
    marks = findall("\n$ch", tm.raw)
    [push!(tm.marks, mark[2]:findnext("\n", mark[2], tm.raw) => label) for mark in marks]
end

"""
**Toolips Markdown**
### clear_marks!(tm::TextModifier)
------------------
Clears all marks in text modifier.
#### example
```

```
"""
clear_marks!(tm::TextModifier) = tm.marks = Dict{UnitRange{Int64}, Symbol}()

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
    # delim
    mark_between!(tm, "#=", "=#", :comment)
    mark_line_after!(tm, "#", :comment)
    mark_between!(tm, "\"", :string)
    mark_inside!(tm, :string) do tm2::TextStyleModifier
        mark_between!(tm2, "\$(", ")", :interp)
        mark_after!(tm2, "\$", :interp)
        mark_inside!(tm2, :interp) do tm3
            julia_block!(tm3)
        end
        mark_after!(tm2, "\\", :exit)
    end
    mark_before!(tm, "(", :funcn, until = [" ", "\n", ",", ".", "\"", "&nbsp;",
    "<br>", "("])
    mark_after!(tm, "::", :type, until = [" ", ",", ")", "\n", "<br>", "&nbsp;", "&nbsp;",
    ";"])
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
#=    mark_inside!(tm, :string) do tm2
        mark_for!(tm2, "\\", 1, :exit)
    end =#
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
    style!(tm, :interp, ["color" => "darkred"])
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

rep_str(s::String) = replace(s, " "  => "&nbsp;",
"\n"  =>  "<br>", "\\" => "&bsol;", "&#61;" => "=")

end # module OliveHighlighters
