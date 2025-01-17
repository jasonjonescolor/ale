" Author: w0rp <devw0rp@gmail.com>
" Description: Fixing files with eslint.

function! ale#fixers#eslint#Fix(buffer) abort
    let l:executable = ale#handlers#eslint#GetExecutable(a:buffer)
    let l:command = ale#node#Executable(a:buffer, l:executable)
    \   . ' --version'

    return ale#semver#RunWithVersionCheck(
    \   a:buffer,
    \   l:executable,
    \   l:command,
    \   function('ale#fixers#eslint#ApplyFixForVersion'),
    \)
endfunction

function! ale#fixers#eslint#ProcessFixDryRunOutput(buffer, output) abort
    for l:item in ale#util#FuzzyJSONDecode(a:output, [])
        return split(get(l:item, 'output', ''), "\n")
    endfor

    return []
endfunction

function! ale#fixers#eslint#ProcessEslintDOutput(buffer, output) abort
    " If the output is an error message, don't use it.
    for l:line in a:output[:10]
        if l:line =~# '\v^Error:|^Could not connect'
            return []
        endif
    endfor

    return a:output
endfunction

function! ale#fixers#eslint#ApplyFixForVersion(buffer, version) abort
    let l:executable = ale#handlers#eslint#GetExecutable(a:buffer)
    let l:options = ale#Var(a:buffer, 'javascript_eslint_options')

    " Use the configuration file from the options, if configured.
    if l:options =~# '\v(^| )-c|(^| )--config'
        let l:config = ''
        let l:has_config = 1
    else
        let l:config = ale#handlers#eslint#FindConfig(a:buffer)
        let l:has_config = !empty(l:config)
    endif

    if !l:has_config
        return 0
    endif

    " Use --fix-to-stdout with eslint_d
    if l:executable =~# 'eslint_d$' && ale#semver#GTE(a:version, [3, 19, 0])
        return {
        \   'cwd': ale#handlers#eslint#GetCwdBasedOnConfigFile(a:buffer),
        \   'command': ale#node#Executable(a:buffer, l:executable)
        \       . ale#Pad(l:options)
        \       . ' --stdin-filename %s --stdin --fix-to-stdout',
        \   'process_with': 'ale#fixers#eslint#ProcessEslintDOutput',
        \}
    endif

    " 4.9.0 is the first version with --fix-dry-run
    if ale#semver#GTE(a:version, [4, 9, 0])
        return {
        \   'cwd': ale#handlers#eslint#GetCwdBasedOnConfigFile(a:buffer),
        \   'command': ale#node#Executable(a:buffer, l:executable)
        \       . ale#Pad(l:options)
        \       . ' --stdin-filename %s --stdin --fix-dry-run --format=json',
        \   'process_with': 'ale#fixers#eslint#ProcessFixDryRunOutput',
        \}
    endif

    return {
    \   'cwd': ale#handlers#eslint#GetCwdBasedOnConfigFile(a:buffer),
    \   'command': ale#node#Executable(a:buffer, l:executable)
    \       . ale#Pad(l:options)
    \       . (!empty(l:config) ? ' -c ' . ale#Escape(l:config) : '')
    \       . ' --fix %t',
    \   'read_temporary_file': 1,
    \}
endfunction
