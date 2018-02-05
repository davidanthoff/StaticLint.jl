using CSTParser, StaticLint, LanguageServer

import StaticLint: State, Scope, Location, FileSystem, File, trav, find_bad_refs

import LanguageServer: uri2filepath, filepath2uri

function StaticLint._follow_include(x, path, s, S::State{LanguageServer.LanguageServerInstance})
    path = isabspath(path) ? path : joinpath(dirname(S.loc.path), path)
    if !haskey(S.fs.documents, LanguageServer.URI2(filepath2uri(path)))
        return
    end

    # parent = S.includes[S.loc.path]
    # f = File(path, (parent, S.loc.offset + x.span), [])
    # push!(parent.children, f)
    # S.includes[path] = f
    if !isempty(S.target.path) && path == S.target.path
        S.in_target = true
    end
    x1 = S.fs.documents[LanguageServer.URI2(filepath2uri(path))].code.ast
    old_Sloc = S.loc
    S.loc = StaticLint.Location(path, 0)
    trav(x1, s, S)
    S.loc = old_Sloc
    if !isempty(S.target.path) && S.loc.path != S.target.path
        S.in_target = false
    end
end

function StaticLint.trav(doc::LanguageServer.Document, server, target = StaticLint.Location("", -1))
    path = uri2filepath(doc._uri)
    S = State{LanguageServer.LanguageServerInstance}(Scope(), StaticLint.Location(path, 0), target, isempty(target.path) || (path == target.path), [], [], 0:0, false, Dict(path => File(path, nothing, [])), server, []);
    x = doc.code.ast
    trav(x, S.current_scope, S)
    find_bad_refs(S)

    return S
end

function _get_includes(x, files = String[])
    if isincludecall(x)
        path = get_path(x)
        isempty(path) && return
        push!(files, path)
    elseif x isa CSTParser.EXPR
        for a in x.args
            if !(x isa CSTParser.EXPR{CSTParser.Call})
                _get_includes(a, files)
            end
        end
    end
    return files
end

function update_includes!(doc::LanguageServer.Document)
    doc._includes = _get_includes(doc.code.ast)
    for (i, p) in enumerate(doc._includes)
        if !isabspath(p)
            doc._includes[i] = joinpath(dirname(doc._uri), p)
        end
    end
    
    return 
end

function update_includes!(server::LanguageServer.LanguageServerInstance)
    for (_, doc) in server.documents
        update_includes!(doc)
    end
end