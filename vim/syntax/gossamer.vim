" Vim syntax file
" Language: Gossamer
" Maintainer: Gossamer contributors
" Filenames: *.gos

if exists("b:current_syntax")
  finish
endif

syntax case match

" Long string literals (thousands of chars) exceed the default 'synmaxcol'
" (3000); without this the closing quote is never found and the string bleeds
" into following lines.
setlocal synmaxcol=0

syntax keyword gossamerKeyword as async await const crate enum extern fn
syntax keyword gossamerKeyword impl let mod mut package pub self Self static
syntax keyword gossamerKeyword struct super trait type unsafe use where yield
syntax keyword gossamerControl if else match loop while for in break continue
syntax keyword gossamerControl return
" The block words are contextual: keywords only where their construct starts,
" ordinary names everywhere else.
syntax match gossamerControl "\<arena\>\ze\s*{"
syntax match gossamerControl "\<cohort\>\ze\s*[({]"
syntax match gossamerControl "\<select\>\ze\s*{"
syntax match gossamerControl "\<defer\>\ze\%(\s*{\|\s\+\h\)"
syntax match gossamerControl "\<default\>\ze\s*=>"
syntax match gossamerKeyword "\<comptime\>\ze\%(\s*{\|\s\+\h\)"
syntax match gossamerKeyword "\<newtype\>\ze\s\+\h"
syntax match gossamerKeyword "\<packed\>\ze\s\+enum\>"

syntax keyword gossamerType bool char str String Never Unit
syntax keyword gossamerType i8 i16 i32 i64 i128 isize
syntax keyword gossamerType u8 u16 u32 u64 u128 usize
syntax keyword gossamerType f32 f64
syntax keyword gossamerType Arc BTreeMap BTreeSet Box Deque DynValue Fn
syntax keyword gossamerType I64Vec Iterator Map MaxHeap MinHeap Mutex Option
syntax keyword gossamerType Queue Range Rc Receiver Result RwLock Sender Set
syntax keyword gossamerType Stack U8Vec Vec Weak

" Prelude functions no module exports, and the compiler-known calls.
syntax keyword gossamerBuiltin assert assert_eq spawn channel
syntax keyword gossamerBuiltin println print eprintln eprint format panic
syntax keyword gossamerBuiltin matches todo unimplemented unreachable dbg codegen

syntax keyword gossamerBoolean true false
syntax keyword gossamerConstant None Some Ok Err

syntax match gossamerNumber "\<0x[0-9a-fA-F_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<0b[01_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<0o[0-7_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<[0-9][0-9_]*\%(\.[0-9_]\+\)\=\%([eE][+-]\=[0-9_]\+\)\=\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"

syntax region gossamerString start=+b\=r\z(#*\)"+ end=+"\z1+ contains=gossamerEscape
syntax region gossamerString start=+b\?"+ skip=+\\\\\|\\"+ end=+"+ contains=gossamerEscape
" Multi-line strings are their own item: same-name regions merge into one
" syntax item, and the single-quote start/end patterns would swallow the
" """ delimiters. Defined after the single-quote regions so it wins at the
" shared quote column. The body starts on the line after the opening """
" (only whitespace may follow it) and runs to the closing """.
syntax region gossamerMultilineString start=+"""\s*$+ skip=+\\\\\|\\"+ end=+"""+ contains=gossamerEscape
" Long multi-line strings outrun the default backwards resync window.
syntax sync minlines=200
syntax match gossamerEscape display contained "\\\(x\x\{2}\|u{\x\+}\|.\)"

syntax match gossamerChar +b\?'\\\?.'+
syntax match gossamerChar +b\?'\\x\x\{2}'+
syntax match gossamerChar +b\?'\\u{\x\+}'+

syntax match gossamerComment "//.*$" contains=gossamerTodo,@Spell
syntax region gossamerBlockComment start="/\*" end="\*/" contains=gossamerBlockComment,gossamerTodo,@Spell
syntax keyword gossamerTodo TODO FIXME XXX NOTE contained

syntax match gossamerOperator "|>"
syntax match gossamerOperator "\.\.\."
syntax match gossamerOperator "<<="
syntax match gossamerOperator ">>="
syntax match gossamerOperator "\.\.="
syntax match gossamerOperator "\.\."
syntax match gossamerOperator "[+\-*%=<>!&|^~?@]"
syntax match gossamerOperator "[+\-*]%=\="
syntax match gossamerOperator "\(//\|/\*\)\@!/"
syntax match gossamerOperator "->"
syntax match gossamerOperator "=>"
syntax match gossamerOperator "::"
syntax match gossamerOperator "#"

" An attribute names a path, which is what separates it from a `#[1, 2]`
" Vec literal that happens to open a line.
syntax match gossamerAttribute "^\s*\zs#!\?\[[A-Za-z_].\{-}\]"
syntax match gossamerMacro "\<[a-zA-Z_][a-zA-Z0-9_]*!"

syntax match gossamerFunction "\<[a-zA-Z_][a-zA-Z0-9_]*\ze\s*("
syntax match gossamerTypeUser "\<[A-Z][a-zA-Z0-9_]*\>"

highlight default link gossamerKeyword Keyword
highlight default link gossamerControl Conditional
highlight default link gossamerType Type
highlight default link gossamerTypeUser Type
highlight default link gossamerBoolean Boolean
highlight default link gossamerConstant Constant
highlight default link gossamerNumber Number
highlight default link gossamerString String
highlight default link gossamerMultilineString String
highlight default link gossamerEscape SpecialChar
highlight default link gossamerChar Character
highlight default link gossamerComment Comment
highlight default link gossamerBlockComment Comment
highlight default link gossamerTodo Todo
highlight default link gossamerOperator Operator
highlight default link gossamerAttribute PreProc
highlight default link gossamerBuiltin Function
highlight default link gossamerMacro Macro
highlight default link gossamerFunction Function

let b:current_syntax = "gossamer"
