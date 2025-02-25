using Test
using OliveHighlighters

@testset "Olive Markdown" verbose = true begin
    @testset "TextStyleModifier essentials" begin
        tm = Highlighter()
        @test length(classes(tm)) == 0
        OliveHighlighters.style_julia!(tm)
        @test length(classes(tm)) > 1
        set_text!(tm, "function example")
    end
    @testset "seeking functions" verbose = true begin

    end
    @testset "highlighting" verbose = true begin

    end
end