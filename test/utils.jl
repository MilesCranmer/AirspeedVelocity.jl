function Base.isapprox(s1::String, s2::String)
    return replace(s1, r"\s+" => "") == replace(s2, r"\s+" => "")
end
