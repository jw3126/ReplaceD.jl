using Tokenize
function recipe_files(dir)
    ret = String[]
    for (root, dirs, files) in walkdir(dir)
        startswith(root, '.') && continue
        for file in files
            splitext(file)[2] == ".jl" || continue
            path = joinpath(root, file)
            if contains(readstring(path), "@recipe")
                push!(ret, path)
            end
        end
    end
    ret
end

immutable RecipeLocation
    startline::Int64
    stopline::Int64
    function RecipeLocation(startline, stopline)
        @assert startline <= stopline
        new(startline, stopline)
    end
end

type State
    searching_recipe_end::Bool
    current_recipe_start_line::Int
    current_line::Int
end

const OUTSIDE_LINE = -1
searching_recipe_end(s::State) = s.searching_recipe_end
searching_recipe_end!(s, b) = (s.searching_recipe_end = b; b)
function finish_recipe!(s::State)
    @assert searching_recipe_end(s)
    ret = RecipeLocation(s.current_recipe_start_line, s.current_line - 1)
    s.current_recipe_start_line = OUTSIDE_LINE
    searching_recipe_end!(s, false)
    ret
end
function start_recipe!(s::State)
    @assert searching_recipe_end(s) == false
    searching_recipe_end!(s, true)
    s.current_recipe_start_line = s.current_line
    s
end
State() = State(false, OUTSIDE_LINE, 1)

locate_recipes!(ret, ex, state) = ret
function locate_recipes!(ret, ex::Expr, state)
    if isline(ex)
        state.current_line = ex.args[1]
    end
    if searching_recipe_end(state) && isline(ex)
        push!(ret, finish_recipe!(state))
    end
    if isrecipe(ex)
        start_recipe!(state)
    end
    if !isrecipe(ex)
        for arg in ex.args
            locate_recipes!(ret, arg, state)
        end
    end
    ret
end

function locate_recipes(s::String)
    ret = RecipeLocation[]
    state = State()
    ex = parse("begin $s end")
    locate_recipes!(ret, ex, state)
    if searching_recipe_end(state)
        state.current_line = length(split(s, '\n')) + 1
        push!(ret, finish_recipe!(state))
    end
    @assert !searching_recipe_end(state)
    ret
end
    
function recipe_lines(s)
    lines = Int64[]
    for recipe in locate_recipes(s)
        append!(lines, recipe.startline:recipe.stopline)
    end
    lines
end

function replace_token_in_recipes(s, pattern, r)
    index = recipe_lines(s)
    lines = String[]
    for (i, line) in enumerate(String.(split(s, '\n')))
        if i in index
            line_new = ""
            for token in tokenize(line)
                if string(token) == pattern
                    line_new *= r
                else
                    line_new *= string(token)
                end
            end
            if line_new != line
                println(i)
                println(line)
                println(line_new)
            end
            push!(lines, line_new)
        else 
            push!(lines, line)
        end
    end
    join(lines, '\n')
end

function replace_token_in_recipes_dir(dir, pattern, r)
    for path in recipe_files(dir)
        s = readstring(path)
        @show path
        s_new = replace_token_in_recipes(s, pattern, r)
        write(path, s_new)
    end
end

function replace_d_pkg(pkg)
    # Pkg.checkout(pkg)
    dir = Pkg.dir(pkg)
    run(Cmd(`git branch replaceD`, dir=dir))
    run(Cmd(`git checkout replaceD`, dir=dir))
    pattern = "d"
    r = "plotattributes"
    replace_token_in_recipes_dir(dir, pattern, r)
    msg = "replace d by plotattributes inside recipes"
    run(Cmd(`git commit -am $msg`, dir=dir))
end

function search_token_in_recipes(f, path)
    index = recipe_lines(readstring(path))
    for (i,line) in enumerate(readlines(path))
        if i in index
            for token in tokenize(line)
                if f(token) 
                    println(" "^8, i, " ", line)
                    break
                end
            end
        end
    end
end
