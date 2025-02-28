<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/0.1/olivehighlighters.png" width=225></img>
</div>

`OliveHighlighters` is a [ToolipsServables](https://github.com/ChifiSource/ToolipsServables.jl)-based syntax highlighting system designed *primarily* for [Olive](https://github.com/ChifiSource/Olive.jl). The main objective of this highlighting system is to provide a clean and easy to modify stylized output for syntax in `Olive`, though it could (and has) easily be applied to other projects as well. 
- [get started](#get-started)
  - [usage](#usage)
```julia
using using OliveHighlighters

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
julia_block!(tm)

# use `string` to turn this into HTML:
display("text/html", string(tm))
```
<img src="https://github.com/ChifiSource/image_dump/blob/main/olive/01%20screenshots/Screenshot%20from%202024-12-25%2008-16-33.png?raw=true"></img>
##### get started

###### usage

##### contributing
This project, as well as the rest of the `chifi` ecosystem are up for outside or inside contributions! This includes issues, pull-requests or using/sharing `OliveHighlighters` or related projects. Before opening an issue,
- ensure the issue does not exist
- ensure the issue can be replicated on the `Unstable` branch

Before opening a pull request,
- ensure that you follow the included `Base`-inspired documentation format.
- Make sure **to pull request to Unstable.**

Thanks guys, I really appreciate any help I can get!
