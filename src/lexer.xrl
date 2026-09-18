Definitions.
RUN     = run
COLLECT = collect
AND     = and
THEN    = then
OR      = or
DEFCMD  = cmd
USAGE   = low|med|high|only
BODY    = \{[^}]*\}
SEMI    = ;
COMMA   = ,
COMMENT = #.*|%.*
WS      = [\s]*
NL      = [\n\r]*
ID      = [a-zA-Z][a-zA-Z0-9_-]*
ELSE    = [^\s]

Rules.
{RUN}     : {token, {run, TokenLine}}.
{COLLECT} : {token, {collect, TokenLine}}.
{AND}     : {token, {together, TokenLine}}.
{THEN}    : {token, {then, TokenLine}}.
{OR}      : {token, {either, TokenLine}}.
{DEFCMD}  : {token, {defcmd, TokenLine}}.
{BODY}    : Chunk = lists:sublist(
					  TokenChars, 
					  2, 
					  length(TokenChars) - 2),
			Trimmed = string:trim(Chunk, both, "\n"),
			NLSplit = string:tokens(Trimmed, "\n"),
			Joined = string:join(NLSplit, " "),
			{token, {body, TokenLine, Joined}}.
{USAGE}   : {token, {usage, TokenLine, TokenChars}}.
{COMMA}   : {token, {comma, TokenLine}}.
{SEMI}    : {token, {semicolon, TokenLine}}.
{COMMENT} : skip_token.
{WS}      : skip_token.
{NL}      : skip_token.
{ID}      : {token, {id, TokenLine, TokenChars}}.
{ELSE}    : {error, err_string(TokenChars, TokenLine)}.

Erlang code.
err_string(Char, Line) ->
	lists:flatten(
	  io_lib:format(
				"Error on token '~s' around "
                "line ~B: not a valid character.", 
				[Char, Line])).
