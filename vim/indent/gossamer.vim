if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GossamerIndent()
setlocal indentkeys=0{,0},0),0],!^F,o,O,e

setlocal nosmartindent
setlocal nocindent
setlocal autoindent

function! GossamerIndent()
  let prev_lnum = prevnonblank(v:lnum - 1)
  if prev_lnum == 0
    return 0
  endif

  let prev_line = getline(prev_lnum)
  let curr_line = getline(v:lnum)
  let indent = indent(prev_lnum)

  if prev_line =~# '{$'
    let indent += shiftwidth()
  endif

  if curr_line =~# '^\s*}'
    let indent = max([indent - shiftwidth(), 0])
  endif

  return indent
endfunction
