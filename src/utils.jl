## Alternate constructors for symbolic objects
##
## Many (too many) ways to create symbolobjects
## Sym("x"), Sym(:x), Sym("x", "y") or Sym(:x, :y), @syms x y, symbols("x y")

"Create a symbolic object from a symbol or string"
Sym(s::AbstractString) = sympy_meth(:sympify, s)
Sym(s::Symbol) = Sym(string(s))


"Create a symbolic number"
Sym{T <: Number}(x::T) = convert(Sym, x)

## math constants in math.jl and done in __init__ stage

"vectorized version of `Sym`"
Sym(args...) = map(Sym, args)

## @syms a b c --- no commas on right hand side!
## Thanks to vtjnash for this!
"""

Macro to create many symbolic objects at once. (Written by `@vtjnash`.)

Example:

```
@syms a b c
```

The `@syms` macros creates the variables and assigns them into the
module `Main`. The `@vars` macro is identical, but this is
transitional and `@syms` should be used. (This is the name used in
MATLAB.). The old behaviour of `@syms` was to create the symbols and
return them for assignment through the left hand side.  The `symbols`
function does this with just few more keystrokes and allows
assumptions to be made. Hence, `@syms` is repurposed. The old behavior
is kept, for now, through `@osyms`. A name clearly to be replaced,
perhaps with `@vars`.

Original macro magic contributed by @vtjnash.
"""
macro syms(x...)
    q=Expr(:block)
    if length(x) == 1 && isa(x[1],Expr)
        @assert x[1].head === :tuple "@vars expected a list of symbols"
        x = x[1].args
    end
    for s in x
        @assert isa(s,Symbol) "@vars expected a list of symbols"
        push!(q.args, Expr(:(=), s, Expr(:call, :Sym, Expr(:quote, s))))
    end
    push!(q.args, Expr(:tuple, x...))
    eval(Main, q)
end


"""

The `vars` macro is identical to  `@syms`. this usage will be deprecated.

"""
macro vars(x...)
    q=Expr(:block)
    if length(x) == 1 && isa(x[1],Expr)
        @assert x[1].head === :tuple "@vars expected a list of symbols"
        x = x[1].args
    end
    for s in x
        @assert isa(s,Symbol) "@vars expected a list of symbols"
        push!(q.args, Expr(:(=), s, Expr(:call, :Sym, Expr(:quote, s))))
    end
    push!(q.args, Expr(:tuple, x...))
    eval(Main, q)
end

"""

Macro to create an assign variables. Similar to `symbols`.

"""
macro osyms(x...)
    q=Expr(:block)
    if length(x) == 1 && isa(x[1],Expr)
        @assert x[1].head === :tuple "@syms expected a list of symbols"
        x = x[1].args
    end
    for s in x
        @assert isa(s,Symbol) "@syms expected a list of symbols"
        push!(q.args, Expr(:(=), s, Expr(:call, :Sym, Expr(:quote, s))))
           end
    push!(q.args, Expr(:tuple, x...))
    q
end


## define one or more symbols directly
## a,b,c = symbols("a,b,c", commutative=false)
"""

Function to create one or more symbolic objects. These are specified with a string,
with commas separating different variables.

This function allows the passing of assumptions about the variables
such as `positive=true`, `real=true` or `commutative=true`. See [SymPy Docs](http://docs.sympy.org/dev/modules/core.html#module-sympy.core.assumptions) for a complete list.

Example:

```
x,y,z = symbols("x, y, z", real=true)
```

"""

function symbols(x::AbstractString; kwargs...) 
    out = sympy_meth(:symbols, x; kwargs...)
end

function length(x::SymbolicObject)
    sz = size(x)
    length(sz) == 0 && return(0)
    *(sz...)
end
function size(x::SymbolicObject)
    return ()
end
function size(x::SymbolicObject, dim::Integer)
    if dim <= 0
        error("dimension out of range")

    else
        return 1
    end
end

## pull out x property of Sym objects or leave alone
project(x::Any) = x
project(x::SymbolicObject) = x.x
project(x::Symbol) = project(Sym(x)) # can use :x instead of Sym(x)
project(x::Tuple) = map(project, x)
function project{T <: Any}(x::Dict{Sym,T})
    D = Dict()
    for (k,v) in x
        D[project(k)] = v
    end
    D
end
project(x::Irrational{:π}) = project(convert(Sym, x))
project(x::Irrational{:e}) = project(convert(Sym, x))
project(x::Irrational{:γ}) = project(convert(Sym, x))
project(x::Irrational{:catalan}) = project(convert(Sym, x))
project(x::Irrational{:φ}) = project(convert(Sym, x))

## for size of containers
function length(x::SymbolicObject)
    sz = size(x)
    length(sz) == 0 && return(0)
    *(sz...)
end
function size(x::SymbolicObject)
    return ()
end
function size(x::SymbolicObject, dim::Integer)
    if dim <= 0
        error("dimension out of range")
   
    else
        return 1
    end
end


## Iterator for Sym
Base.start(x::Sym) = 1
Base.next(x::Sym, state) = (x.x, state-1)
Base.done(x::Sym, state) = state <= 0






"""

In SymPy, the typical calling pattern is `obj.method` or
`sympy.method` ... In `PyCall`, this becomes `obj[:method](...)` or
`sympy.method(...)`. In `SymPy` many -- but no where near all --
method calls become `method(obj, ...)`. For those that aren't
included, this allows the call to follow `PyCall`, and be
`obj[:method]` where a symbol is passed for the method name.

These just dispatch to `sympy_meth` or `object_meth`, as
appropriate. This no longer can be used to access properties of the
underlying `PyObject`. For that, there is no special syntax beyond
`object.x[:property]`.

Examples:
```
x = Sym("x")
(x^2 - 2x + 1)[:diff]()
(x^2 - 2x + 1)[:integrate]((x,0,1))
```

"""
function getindex(x::SymbolicObject, i::Symbol)
    if haskey(project(x), i)
        function __XXxxXX__(args...;kwargs...) # replace with generated name
            object_meth(x, i, args...; kwargs...)
        end
        return __XXxxXX__
    elseif haskey(sympy, i)
        function __XXxxXX__(args...;kwargs...)
            sympy_meth(i, x, args...; kwargs...)
        end
        return __XXxxXX__
    else
       MethodError()
    end
end 

## deprecate trying to access both a property or a method...        
function getindexOLD(x::SymbolicObject, i::Symbol)
    ## find method
    if haskey(project(x), i)
        out = project(x)[i]
        if isa(out, Function)
            function f(args...;kwargs...)
                object_meth(x, i, args...; kwargs...)
            end
            return f
        else
            return out
        end
    elseif haskey(sympy, i)
        out = sympy[i]
        if isa(out, Function)
            function f(args...;kwargs...)
                sympy_meth(i, x, args...; kwargs...)
            end
            return f
        else
            return out
        end
    else
        MethodError()
    end
end

## Override this so that using symbols as keys in a dict works
Base.hash(x::Sym) = hash(project(x))


## Helper function from PyCall.pywrap:
function members(o::@compat Union{PyObject, Sym})
    out = pycall(PyCall.inspect["getmembers"], PyObject, project(o))
    AbstractString[a for (a,b) in out]
end


