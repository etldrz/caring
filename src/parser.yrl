Nonterminals expr root rootlist.

Terminals run collect together either then defcmd 
	id body usage comma semicolon.

Rootsymbol rootlist.

Left 100 then.
Right 200 together.
Right 200 either.

expr -> expr either expr : {either, '$1', '$3'}.
expr -> expr together expr : {together, '$1', '$3'}.
expr -> expr then expr : {then, '$1', '$3'}.
expr -> id : element(3, '$1').

root -> defcmd id body id semicolon 
		: {defcmd, {'$2', '$3', '$4'}].
root -> defcmd id body usage comma id semicolon 
		: {defcmd, {'$2', '$3', '$4', '$6'}].
root -> run expr semicolon : '$2'.
root -> collect body id semicolon : {collect, {'$2', '$3'}].

rootlist -> root : {'$1'}.
rootlist -> rootlist root : '$1' ++ {'$2'}.

Erlang code.
