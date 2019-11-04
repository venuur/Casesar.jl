module Caesar

export token_list,
       type,
       line_comment_token,
       open_parenthesis_token,
       close_parenthesis_token,
       symbol_token,
       newline_token,
       whitespace_token,
       isatom,
       value,
       make_atom,
       AtomExpr,
       Token,
       iswhitespace,
       expr_token,
       expr_tokens,
       CombinationExpr,
       parse_atom,
       make_combination

delim_regex() = r"([()]|[ ]+|\n|;)"

@enum TokenType begin
    symbol_token
    # All of these count as delimiters.
    open_parenthesis_token
    close_parenthesis_token
    line_comment_token
    newline_token
    whitespace_token
end

struct Token
    type::TokenType
    line::Int
    col::Int
    index_range::UnitRange
    value::String
end

type(t::Token) = t.type

value(t::Token) = t.value


isatom(token::Token) = type(token) == symbol_token

iswhitespace(token::Token) =
    (type(token) === whitespace_token || type(token) === newline_token)


function delimiter_token(line, col, index, value)
    if value == "("
        type = open_parenthesis_token
    elseif value == ")"
        type = close_parenthesis_token
    elseif value == ";"
        type = line_comment_token
    elseif value == "\n"
        type = newline_token
    else
        type = whitespace_token
    end

    Token(type, line, col, index, value)
end

function token_list(code)
    function _push_delimiter!(tokens, line, col, range, code)
        value = code[next_range]
        t = delimiter_token(line, col, next_range, value)
        push!(tokens, t)
        if type(t) == newline_token
            line += 1
            col = 1
        else
            col += length(value)
        end
        line, col
    end

    function _push_symbol!(tokens, line, col, index, code)
        value = code[index]
        push!(tokens, Token(symbol_token, line, col, index, value))
        col += length(value)
        line, col
    end

    delim = delim_regex()
    tokens = Array{Token}(undef, 0)
    line = 1
    col = 1
    next_range = findnext(delim, code, 1)
    if next_range === nothing
        if length(code) > 0
            line, col = _push_symbol!(tokens, 1, 1, 1:lastindex(code), code)
        end
        return tokens
    end
    let i = first(next_range)
        if i > 1
            # There is some symbol before the first delimiter.
            line, col = _push_symbol!(tokens, 1, 1, 1:i-1, code)
        end
        line, col = _push_delimiter!(tokens, line, col, next_range, code)
    end
    while true
        prev_range = next_range
        i = last(prev_range) + 1
        next_range = findnext(delim, code, i)
        if next_range === nothing
            if i < lastindex(code)
                # Theres a symbol at the end of the file.
                line,
                col = _push_symbol!(tokens, line, col, 1:i:lastindex(code), code)
            end
            return tokens
        end
        let j = first(next_range)
            if j > i
                # There's a symbol between the delimiters.
                line, col = _push_symbol!(tokens, line, col, i:j-1, code)
            end
        end
        line, col = _push_delimiter!(tokens, line, col, next_range, code)
    end
end


struct AtomExpr
    value::String
    token::Token
end

make_atom(t::Token) = AtomExpr(value(t), t)
expr_token(atom::AtomExpr) = atom.token

function parse_atom(tokens, i)
    token = tokens[i]
    !isatom(token) && return nothing
    return make_atom(token), i+1
end

struct CombinationExpr
    head::Union{CombinationExpr,AtomExpr}
    body::Array{Union{CombinationExpr,AtomExpr}}
    tokens::Array{Token}
end

make_combination(head, body, tokens) = CombinationExpr(head, body, tokens)
expr_tokens(combination::CombinationExpr) = combination.tokens


function parse_combination(tokens, start)
    head = nothing
    body = Array{Union{AtomExpr, CombinationExpr}}(undef, 0)
    combination_tokens = Array{Token}(undef, 0)

    # Search for first none whitespace token or comment
    i = let k = start
        while k < lastindex(tokens)
            @debug "TOKEN" k tokens[k]
            if (type(tokens[k]) === line_comment_token)
                @debug "line_comment_token"
                push!(combination_tokens, tokens[k])
                k = let j = k
                    while j < lastindex(tokens) && type(tokens[j]) !== newline_token
                        push!(combination_tokens, tokens[j])
                        j += 1
                    end
                    j
                end
            elseif iswhitespace(tokens[k])
                @debug "whitespace"
                push!(combination_tokens, tokens[k])
                k += 1
            else
                break
            end
        end
        k
    end

    (type(tokens[i]) !== open_parenthesis_token) && return (nothing, start)
    @debug "TOKEN" i=i t=tokens[i] head=head body=body
    push!(combination_tokens, tokens[i])

    closed = false
    i += 1
    while i < lastindex(tokens)
        @debug "TOKEN" i=i t=tokens[i] head=head body=body
        if (type(tokens[i]) === line_comment_token)
            @debug "line_comment_token"
            push!(combination_tokens, tokens[i])
            j = i+1
            while j < lastindex(tokens) && type(tokens[j]) !== newline_token
                push!(combination_tokens, tokens[j])
                j += 1
            end
            i = j
        elseif iswhitespace(tokens[i])
            @debug "whitespace"
            push!(combination_tokens, tokens[i])
            i += 1
        elseif type(tokens[i]) === close_parenthesis_token
            @debug "close_parenthesis_token"
            closed = true
            push!(combination_tokens, tokens[i])
            i += 1
            break
        elseif isatom(tokens[i])
            @debug "atom"
            atom, i = parse_atom(tokens, i)
            atom === nothing && return (nothing, i)
            if head === nothing
                head = atom
            else
                push!(body, atom)
            end
            push!(combination_tokens, expr_token(atom))
        else
            @debug "combination"
            combination, i = parse_combination(tokens, i)
            combination === nothing && return (nothing, i)
            if head === nothing
                head = combination
            else
                push!(body, combination)
            end
            append!(combination_tokens, expr_tokens(combination))
        end
    end
    if closed
        return (make_combination(head, body, combination_tokens), i)
    else
        return (nothing, i)
    end
end

end # module
