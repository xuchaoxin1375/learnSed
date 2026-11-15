# Remove whole-line comments and blank lines, then collapse whitespace.
# GNU sed is required for \+ in a BRE.
/^[[:space:]]*#/d
/^[[:space:]]*$/d
s/[[:space:]]\+/ /g
s/^[[:space:]]*//
s/[[:space:]]*$//
