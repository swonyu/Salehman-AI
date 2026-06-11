=== Append bugs from run ===
fleet-2 running bug hunt
fleet-2: added quoting/edge bugs from parallel_safari.sh (RAM calc, ec truncate, no --help)
fleet-2: bugs - parallel_safari: incomplete 'ec' line (syntax err), no --help impl, quoting in usage/args, RAM calc portability (sysctl), set -e trap on errors, Safari JS defaults check fragile; grok_sessions_summary.py: no shebang/CLI
fleet-2: bugs - run_parallel: i var uninit (I=0 then [  ]), TABIDX array off-by-one risk, osascript no error handling, nohup/disown race,  vs , truncated echo, no --help, quoting in tasks/args; grok_status missing; supervisor missing; summary.py no CLI/args/shebang
