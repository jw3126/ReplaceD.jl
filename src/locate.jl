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
    path::String
    startline::Int64
    stopline::Int64
    function RecipeLocation(path, startline, stopline)
        @assert startline <= stopline
        new(path, startline, stopline)
    end
end

type State
    path::String
    searching_recipe_end::Bool
    current_recipe_start_line::Int
    current_line::Int
end

const OUTSIDE_LINE = -1
searching_recipe_end(s::State) = s.searching_recipe_end
searching_recipe_end!(s, b) = (s.searching_recipe_end = b; b)
function finish_recipe!(s::State)
    @assert searching_recipe_end(s)
    ret = RecipeLocation(s.path, s.current_recipe_start_line, s.current_line - 1)
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
State(path) = State(path, false, OUTSIDE_LINE, 1)

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

function locate_recipes(path)
    ret = RecipeLocation[]
    state = State(path)
    ex = parse("begin $(readstring(path)) end")
    locate_recipes!(ret, ex, state)
    if searching_recipe_end(state)
        state.current_line = length(readlines(path)) + 1
        push!(ret, finish_recipe!(state))
    end
    @assert !searching_recipe_end(state)
    ret
end
    
function recipe_lines(path)
    recipes = locate_recipes(path)
    lines = Int64[]
    for recipe in locate_recipes(path)
        append!(lines, recipe.startline:recipe.stopline)
    end
    # Set(lines)
    lines
end

function search_token_in_recipes(f, path)
    index = recipe_lines(path)
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
