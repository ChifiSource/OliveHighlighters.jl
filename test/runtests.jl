using Test
using OliveHighlighters
using OliveHighlighters: classes

@testset "OliveHighlighters Syntax Highlighters" verbose = true begin
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
            set_text!(tm, "mutable")
            @test tm.raw == "mutable"
            @test length(tm.marks) == 0
        end
        class_len = length(classes(tm))
        @testset "styles" begin
            @test :sample in keys(tm.styles)
            style!(tm, :sample, "color" => "green")
            @test ("color" => "green") in tm.styles[:sample]
            style!(tm, :another, "color" => "red")
            @test :another in classes(tm)
            remove!(tm, :another)
            @test ~(:another in classes(tm))
        end
    end
    @testset "seeking functions" verbose = true begin
        tm = Highlighter("""function example(x::String = "hello!")\n    x * \" friend!\"\nend""")
        @testset "mark all" begin 
            OliveHighlighters.mark_all!(tm, "function", :function)
            @test :function in values(tm.marks)
            @test 1:8 in keys(tm.marks)
            @test tm.marks[1:8] == :function
        end
        @testset "mark before / after" begin
            OliveHighlighters.mark_before!(tm, "(", :funcn, until = OliveHighlighters.UNTILS)
            @test :funcn in values(tm.marks)
            @test 10:16 in keys(tm.marks)
            @test tm.marks[10:16] == :funcn
            OliveHighlighters.clear!(tm)
            OliveHighlighters.mark_after!(tm, "::", :type, until = OliveHighlighters.UNTILS)
            @test :type in values(tm.marks)
            @test length(tm.marks) == 1
            @test tm.raw[first(tm.marks)[1]] == "::String"
        end
        OliveHighlighters.clear!(tm)
        @testset "mark between" begin
            OliveHighlighters.mark_between!(tm, "\"", :string)
            @test :string in values(tm.marks)
            @test length(keys(tm.marks)) == 2
            @test tm.raw[[keys(tm.marks) ...][1]] in ("\"hello!\"", "\" friend!\"")
        end
        @testset "mark inside" begin 
            OliveHighlighters.mark_inside!(tm, :string) do tm2::Highlighter
                OliveHighlighters.mark_all!(tm2, "hello!", :message)
            end
            @test :message in values(tm.marks)
        end
        set_text!(tm, """example\n# hello \n\n# hi""")
        @testset "mark line after" begin
            OliveHighlighters.mark_line_after!(tm, "#", :comment)
            @test :comment in values(tm.marks)
            @test contains(tm.raw[first(tm.marks)[1]], "#")
            ks = [tm.raw[k] for k in keys(tm.marks)]
            @test contains(ks[1], " hello") || contains(ks[1], " hi")
            @test contains(ks[2], " hello") || contains(ks[2], " hi")
        end
    end
end