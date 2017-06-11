include("util.jl")
include("locate.jl")

pkgs = sort!(unique(mapreduce(Pkg.dependents, vcat, ["Plots", "RecipesBase"])))

const PKGDB = joinpath(Pkg.dir("ReplaceD"), "pkgdb")
ispath(PKGDB) || mkpath(PKGDB)
pkgdbpath(p) = joinpath(PKGDB, p)

for p in pkgs
    target = pkgdbpath(p)
    if !ispath(target)
        cmd = `git clone $(url(p)) $target`
        run(cmd)
    end
end


for pkg in pkgs
    root = pkgdbpath(pkg)
    println(pkg)
    for path in recipe_files(root)
        # parse("begin $(readstring(path)) end")
        println(" "^4, splitdir(path)[2])
        search_token_in_recipes(tok -> string(tok) == "d", path)
    end
end
