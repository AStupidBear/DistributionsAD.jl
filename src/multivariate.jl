## Categorical ##

struct TuringDiscreteNonParametric{T<:Real,P<:Real,Ts<:AbstractVector{T},Ps<:AbstractVector{P}} <: DiscreteUnivariateDistribution
    support::Ts
    p::Ps
    
    function TuringDiscreteNonParametric{T, P, Ts, Ps}(vs, ps; check_args=true) where {
        T <: Real,
        P <: Real,
        Ts <: AbstractVector{T},
        Ps <: AbstractVector{P},
    }
        check_args || return new{T, P, Ts, Ps}(vs, ps)
        Distributions.@check_args(TuringDiscreteNonParametric, length(vs) == length(ps))
        Distributions.@check_args(TuringDiscreteNonParametric, isprobvec(ps))
        Distributions.@check_args(TuringDiscreteNonParametric, allunique(vs))
        sort_order = sortperm(vs)
        vs = vs[sort_order]
        ps = ps[sort_order]
        new{T, P, Ts, Ps}(vs, ps)
    end    
end
function TuringDiscreteNonParametric(vs::Ts, ps::Ps; check_args=true) where {
    T <: Real,
    P <: Real,
    Ts <: AbstractVector{T},
    Ps <: AbstractVector{P},
}
    return TuringDiscreteNonParametric{T, P, Ts, Ps}(vs, ps; check_args = check_args)
end
function TuringDiscreteNonParametric(vs::Ts, ps::Ps; check_args=true) where {
    T <: Real,
    P <: Real,
    Ts <: AbstractVector{T},
    Ps <: SubArray,
}
    _ps = collect(ps)
    _Ps = typeof(ps)
    return TuringDiscreteNonParametric{T, P, Ts, _Ps}(vs, _ps, check_args = check_args)
end
function TuringDiscreteNonParametric(vs::Ts, ps::Ps; check_args=true) where {
    T <: Real,
    P <: Real,
    Ts <: AbstractVector{T},
    Ps <: TrackedVector{P, <:SubArray},
}
    _ps = ps[:]
    _Ps = typeof(_ps)
    return TuringDiscreteNonParametric{T, P, Ts, _Ps}(vs, _ps, check_args = check_args)
end

Base.eltype(::Type{<:TuringDiscreteNonParametric{T}}) where T = T

# Accessors
Distributions.params(d::TuringDiscreteNonParametric) = (d.support, d.p)

Distributions.support(d::TuringDiscreteNonParametric) = d.support

Distributions.probs(d::TuringDiscreteNonParametric)  = d.p

Base.isapprox(c1::D, c2::D) where D <: TuringDiscreteNonParametric =
    (support(c1) ≈ support(c2) || all(support(c1) .≈ support(c2))) &&
    (probs(c1) ≈ probs(c2) || all(probs(c1) .≈ probs(c2)))

function Distributions.rand(rng::AbstractRNG, d::TuringDiscreteNonParametric{T,P}) where {T,P}
    x = support(d)
    p = probs(d)
    n = length(p)
    draw = rand(rng, P)
    cp = zero(P)
    i = 0
    while cp < draw && i < n
        cp += p[i +=1]
    end
    x[max(i,1)]
end

Distributions.rand(d::TuringDiscreteNonParametric) = rand(GLOBAL_RNG, d)

Distributions.sampler(d::TuringDiscreteNonParametric) =
    DiscreteNonParametricSampler(support(d), probs(d))

Distributions.get_evalsamples(d::TuringDiscreteNonParametric, ::Float64) = support(d)

Distributions.pdf(d::TuringDiscreteNonParametric) = copy(probs(d))

# Helper functions for pdf and cdf required to fix ambiguous method
# error involving [pc]df(::DisceteUnivariateDistribution, ::Int)
function _pdf(d::TuringDiscreteNonParametric{T,P}, x::T) where {T,P}
    idx_range = searchsorted(support(d), x)
    if length(idx_range) > 0
        return probs(d)[first(idx_range)]
    else
        return zero(P)
    end
end
Distributions.pdf(d::TuringDiscreteNonParametric{T}, x::Int) where T  = _pdf(d, convert(T, x))
Distributions.pdf(d::TuringDiscreteNonParametric{T}, x::Real) where T = _pdf(d, convert(T, x))

function _cdf(d::TuringDiscreteNonParametric{T,P}, x::T) where {T,P}
    x > maximum(d) && return 1.0
    s = zero(P)
    ps = probs(d)
    stop_idx = searchsortedlast(support(d), x)
    for i in 1:stop_idx
        s += ps[i]
    end
    return s
end
Distributions.cdf(d::TuringDiscreteNonParametric{T}, x::Integer) where T = _cdf(d, convert(T, x))
Distributions.cdf(d::TuringDiscreteNonParametric{T}, x::Real) where T = _cdf(d, convert(T, x))

function _ccdf(d::TuringDiscreteNonParametric{T,P}, x::T) where {T,P}
    x < minimum(d) && return 1.0
    s = zero(P)
    ps = probs(d)
    stop_idx = searchsortedlast(support(d), x)
    for i in (stop_idx+1):length(ps)
        s += ps[i]
    end
    return s
end
Distributions.ccdf(d::TuringDiscreteNonParametric{T}, x::Integer) where T = _ccdf(d, convert(T, x))
Distributions.ccdf(d::TuringDiscreteNonParametric{T}, x::Real) where T = _ccdf(d, convert(T, x))

function Distributions.quantile(d::TuringDiscreteNonParametric, q::Real)
    0 <= q <= 1 || throw(DomainError())
    x = support(d)
    p = probs(d)
    k = length(x)
    i = 1
    cp = p[1]
    while cp < q && i < k #Note: is i < k necessary?
        i += 1
        @inbounds cp += p[i]
    end
    x[i]
end

Base.minimum(d::TuringDiscreteNonParametric) = first(support(d))
Base.maximum(d::TuringDiscreteNonParametric) = last(support(d))
Distributions.insupport(d::TuringDiscreteNonParametric, x::Real) =
    length(searchsorted(support(d), x)) > 0

Distributions.mean(d::TuringDiscreteNonParametric) = dot(probs(d), support(d))

function Distributions.var(d::TuringDiscreteNonParametric{T}) where T
    m = mean(d)
    x = support(d)
    p = probs(d)
    k = length(x)
    σ² = zero(T)
    for i in 1:k
        @inbounds σ² += abs2(x[i] - m) * p[i]
    end
    σ²
end

Distributions.mode(d::TuringDiscreteNonParametric) = support(d)[argmax(probs(d))]
function Distributions.modes(d::TuringDiscreteNonParametric{T,P}) where {T,P}
    x = support(d)
    p = probs(d)
    k = length(x)
    mds = T[]
    max_p = zero(P)
    @inbounds for i in 1:k
        pi = p[i]
        xi = x[i]
        if pi > max_p
            max_p = pi
            mds = [xi]
        elseif pi == max_p
            push!(mds, xi)
        end
    end
    mds
end

function Distributions.Categorical(p::TrackedVector; check_args = true)
    return TuringDiscreteNonParametric(1:length(p), p, check_args = check_args)
end

## Dirichlet ##

struct TuringDirichlet{T, TV <: AbstractVector} <: ContinuousMultivariateDistribution
    alpha::TV
    alpha0::T
    lmnB::T
end
function check(alpha)
    all(ai -> ai > 0, alpha) || 
        throw(ArgumentError("Dirichlet: alpha must be a positive vector."))
end
Zygote.@nograd DistributionsAD.check

function TuringDirichlet(alpha::AbstractVector)
    check(alpha)
    alpha0 = sum(alpha)
    lmnB = sum(loggamma, alpha) - loggamma(alpha0)
    T = promote_type(typeof(alpha0), typeof(lmnB))
    TV = typeof(alpha)
    TuringDirichlet{T, TV}(alpha, alpha0, lmnB)
end

function TuringDirichlet(d::Integer, alpha::Real)
    alpha0 = alpha * d
    _alpha = fill(alpha, d)
    lmnB = loggamma(alpha) * d - loggamma(alpha0)
    T = promote_type(typeof(alpha0), typeof(lmnB))
    TV = typeof(_alpha)
    TuringDirichlet{T, TV}(_alpha, alpha0, lmnB)
end
function TuringDirichlet(alpha::AbstractVector{T}) where {T <: Integer}
    Tf = float(T)
    TuringDirichlet(convert(AbstractVector{Tf}, alpha))
end
TuringDirichlet(d::Integer, alpha::Integer) = TuringDirichlet(d, Float64(alpha))

Distributions.Dirichlet(alpha::TrackedVector) = TuringDirichlet(alpha)
Distributions.Dirichlet(d::Integer, alpha::TrackedReal) = TuringDirichlet(d, alpha)

function Distributions.logpdf(d::TuringDirichlet, x::AbstractVector)
    simplex_logpdf(d.alpha, d.lmnB, x)
end
function Distributions.logpdf(d::TuringDirichlet, x::AbstractMatrix)
    simplex_logpdf(d.alpha, d.lmnB, x)
end
function Distributions.logpdf(d::Dirichlet{T}, x::TrackedVecOrMat) where {T}
    TV = typeof(d.alpha)
    logpdf(TuringDirichlet{T, TV}(d.alpha, d.alpha0, d.lmnB), x)
end

ZygoteRules.@adjoint function Distributions.Dirichlet(alpha)
    return pullback(TuringDirichlet, alpha)
end
ZygoteRules.@adjoint function Distributions.Dirichlet(d, alpha)
    return pullback(TuringDirichlet, d, alpha)
end

function simplex_logpdf(alpha, lmnB, x::AbstractVector)
    sum((alpha .- 1) .* log.(x)) - lmnB
end
function simplex_logpdf(alpha, lmnB, x::AbstractMatrix)
    @views init = vcat(sum((alpha .- 1) .* log.(x[:,1])))
    mapreduce(vcat, drop(eachcol(x), 1); init = init) do c
        sum((alpha .- 1) .* log.(c)) - lmnB
    end
end

Tracker.@grad function simplex_logpdf(alpha, lmnB, x::AbstractVector)
    simplex_logpdf(data(alpha), data(lmnB), data(x)), Δ -> begin
        (Δ .* log.(data(x)), -Δ, Δ .* (data(alpha) .- 1))
    end
end
Tracker.@grad function simplex_logpdf(alpha, lmnB, x::AbstractMatrix)
    simplex_logpdf(data(alpha), data(lmnB), data(x)), Δ -> begin
        (log.(data(x)) * Δ, -sum(Δ), repeat(data(alpha) .- 1, 1, size(x, 2)) * Diagonal(Δ))
    end
end

ZygoteRules.@adjoint function simplex_logpdf(alpha, lmnB, x::AbstractVector)
    simplex_logpdf(alpha, lmnB, x), Δ -> (Δ .* log.(x), -Δ, Δ .* (alpha .- 1))
end

ZygoteRules.@adjoint function simplex_logpdf(alpha, lmnB, x::AbstractMatrix)
    simplex_logpdf(alpha, lmnB, x), Δ -> begin
        (log.(x) * Δ, -sum(Δ), repeat(alpha .- 1, 1, size(x, 2)) * Diagonal(Δ))
    end
end

## MvNormal ##

"""
    TuringDenseMvNormal{Tm<:AbstractVector, TC<:Cholesky} <: ContinuousMultivariateDistribution

A multivariate Normal distribution whose covariance is dense. Compatible with Tracker.
"""
struct TuringDenseMvNormal{Tm<:AbstractVector, TC<:Cholesky} <: ContinuousMultivariateDistribution
    m::Tm
    C::TC
end
function TuringDenseMvNormal(m::AbstractVector, A::AbstractMatrix)
    return TuringDenseMvNormal(m, cholesky(A))
end
Base.length(d::TuringDenseMvNormal) = length(d.m)
Distributions.rand(d::TuringDenseMvNormal, n::Int...) = rand(Random.GLOBAL_RNG, d, n...)
function Distributions.rand(rng::Random.AbstractRNG, d::TuringDenseMvNormal, n::Int...)
    return d.m .+ d.C.U' * randn(rng, length(d), n...)
end

"""
    TuringDiagMvNormal{Tm<:AbstractVector, Tσ<:AbstractVector} <: ContinuousMultivariateDistribution

A multivariate normal distribution whose covariance is diagonal. Compatible with Tracker.
"""
struct TuringDiagMvNormal{Tm<:AbstractVector, Tσ<:AbstractVector} <: ContinuousMultivariateDistribution
    m::Tm
    σ::Tσ
end

Base.length(d::TuringDiagMvNormal) = length(d.m)
Base.size(d::TuringDiagMvNormal) = (length(d), length(d))
Distributions.rand(d::TuringDiagMvNormal, n::Int...) = rand(Random.GLOBAL_RNG, d, n...)
function Distributions.rand(rng::Random.AbstractRNG, d::TuringDiagMvNormal, n::Int...)
    return d.m .+ d.σ .* randn(rng, length(d), n...)
end

struct TuringScalMvNormal{Tm<:AbstractVector, Tσ<:Real} <: ContinuousMultivariateDistribution
    m::Tm
    σ::Tσ
end

Base.length(d::TuringScalMvNormal) = length(d.m)
Base.size(d::TuringScalMvNormal) = (length(d), length(d))
Distributions.rand(d::TuringScalMvNormal, n::Int...) = rand(Random.GLOBAL_RNG, d, n...)
function Distributions.rand(rng::Random.AbstractRNG, d::TuringScalMvNormal, n::Int...)
    return d.m .+ d.σ .* randn(rng, length(d), n...)
end

for T in (:AbstractVector, :AbstractMatrix)
    @eval Distributions.logpdf(d::TuringScalMvNormal, x::$T) = _logpdf(d, x)
    @eval Distributions.logpdf(d::TuringDiagMvNormal, x::$T) = _logpdf(d, x)
    @eval Distributions.logpdf(d::TuringDenseMvNormal, x::$T) = _logpdf(d, x)
end

function _logpdf(d::TuringScalMvNormal, x::AbstractVector)
    return -(length(x) * log(2π * abs2(d.σ)) + sum(abs2.((x .- d.m) ./ d.σ))) / 2
end
function _logpdf(d::TuringScalMvNormal, x::AbstractMatrix)
    return -(size(x, 1) * log(2π * abs2(d.σ)) .+ vec(sum(abs2.((x .- d.m) ./ d.σ), dims=1))) ./ 2
end

function _logpdf(d::TuringDiagMvNormal, x::AbstractVector)
    return -(length(x) * log(2π) + 2 * sum(log.(d.σ)) + sum(abs2.((x .- d.m) ./ d.σ))) / 2
end
function _logpdf(d::TuringDiagMvNormal, x::AbstractMatrix)
    return -((size(x, 1) * log(2π) + 2 * sum(log.(d.σ))) .+ vec(sum(abs2.((x .- d.m) ./ d.σ), dims=1))) ./ 2
end
function _logpdf(d::TuringDenseMvNormal, x::AbstractVector)
    return -(length(x) * log(2π) + logdet(d.C) + sum(abs2.(zygote_ldiv(d.C.U', x .- d.m)))) / 2
end
function _logpdf(d::TuringDenseMvNormal, x::AbstractMatrix)
    return -((size(x, 1) * log(2π) + logdet(d.C)) .+ vec(sum(abs2.(zygote_ldiv(d.C.U', x .- d.m)), dims=1))) ./ 2
end

# zero mean, dense covariance
MvNormal(A::TrackedMatrix) = TuringMvNormal(A)

# zero mean, diagonal covariance
MvNormal(σ::TrackedVector) = TuringMvNormal(σ)

# dense mean, dense covariance
MvNormal(m::TrackedVector{<:Real}, A::TrackedMatrix{<:Real}) = TuringMvNormal(m, A)
MvNormal(m::TrackedVector{<:Real}, A::Matrix{<:Real}) = TuringMvNormal(m, A)
MvNormal(m::AbstractVector{<:Real}, A::TrackedMatrix{<:Real}) = TuringMvNormal(m, A)

# dense mean, diagonal covariance
function MvNormal(
    m::TrackedVector{<:Real},
    D::Diagonal{T, <:TrackedVector{T}} where {T<:Real},
)
    return TuringMvNormal(m, D)
end
function MvNormal(
    m::AbstractVector{<:Real},
    D::Diagonal{T, <:TrackedVector{T}} where {T<:Real},
)
    return TuringMvNormal(m, D)
end
function MvNormal(
    m::TrackedVector{<:Real},
    D::Diagonal{T, <:AbstractVector{T}} where {T<:Real},
)
    return TuringMvNormal(m, D)
end

# dense mean, diagonal covariance
MvNormal(m::TrackedVector{<:Real}, σ::TrackedVector{<:Real}) = TuringMvNormal(m, σ)
MvNormal(m::TrackedVector{<:Real}, σ::AbstractVector{<:Real}) = TuringMvNormal(m, σ)
MvNormal(m::TrackedVector{<:Real}, σ::Vector{<:Real}) = TuringMvNormal(m, σ)
MvNormal(m::AbstractVector{<:Real}, σ::TrackedVector{<:Real}) = TuringMvNormal(m, σ)

# dense mean, constant variance
MvNormal(m::TrackedVector{<:Real}, σ::TrackedReal) = TuringMvNormal(m, σ)
MvNormal(m::TrackedVector{<:Real}, σ::Real) = TuringMvNormal(m, σ)
MvNormal(m::AbstractVector{<:Real}, σ::TrackedReal) = TuringMvNormal(m, σ)

# dense mean, constant variance
function MvNormal(m::TrackedVector{<:Real}, A::UniformScaling{<:TrackedReal})
    return TuringMvNormal(m, A)
end
function MvNormal(m::AbstractVector{<:Real}, A::UniformScaling{<:TrackedReal})
    return TuringMvNormal(m, A)
end
function MvNormal(m::TrackedVector{<:Real}, A::UniformScaling{<:Real})
    return TuringMvNormal(m, A)
end

# zero mean,, constant variance
MvNormal(d::Int, σ::TrackedReal{<:Real}) = TuringMvNormal(d, σ)

TuringMvNormal(d::Int, σ::Real) = TuringMvNormal(zeros(d), σ)
TuringMvNormal(m::AbstractVector{<:Real}, σ::Real) = TuringScalMvNormal(m, σ)
TuringMvNormal(σ::AbstractVector) = TuringMvNormal(zeros(length(σ)), σ)
TuringMvNormal(A::AbstractMatrix) = TuringMvNormal(zeros(size(A, 1)), A)
function TuringMvNormal(m::AbstractVector{<:Real}, σ::AbstractVector{<:Real})
    return TuringDiagMvNormal(m, σ)
end
function TuringMvNormal(
    m::AbstractVector{<:Real},
    D::Diagonal{T, <:AbstractVector{T}},
) where {T <: Real}
    return TuringMvNormal(m, sqrt.(D.diag))
end
function TuringMvNormal(m::AbstractVector{<:Real}, A::AbstractMatrix{<:Real})
    return TuringDenseMvNormal(m, A)
end
function TuringMvNormal(m::AbstractVector{<:Real}, A::UniformScaling{<:Real})
    return TuringMvNormal(m, sqrt(A.λ))
end

## MvLogNormal ##

struct TuringMvLogNormal{TD} <: AbstractMvLogNormal
    normal::TD
end
MvLogNormal(d::TuringDenseMvNormal) = TuringMvLogNormal(d)
MvLogNormal(d::TuringDiagMvNormal) = TuringMvLogNormal(d)
MvLogNormal(d::TuringScalMvNormal) = TuringMvLogNormal(d)
Distributions.length(d::TuringMvLogNormal) = length(d.normal)
function Distributions.rand(rng::Random.AbstractRNG, d::TuringMvLogNormal)
    return Distributions.exp!(rand(rng, d.normal))
end
function Distributions.rand(rng::Random.AbstractRNG, d::TuringMvLogNormal, n::Int)
    return Distributions.exp!(rand(rng, d.normal, n))
end
for T in (:AbstractVector, :AbstractMatrix)
    @eval Distributions.logpdf(d::TuringMvLogNormal, x::$T) = _logpdf(d, x)
end
for T in (:TrackedVector, :TrackedMatrix)
    @eval Distributions.logpdf(d::TuringMvLogNormal, x::$T) = _logpdf(d, x)
end
function _logpdf(d::TuringMvLogNormal, x::AbstractVector{T}) where {T<:Real}
    if insupport(d, x)
        logx = log.(x)        
        return _logpdf(d.normal, logx) - sum(logx)
    else
        return -T(Inf)
    end
end
function _logpdf(d::TuringMvLogNormal, x::AbstractMatrix{<:Real})
    if all(i -> DistributionsAD.insupport(d, view(x, :, i)), axes(x, 2))
        logx = log.(x)
        return DistributionsAD._logpdf(d.normal, logx) - vec(sum(logx; dims = 1))
    else
        return [DistributionsAD._logpdf(d, view(x, :, i)) for i in axes(x, 2)]
    end
end

# zero mean, dense covariance
MvLogNormal(A::TrackedMatrix) = TuringMvLogNormal(TuringMvNormal(A))

# zero mean, diagonal covariance
MvLogNormal(σ::TrackedVector) = TuringMvLogNormal(TuringMvNormal(σ))

# dense mean, dense covariance
MvLogNormal(m::TrackedVector{<:Real}, A::TrackedMatrix{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, A))
MvLogNormal(m::TrackedVector{<:Real}, A::Matrix{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, A))
MvLogNormal(m::AbstractVector{<:Real}, A::TrackedMatrix{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, A))

# dense mean, diagonal covariance
function MvLogNormal(
    m::TrackedVector{<:Real},
    D::Diagonal{T, <:TrackedVector{T}} where {T<:Real},
)
    return TuringMvLogNormal(TuringMvNormal(m, D))
end
function MvLogNormal(
    m::AbstractVector{<:Real},
    D::Diagonal{T, <:TrackedVector{T}} where {T<:Real},
)
    return TuringMvLogNormal(TuringMvNormal(m, D))
end
function MvLogNormal(
    m::TrackedVector{<:Real},
    D::Diagonal{T, <:AbstractVector{T}} where {T<:Real},
)
    return TuringMvLogNormal(TuringMvNormal(m, D))
end
function MvLogNormal(
    m::AbstractVector{<:Real},
    D::Diagonal{T, <:AbstractVector{T}} where {T<:Real},
)
    return MvLogNormal(MvNormal(m, D))
end

# dense mean, diagonal covariance
MvLogNormal(m::TrackedVector{<:Real}, σ::TrackedVector{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, σ))
MvLogNormal(m::TrackedVector{<:Real}, σ::AbstractVector{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, σ))
MvLogNormal(m::TrackedVector{<:Real}, σ::Vector{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, σ))
MvLogNormal(m::AbstractVector{<:Real}, σ::TrackedVector{<:Real}) = TuringMvLogNormal(TuringMvNormal(m, σ))

# dense mean, constant variance
function MvLogNormal(m::TrackedVector{<:Real}, σ::TrackedReal)
    return TuringMvLogNormal(TuringMvNormal(m, σ))
end
function MvLogNormal(m::TrackedVector{<:Real}, σ::Real)
    return TuringMvLogNormal(TuringMvNormal(m, σ))
end
function MvLogNormal(m::AbstractVector{<:Real}, σ::TrackedReal)
    return TuringMvLogNormal(TuringMvNormal(m, σ))
end

# dense mean, constant variance
function MvLogNormal(m::TrackedVector{<:Real}, A::UniformScaling{<:TrackedReal})
    return TuringMvLogNormal(TuringMvNormal(m, A))
end
function MvLogNormal(m::AbstractVector{<:Real}, A::UniformScaling{<:TrackedReal})
    return TuringMvLogNormal(TuringMvNormal(m, A))
end
function MvLogNormal(m::TrackedVector{<:Real}, A::UniformScaling{<:Real})
    return TuringMvLogNormal(TuringMvNormal(m, A))
end

# zero mean,, constant variance
MvLogNormal(d::Int, σ::TrackedReal{<:Real}) = TuringMvLogNormal(TuringMvNormal(d, σ))

## Zygote adjoint

ZygoteRules.@adjoint function Distributions.MvNormal(
    A::Union{AbstractVector{<:Real}, AbstractMatrix{<:Real}},
)
    return pullback(TuringMvNormal, A)
end
ZygoteRules.@adjoint function Distributions.MvNormal(
    m::AbstractVector{<:Real},
    A::Union{Real, UniformScaling, AbstractVecOrMat{<:Real}},
)
    return pullback(TuringMvNormal, m, A)
end
ZygoteRules.@adjoint function Distributions.MvNormal(
    d::Int,
    A::Real,
)
    value, back = pullback(A -> TuringMvNormal(d, A), A)
    return value, x -> (nothing, back(x)[1])
end
