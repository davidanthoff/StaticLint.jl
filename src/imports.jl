function import_has_dots(x)
    i = 2
    while CSTParser.is_dot(x.args[i])
        i +=1
    end
    return i - 2
end

function unwrap_imports(x)
    !all(CSTParser.is_colon(a) || a isa CSTParser.PUNCTUATION || a isa CSTParser.IDENTIFIER || a isa CSTParser.KEYWORD for a in x) && return []
    prefix = Symbol[]
    vars = Vector{Symbol}[]

    i = 2
    if any(CSTParser.is_colon(a) for a in x)
        while !CSTParser.is_colon(x.args[i])
            !(x.args[i] isa CSTParser.PUNCTUATION) && push!(prefix, Symbol(x.args[i].val))
            i += 1
        end
        i += 1
    end
    
    while i <= length(x.args)
        if CSTParser.is_comma(x.args[i]) 
            i += 1
        end
        var = copy(prefix)
        while i<= length(x.args) && !CSTParser.is_comma(x.args[i])
            !(x.args[i] isa CSTParser.PUNCTUATION) && push!(var, Symbol(x.args[i].val))
            i += 1
        end
        push!(vars, var)
    end
    return vars
end

function is_pkg_available(pkg::Symbol, S)
    string(pkg) in readdir(Pkg.dir())
end

function is_pkg_loaded(pkg::Symbol, S)
    string(pkg) in keys(loaded_mods)
end


function load_pkg(pkg::Symbol, S)
    if is_pkg_available(pkg, S)
        eval(:(import $(pkg)))
        mod_names(getfield(Main, pkg), loaded_mods)
    end
end

function get_imports(x, S) end
function get_imports(x::CSTParser.EXPR{T}, S) where T <: Union{CSTParser.Using,CSTParser.Import,CSTParser.ImportAll}
    u = T == CSTParser.Using
    vars = unwrap_imports(x)
    for v in vars
        rootmod = string(v[1])
        if rootmod in keys(S.current_scope.names) && S.current_scope.names[rootmod][end].t == :Module # is user defined module
            if length(v) == 1 
                if u # simple case
                    mx = S.current_scope.names[string(v[1])][end].val.args[3].args
                    for a in mx
                        if a isa CSTParser.EXPR{CSTParser.Export}
                            for i = 2:length(a.args)
                                if a.args[i] isa CSTParser.IDENTIFIER
                                    add_binding(x, CSTParser.str_value(a.args[i]), :Any, S::State, S.loc.offset + x.span)
                                end
                            end
                        end
                    end
                else
                    add_binding(x, rootmod, :Module, S::State, S.loc.offset + x.span)
                end
            end
        elseif rootmod in keys(SymbolServer.server) # is available external module
            if !SymbolServer.server[rootmod].is_loaded && !SymbolServer.server[rootmod].load_failed # load root module if not loaded and hasn't failed already
                SymbolServer.load_module(rootmod)
            end
            if !SymbolServer.server[rootmod].is_loaded # if load failed get out of here
                return 
            end
            if length(v) == 1
                if u
                    for n in SymbolServer.server[rootmod].exported
                        val = getfield(getfield(Main, Symbol(rootmod)), n)
                        add_binding(val, string(n), :Any, S, S.loc.offset + x.span)
                    end
                else
                    add_binding(x, rootmod, :Module, S, S.loc.offset + x.span)
                end
            elseif join(v[1:end-1], ".") in keys(SymbolServer.server)
                if Symbol(v[end]) in SymbolServer.server[join(v[1:end-1], ".")].internal
                    val = Main
                    for f in v
                        val = getfield(val, Symbol(f))
                    end
                    t = val isa Function ? "Function" : string(typeof(val))
                    add_binding(val, string(v[end]), t, S, S.loc.offset + x.span)
                end
            end
        end
        # user defined mod
        # if u && string(v[1]) in keys(S.current_scope.names) && S.current_scope.names[string(v[1])][end].t == :Module
        #     mx = S.current_scope.names[string(v[1])][end].val.args[3].args
        #     for a in mx
        #         if a isa CSTParser.EXPR{CSTParser.Export}
        #             for i = 2:length(a.args)
        #                 if a.args[i] isa CSTParser.IDENTIFIER
        #                     add_binding(x, CSTParser.str_value(a.args[i]), :Any, S::State, S.loc.offset + x.span)
        #                 end
        #             end
        #         end
        #     end
        # elseif join(v, ".") in keys(loaded_mods)
        #     add_binding(x, string(v[end]), :Any, S::State, S.loc.offset + x.span)
        #     if u
        #         for n in loaded_mods[join(v, ".")][1]
        #             add_binding(x, string(n), :Any, S::State, S.loc.offset + x.span)
        #         end
        #     end
        # elseif length(v) > 1 && join(v[1:length(v)-1], ".") in keys(loaded_mods)
        #     if v[end] in loaded_mods[join(view(v,1:length(v)-1), ".")][2]
        #         add_binding(x, string(v[end]), :Any, S::State, S.loc.offset + x.span)
        #     end
        # elseif is_pkg_available(v[1], S)
        #     load_pkg(v[1], S)
        # end
    end
end


function mod_names(m::Module, d = Dict{String,Tuple{Set{Symbol},Set{Symbol}}}())
    ext = names(m)
    int = names(m, true, true)
    d[string(m)] = (Set(ext), Set(int))
    for n in int
        if isdefined(m, n) && getfield(m, n) isa Module && !(string(getfield(m, n)) in keys(d))
            mod_names(getfield(m, n), d)
        end
    end
    d
end
