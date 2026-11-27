#!/bin/zsh
# Runs the app's --guard developer check on fixed cases and fails if the meaning guard lets a bad change through.
set -uo pipefail
BIN="${1:-HeyHumanly.app/Contents/MacOS/HeyHumanly}"
fail=0
check() { # original rewrite expected
  local got; got="$("$BIN" --guard "$1" "$2")"
  if [[ "$got" == "$3" ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1 -> $got (expected: $3)"; fail=1; fi
}
styled() { # style original rewrite expected
  local got; got="$("$BIN" --guard "$2" "$3" --style "$1")"
  if [[ "$got" == "$4" ]]; then echo "ok   [$1] $2 -> $got"; else echo "FAIL [$1] $2 -> $got (expected: $4)"; fail=1; fi
}
styledLacks() { # style original rewrite forbidden-substring
  local got; got="$("$BIN" --guard "$2" "$3" --style "$1")"
  if [[ "$got" != *"$4"* ]]; then echo "ok   [$1] $2 -> $got"; else echo "FAIL [$1] $2 -> $got (must not contain: $4)"; fail=1; fi
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
check "use \`i => i*2\` here" "Use \`i => i * 2\` here." "use \`i => i*2\` here."
check "i shoud of went their" "i should have gone there" "i should have gone there"
check "So i.e. this, i think" "So i.e. this, i think" "So i.e. this, I think"
check "Use \`foo\` instead of \`bar\`" "\`bar\` should be replaced by \`foo\`." "\`bar\` should be replaced by \`foo\`."
check "I has a question and we was late." "I has a question and we was late." "I have a question and we were late."
check "Their is a bug, he don't know." "Their is a bug, he don't know." "There is a bug, he doesn't know."
check "thx, see u soon" "thx, see u soon" "thx, see u soon"
check "I should of course check" "I should of course check" "I should of course check"
check "He dont know" "He dont know" "He doesn't know"
fixonly() { # original rewrite expected, with Fix only's keep-every-word check
  local got; got="$("$BIN" --guard "$1" "$2" --fix-only)"
  if [[ "$got" == "$3" ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1 -> $got (expected: $3)"; fail=1; fi
}
fixonly "I should of course check, the thing I sent you was the draft." "I should of course check, the draft I sent you." "I should of course check, the thing I sent you was the draft."
fixonly "I has went to the store." "I went to the store." "I went to the store."
check "I should of course check, the thing I sent you was the draft." "I should have checked, the thing I sent you was the draft." "I should of course check, the thing I sent you was the draft."
check "I should of gone, I should of course check" "I should have gone, I should have checked" "I should have gone, I should of course check"
styled Professional "I should of course check, the thing I sent you was the draft." "I should have checked; the item I sent you was the draft." "I should of course check; the item I sent you was the draft."
styled Friendly "thx for the help. i has a question" "Thanks so much for the help! I have a question." "thx so much for the help! i have a question."
styled Friendly "thx for the help. i has a question" "No problem at all! Shoot, what's your question?" "thx for the help. i have a question"
styled Professional "Can you send the report today?" "Certainly, I can send the report today." "Can you send the report today?"
styled Shorter "can you check the reprot? i will send it after" "Can you check the report? I will send it after." "can you check the report? i will send it after."
styled Professional "the build is broken again, someone pushed without running tests. pls fix asap" "the build is broken again. someone pushed without running tests." "the build is broken again, someone pushed without running tests. pls fix asap"
styled Shorter "Please send the draft. Can you also book the room?" "Send the draft." "Please send the draft. Can you also book the room?"
styled Professional "thx for the help. i has a question" "Thank you for the help. I have a question." "Thank you for the help. I have a question."
styled Professional "hey can u send me the report asap, we was late" "Sure, could you please send me the report as soon as possible? We were late." "Could you please send me the report as soon as possible? We were late."
styled Polish "sry, cant make it tmrw cuz im sick, lmk if thats ok" "Sure, lmk if thats ok." "sry, cant make it tmrw cuz im sick, lmk if thats ok."
styled Friendly "Their going to announce it monday" "They're going to announce it on Monday. How about grabbing a coffee together to celebrate this news?" "They're going to announce it on Monday."
styled Shorter "thx for the help. i has a question" "Thanks for the help. I have a question." "thx for the help. i have a question."
styled Professional "Sry, I cant come cuz Im sick" "I apologize, but I cannot come because I am sick." "I apologize, but I cannot come because I am sick."
styled Professional "Sry, cant make it tmrw, lmk if thats ok" "I am sorry, I cannot make it tomorrow. Please let me know if that is okay." "I am sorry, I cannot make it tomorrow. Please let me know if that is okay."
styled Professional "Tbh I dont think this will work" "To be honest, I do not think this will work." "To be honest, I do not think this will work."
styled Professional "Yep, I'll send the report" "Certainly, I'll send the report." "Certainly, I'll send the report."
styled Polish "Sry, I has a question" "Sorry to hear that! What is your question?" "Sry, I have a question"
styled Shorter "Can you send the report today?" "Here is a shorter version. Sure, the report was sent today." "Can you send the report today?"
styled Professional "Thx for the help." "Thank you for the help." "Thank you for the help."
check "I should of course check, and you should have called." "Of course, I should check, and you should have called." "Of course, I should check, and you should have called."
check "I should of course call, and I should of course check." "I should of course call, and I should have checked." "I should of course call, and I should of course check."
check "I should of course check" "Of course I should have checked" "Of course I should have checked"
styled Shorter "we was late, their is a bug" "We were late due to a bug." "we were late, there is a bug"
styled Professional "Can you send the report today?" "Could you send the report today? I apologize for any confusion." "Could you send the report today?"
styled Friendly "Can you send the report today?" "Could you send the report today? Hope you have a great day!" "Could you send the report today? Hope you have a great day!"
styled Professional "we was late, their is a bug" "we apologize for the delay." "we were late, there is a bug"
styled Friendly "their is a problem with the login page and we was not told" "I'm sorry to hear there's an issue with the login page. Let me know if you need any help troubleshooting." "there is a problem with the login page and we were not told"
styled Polish "send the deck to priya and the board" "Thanks for reaching out to us today." "send the deck to priya and the board"
fixonly "Great work on the launch everyone" "Great job on the launch, everyone!" "Great work on the launch everyone"
fixonly "hey r u coming to the standup tmrw?" "hey, u coming to the standup tmrw?" "hey r u coming to the standup tmrw?"
fixonly "I has finished the slides" "I haven't finished the slides" "I have finished the slides"
fixonly "The files is ready" "The files are ready." "The files are ready."
styled Friendly "the login page is broken for me" "It's okay, let's try this again." "the login page is broken for me"
styled Professional 'The api returns 500 when `user_id` is null, can you look?' 'The API returns a 500 error when `user_id` is null. Could you please assist?' 'The API returns a 500 error when `user_id` is null. Could you please assist?'
styledLacks Professional "Im running 10 mins late, start without me" "You are running 10 minutes late, and I need to start without you." "You are"
styledLacks Professional "r u free for lunch on thursday? theres a new ramen place near the office" "I'm free for lunch on Thursday. There's a new ramen place near the office." "I'm free"
styled Professional "Im running 10 mins late, start without me" "I'm running 10 minutes late. Start without me." "I'm running 10 minutes late. Start without me."
styled Professional "I attached the contract." "You will find the contract attached." "You will find the contract attached."
styled Professional "I can send the file on request." "You can ask me to send the file." "You can ask me to send the file."
styled Professional "what time works for u?" "I'd like to know what time works for a call." "I'd like to know what time works for a call."
styledLacks Professional "r u free for lunch on thursday? theres a new ramen place near the office" "Here is a professional version: I'm free for lunch on Thursday. There's a new ramen place near the office." "I'm free"
styledLacks Professional "ngl the new design is way better, nice job" "Thank you for sharing your feedback on the new design. I'm glad to hear that it has exceeded your expectations." "Thank you for sharing"
styledLacks Professional "r u free for lunch on thursday? theres a new ramen place near the office" "I'm available for lunch on Thursday. There's a new ramen place near the office. Would you be free to join me?" "available"
exit $fail
