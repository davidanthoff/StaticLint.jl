module SymbolServer

struct MethodBinding
    path::String
    line::Int
    args::Vector{Tuple{String,String}}
    rt::String
end

struct FunctionBinding
    ms::Vector{MethodBinding}    
end

struct DataTypeBinding
    fields::Vector{String}
end
struct GenericBinding
    t::String
end

mutable struct ModuleBinding
    exported::Set{Symbol}
    internal::Set{Symbol}
    loaded::Dict{String,Any}
    is_loaded::Bool
    load_failed::Bool
end

function load_module(m::String)
    if m in keys(server)
        if server[m].is_loaded
            return true
        elseif server[m].load_failed
            return false
        else
            try
                eval(:(import $(Symbol(m))))
                M = getfield(Main, Symbol(m))
                load_module(M)
                server[m].is_loaded = true
            catch
                server[m].load_failed = true
            end
            return server[m].is_loaded
        end
    else
        return false
    end
end

function load_module(m::Module, load = false) 
    mname = string(first(methods(getfield(m, :eval))).module)
    if haskey(server, mname) && server[mname].is_loaded
        return
    end
    
    server[mname] = ModuleBinding(Set(names(m)), Set(names(m, true, true)), Dict(), true, false)
    for i in server[mname].internal
        !isdefined(m, i) && continue
        x = getfield(m, i)
        if x isa Module
            load_module(x)
        end
    end
    # if load
    #     for i in mn.internal
    #         !isdefined(m, i) && continue
    #         x = getfield(m, i)
    #         t = x isa Function ? Function : typeof(x)
    #         mn.loaded[i] = string(t)
    #     end
    # end
end

# function load_functions(m::Module, all = false)
#     mname = string(first(methods(getfield(m, :eval))).module)
#     if !haskey(server, mname)
#         load_module(m)
#     end
#     for i in ifelse(all, server[mname].internal, server[mname].exported)
#         !isdefined(m, i) && continue
#         x = getfield(m, i)
#         !(x isa Function) && continue
#         try load_function(x) end
#     end
# end

function get_module(m::String)
end

function load_binding(m::String, b::String)
    if haskey(server, m)

    end
end

# function load_function(f::Function)
#     fm = first(methods(f))
#     mname = string(fm.module)
#     if !haskey(server, mname)
#         load_module(fm.module)
#     end
#     rts = Base.return_types(f)
#     ms = MethodBinding[]
#     for (i, m) in enumerate(methods(f))
#         _, args, file, line = Base.arg_decl_parts(m)
#         rt = rts[i]
#         while rt isa UnionAll
#             rt = rt.body
#         end
#         if  rt isa Union || rt isa Core.TypeofBottom
#             rtname = "Any"
#         else
#             rtname = join([string(rt.name.module),string(rt.name.name)], ".")
#         end
        
#         push!(ms, MethodBinding(abspath(Base.find_source_file(string(file))), line, args[2:end], rtname))
#     end
#     server[mname].loaded[string(fm.name)] = FunctionBinding(ms)
#     return
# end

# function load_datatype(d::DataType)
#     while d isa UnionAll
#         d = d.body
#     end
#     if !haskey(server, string(d.name.module))
#         load_module(d.name.module)
#     end
# end

const pkgdir = Pkg.dir()
pkgdir = "c:/Users/zacnu/.julia/v0.6"
const installed_packages = filter(p->isdir(joinpath(pkgdir,p)) && p!="METADATA" && !startswith(p,"."), readdir(pkgdir))
const server = Dict{String,ModuleBinding}()

function init()
    load_module(Base)
    load_module(Core)    
    for pkg in installed_packages
        if isfile(joinpath(pkgdir, pkg, "src", join([pkg, ".jl"])))
            server[pkg] = ModuleBinding(Set{String}(), Set{String}(), Dict(), false, false)
        end
    end
end

end
