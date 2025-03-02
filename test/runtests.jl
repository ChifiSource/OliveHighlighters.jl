using Test
using OliveHighlighters
using OliveHighlighters: classes
@testset "Olive Markdown" verbose = true begin
    @testset "TextStyleModifier API" verbose = true begin
        tm = Highlighter()
        @testset "Highlighter" begin
            @test typeof(tm) <: OliveHighlighters.TextModifier
            @test length(classes(tm)) == 0
            OliveHighlighters.style_julia!(tm)
            @test length(classes(tm)) > 1
            @test length(keys(tm.marks)) == 0
            OliveHighlighters.mark_julia!(tm)
            @test length(keys(tm.marks)) == 0
        end
        @testset "classes" begin
            cls = classes(tm)
            @test length(cls) > 1
            @test :default in cls
            @test :type in cls
            @test :module in cls
            style!(tm, :sample, "color" => "lightblue")
            @test :sample in [classes(tm) ...] 
        end
        @testset "set text" begin
            set_text!(tm, "function")
            @test tm.raw == "function"
            
        end
        @testset "style!" begin

        end
        set_text!(tm, "function example")
    end
    @testset "seeking functions" verbose = true begin
        @testset "mark all" begin 

        end
        @testset "mark after" begin

        end
    end
    @testset "highlighting" verbose = true begin
        @testset "julia highlighting" verbose = true begin

        end
        @testset "markdown highlighting" begin

        end
        @testset "toml highlighting" begin

        end
    end
end