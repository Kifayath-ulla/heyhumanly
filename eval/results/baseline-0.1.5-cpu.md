| model | score | cases fully passed | median latency | failed checks |
|---|---|---|---|---|
| qwen2.5:3b | 92% | 10/17 | 4.6s | casual-slang:keepsLowercase, casual-lowercase-doubt:keepsLowercase, casual-lowercase-doubt:keepsSlang, rambling-meeting:removesFiller, inline-code:removesFiller, arabic-rtl:removesFiller, very-long-sentence:cutsEnough, goal-shorter:removesFiller, goal-shorter:cutsEnough |
| llama3.2 | 97% | 13/17 | 5.6s | rambling-meeting:removesFiller, spanish:removesFiller, arabic-rtl:removesFiller, doubt-question:keepsQuestion |
| qwen2.5:7b | 97% | 14/17 | 8.8s | casual-lowercase-doubt:keepsSlang, casual-lowercase-doubt:noInvention, rambling-meeting:removesFiller, goal-shorter:cutsEnough |
| qwen3.5:9b | 96% | 12/17 | 18.7s | casual-lowercase-doubt:removesFiller, rambling-meeting:removesFiller, mixed-update:removesFiller, very-long-sentence:cutsEnough, goal-shorter:cutsEnough |
| gemma4:12b | 98% | 15/17 | 21.9s | mixed-update:removesFiller, goal-shorter:cutsEnough |
