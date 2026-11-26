#!/bin/zsh
# Runs the app's --guard developer check on fixed cases and fails if the meaning guard lets a bad change through.
set -uo pipefail
BIN="${1:-HeyHumanly.app/Contents/MacOS/HeyHumanly}"
fail=0
check() { # original rewrite expected
  local got; got="$("$BIN" --guard "$1" "$2")"
  if [[ "$got" == "$3" ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1 -> $got (expected: $3)"; fail=1; fi
}
lacks() { # original rewrite forbidden-substring
  local got; got="$("$BIN" --guard "$1" "$2")"
  if [[ "$got" != *"$3"* ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1 -> $got (must not contain: $3)"; fail=1; fi
}
has() { # original rewrite required-substring
  local got; got="$("$BIN" --guard "$1" "$2")"
  if [[ "$got" == *"$3"* ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1 -> $got (must contain: $3)"; fail=1; fi
}
check "Ship it today." "Ship it today." "Ship it today."
check "I has went to the store yesterday." "I went to the store yesterday." "I went to the store yesterday."
check "idk if gng can come tbh" "I don't know if the gang can come, to be honest" "idk if gng can come, tbh"
check "send the thung to priya" "send the thing to priya" "send the thing to priya"
lacks "send the thung to priya" "send the file to priya" "file"
check "The invoice is 4,200 dollars, due on 12 March." "The invoice is 4,000 dollars, due on 12 March." "The invoice is 4,200 dollars, due on 12 March."
check "Meet at 3pm on Friday." "Meet at 4pm on Friday." "Meet at 3pm on Friday."
check "On 12 March, send the invoice." "Send the invoice on 12 March." "Send the invoice on 12 March."
check "Pay 12.50 today." "Pay 50.12 today." "Pay 12.50 today."
has "On 12 March, send it asap." "Send it as soon as possible on 12 March." "12 March"
check "Call me at 5pm." "Call me at 5 p.m." "Call me at 5pm."
check "send teh file" "send tbh file" "send the file"
check "fix \`x.lenght\` now" "Fix (x.length now." "fix \`x.lenght\` now"
check "use \`i => i*2\` here" "Use \`i => i * 2\` here." "Use \`i => i*2\` here."
check "i shoud of went their" "i should have gone there" "I should have gone there"
check "i.e. this, i think" "i.e. this, i think" "i.e. this, I think"
check "Use \`foo\` instead of \`bar\`" "\`bar\` should be replaced by \`foo\`." "\`bar\` should be replaced by \`foo\`."
check "I has a question and we was late." "I has a question and we was late." "I have a question and we were late."
check "Their is a bug, he don't know." "Their is a bug, he don't know." "There is a bug, he doesn't know."
check "thx, see u soon" "thx, see u soon" "thx, see u soon"
exit $fail
