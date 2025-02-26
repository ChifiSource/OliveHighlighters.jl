<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/0.1/olivehighlighters.png" width=225></img>
</div>

---
`OliveHighlighters` is a [ToolipsServables](https://github.com/ChifiSource/ToolipsServables.jl)-based syntax highlighting system for [Olive](https://github.com/ChifiSource/Olive.jl). The main objective of this highlighting system is to provide a clean and easy to modify stylized output for syntax in `Olive`, though it could (and has) easily be applied to other projects as well.
```julia
using OliveHighlighters: TextStyleModifier, julia_block!

tm = TextStyleModifier(
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
julia_block!(tm)

# use `string` to turn this into HTML:
display("text/html", string(tm))
```
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/01%20screenshots/Screenshot%20from%202024-12-25%2008-16-33.png?raw=true"></img>


###### usage
Using this package is really easy. In order to lex code, we use several different marking algorithms which store marks in a `TextStyleModifier`. The `TextStyleModifier` has special indexing that allows it to work better for this case. We set styles with the `Toolips.style!`, using symbols to mark things as we see fit. The package also provides three prebuilt highlighters for markdown, toml, and Julia.
A full list of modifying functions is available in the `OliveHighlighters` doc-string.
