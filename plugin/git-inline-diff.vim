map <silent> <Leader>d :call <SID>gitDiff()<CR>

hi SignColumn guifg=#7c7c7c guibg=#000000 gui=NONE
hi scmLineAdded guifg=#65b042 ctermfg=77
hi scmLineChanged guifg=#3387cc ctermfg=63
hi scmLineRemoved guifg=#ff0000 ctermfg=202

if !exists("g:git_diff_added_symbol")
  let g:git_diff_added_symbol = '+'
endif

if !exists("g:git_diff_removed_symbol")
  let g:git_diff_removed_symbol = '-'
endif

if !exists("g:git_diff_changed_symbol")
  let g:git_diff_changed_symbol = '-+'
endif

exe 'sign define scmLineAdded text='.g:git_diff_added_symbol.' texthl=scmLineAdded'
exe 'sign define scmLineChanged text='.g:git_diff_changed_symbol.' texthl=scmLineChanged'
exe 'sign define scmLineRemoved text='.g:git_diff_removed_symbol.' texthl=scmLineRemoved'
sign define scmGhost

ruby << EOF
$SIGNS = Hash.new { |h,k| h[k] = [] }
EOF

function! s:gitDiff()
  set updatetime=1000

  let g:scmBufPath = expand("%:p")

  if g:scmBufPath == ""
    return
  endif

  let g:scmBufDir = expand("%:p:h")

  let oldFilePath = tempname()
  let newFilePath = tempname()

  let out = system('git show HEAD:' . bufname('%') . ' > ' . oldFilePath)
  if v:shell_error
    return
  endif

  execute "silent write! " . fnameescape(newFilePath)

  let out = system('cd ' . g:scmBufDir . ' && /usr/bin/diff -u ' . oldFilePath . ' ' . newFilePath)

  ruby << EOF
  file = VIM::evaluate("g:scmBufPath")
  diff = VIM::evaluate('out').split("\n")

  # workaround for flickering signs column
  VIM::command("sign place 1 line=1 name=scmGhost file=#{file}") unless $SIGNS[file].empty?

  # unplace signs in this file
  $SIGNS[file].each do |line|
    VIM::command("sign unplace #{line} file=#{file}")
  end
  $SIGNS[file] = []


  chunks = []
  annotations = {}
  counter_since_last_chunk = 0
  deletion = false
  diff.each do |line|
    next if line =~ /^[\+\-]{3}/
    chunk = line.match(/^@@ -([0-9]+)(,([0-9]+))? \+([0-9]+)(,([0-9]+))? @@/)
    if chunk
      chunks << {
        :line_before => chunk[1].to_i,
        :len_before => chunk[3].to_i,
        :line_after => chunk[4].to_i,
        :len_after => chunk[6].to_i
      }
      counter_since_last_chunk = 0
      deletion = false
    else
      counter_since_last_chunk += 1
    end


    line_in_current_file = chunks.last[:line_after] + counter_since_last_chunk - 1

    case line[0,1]
    when '-'
      annotations[line_in_current_file] = 'scmLineRemoved'
      deletion = true
      counter_since_last_chunk -= 1
    when '+'
      if deletion && annotations[line_in_current_file]
        annotations[line_in_current_file] = 'scmLineChanged'
      else
        annotations[line_in_current_file] = 'scmLineAdded'
      end
      deletion = false
    end
  end

  annotations.each do |line,sign|
    VIM::command("sign place #{line} line=#{line} name=#{sign} file=#{file}")
    $SIGNS[file] << line
  end

  # workaround for flickering signs column
  VIM::command("sign unplace 1 file=#{file}") if $SIGNS[file].empty?
EOF
endfunction

set updatetime=1000

autocmd CursorHold * call <SID>gitDiff()
