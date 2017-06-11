function url(pkg)
    path = joinpath(Pkg.dir(), "METADATA", pkg, "url")
    ispath(path) || error("No METADATA for $pkg.")
    url_git = strip(readstring(path))
end


isrecipe(x) = false
function isrecipe(ex::Expr)
    (ex.head == :macrocall) &&
    (ex.args[1] == Symbol("@recipe"))
end

isline(ex) = false
isline(ex::Expr) = ex.head == :line
