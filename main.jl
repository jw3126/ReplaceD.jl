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

function url(pkg)
    path = joinpath(Pkg.dir(), "METADATA", pkg, "url")
    ispath(path) || error("No METADATA for $pkg.")
    url_git = strip(readstring(path))
end

