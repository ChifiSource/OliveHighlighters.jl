<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/0.1/olivehighlighters.png" width=225></img>

  [![version](https://juliahub.com/docs/General/OliveHighlighters/stable/version.svg)](https://juliahub.com/ui/Packages/General/OliveHighlighters)

  [![deps](https://juliahub.com/docs/General/OliveHighlighters/stable/deps.svg)](https://juliahub.com/ui/Packages/General/OliveHighlighters?t=2)

  [![pkgeval](https://juliahub.com/docs/General/OliveHighlighters/stable/pkgeval.svg)](https://juliahub.com/ui/Packages/General/OliveHighlighters)
  
</div>

`OliveHighlighters` is a [ToolipsServables](https://github.com/ChifiSource/ToolipsServables.jl)-based syntax highlighting system designed *primarily* for [Olive](https://github.com/ChifiSource/Olive.jl). The main objective of this highlighting system is to provide a clean and easy to modify stylized output for syntax in `Olive`, though it could (and has) easily be applied to other projects as well. 
- [get started](#get-started)
  - [docs](#documentation)
  - [usage](#usage) 
- [contributing](#contributing)
```julia
using OliveHighlighters

tm = Highlighter(
"""function sample_func(x::Any)
       println("you provided the value \$x")
       if typeof(x) <: Real
         println("\$(x + 5) is the number incremented by 5")
       end
       if typeof(x) == Int64 && x > 0
          for x in 1:x
             println("hello \$x")
          end
       end
end
""")
# styling and marking for julia:
OliveHighlighters.julia_block!(tm)

# use `string` to turn this into HTML:
display("text/html", string(tm))
```
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/01%20screenshots/Screenshot%20from%202024-12-25%2008-16-33.png?raw=true"></img>
##### get started
Is `OliveHighlighters` the right package for you? This package serves a very specific role, presenting highlighted code within the web-browser or notebook as HTML output. This HTML specifically presents itself with in-line styling and clean simplified output. This particular package is created specifically for [Olive](https://github.com/ChifiSource/Olive.jl). `OliveHighlighters` is useful for the following applications:
- Getting highlighted julia code in a self-hosted `tmd` markdown document.
- Creating an application which serves highlighted code.
- Highlighting Julia code for an example within a Data Science notebook or similar HTTP-based development environment.
###### adding olive highlighters
`OliveHighlighters` `0.1` is registered to the `Julia/General` registry, we can add it using `Pkg.add`
```julia
using Pkg; Pkg.add("OliveHighlighters")
```
For the latest changes -- sometimes broken -- add the `Unstable` branch. Some of the branches (new) features might not be fully working.
```julia
using Pkg; Pkg.add("OliveHighlighters", rev = "Unstable")
```
##### documentation
- All exports are available in the `OliveHighlighters` doc-string.
- We are still working on getting our documentation website up, but there will be a documentation link **here** eventually.
###### usage
Usage of `OliveHighlighters` revolves around the `TextStyleModifier`, or `Highlighter` type. We create this type and then mutate it by adding our source and using *marking functions*.
```julia
using OliveHighlighters

hl = Highlighter("hello world!")

OliveHighlighters.mark_all!(hl, "hello", :hello)
style!(hl, :default, "color" => "black")
style!(hl, :hello, "background-color" => "orange", "color" => "black")
string(hl)
```
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/0.1/hlsc/Screenshot%20from%202025-03-05%2009-25-21.png"></img>

Note that in most cases we will need to use `display("text/html", string(hl))` to see our HTML output. The example above is how highlighters are composed, for a full list of marking functions use `?OliveHighlighters`. `OliveHighlighters` also provides complete syntax highlighters for Julia, Markdown, and `TOML`. These are used through `mark_julia!`/`mark_markdown!`/`mark_toml!` and the same equivalent functions for `style_julia!` and so-forth. For Julia specifically, there is also a convenience function which calls both `mark` and `style`, `julia_block!`
```julia
using OliveHighlighters

julia_hl = Highlighter("begin end")
md_hl = Highlighter()
OliveHighlighters.julia_block!(julia_hl)
OliveHighlighters.style_markdown!(md_hl)
OliveHighlighters.mark_markdown!(md_hl)
```
Also consider that when we call `set_text!` to change a highlighter's text, this will also clear the highlighter's marks, **but** it will **not** clear the highlighter's styles. This means we can use the same highlighter to highlight multiple code blocks of the same type of input.
- **marking julia inside of markdown example** (using `ToolipsServables.tmd` and `interpolate!`)
```julia
help?> ToolipsServables.interpolate!
  interpolate!(mdcomp::Component{:div}, components::Component{<:Any} ...; keyargs ...) -> ::Nothing
  interpolate!(comp::Component{:div}, fillfuncs::Pair{String, <:Any} ...) -> ::Nothing

  Interpolates markdown inside the :text of a div (typically created using
  tmd). The Component{<:Any} and key-word argument dispatch will interpolate
  in-line code blocks, as well as values with a % before them. The latter
  function will take a series of strings paired with functions.

  The functions will be passed the String of a code block, the return is
  another String – the result.
```
```julia
using OliveHighlighters
using OliveHighlighters.ToolipsServables: tmd, interpolate!

# the `julia` below should have three `s, not two.
my_md = tmd("mydoc",
"""# hello world
- this is my sample markdown, along with some julia code.
``julia
# example julia!
mutable struct Example
   x::Int64
end
``
""")

jl_highlighter = Highlighter()
OliveHighlighters.style_julia!(jl_highlighter)

function mark_md_julia(input::String)
    set_text!(jl_highlighter, input)
    OliveHighlighters.mark_julia!(jl_highlighter)
    string(jl_highlighter)::String
end

interpolate!(my_md, "julia" => mark_md_julia)
my_md # display("text/html", my_md) or display(my_md)
```

<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/0.1/hlsc/Screenshot%20from%202025-03-05%2009-25-05.png">

##### contributing
This project, as well as the rest of the `chifi` ecosystem are up for outside or inside contributions! This includes issues, pull-requests or using/sharing `OliveHighlighters` or related projects. Before opening an issue,
- ensure the issue does not exist
- ensure the issue can be replicated on the `Unstable` branch

Before opening a pull request,
- ensure that you follow the included `Base`-inspired documentation format.
- Make sure **to pull request to Unstable.**

Thanks you all, I really appreciate any help that is shared :)
