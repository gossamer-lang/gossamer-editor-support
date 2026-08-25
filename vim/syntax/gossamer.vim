" Vim syntax file
" Language: Gossamer
" Maintainer: Gossamer contributors
" Filenames: *.gos

if exists("b:current_syntax")
  finish
endif

syntax case match

syntax keyword gossamerKeyword as async await comptime const crate dyn enum extern fn
syntax keyword gossamerKeyword impl let mod mut package pub self Self static
syntax keyword gossamerKeyword struct super trait type unsafe use where yield
syntax keyword gossamerControl if else match loop while for in break continue
syntax keyword gossamerControl return yield defer select go
" `arena` is contextual: a keyword only when it opens a block.
syntax match gossamerControl "\<arena\>\ze\s*{"

syntax keyword gossamerType bool char str
syntax keyword gossamerType i8 i16 i32 i64 i128 isize
syntax keyword gossamerType u8 u16 u32 u64 u128 usize
syntax keyword gossamerType f32 f64
syntax keyword gossamerType Arc Array BTreeMap BTreeSet Box Fn FnMut FnOnce
syntax keyword gossamerType HashMap HashSet JoinHandle Mutex Option Rc Receiver
syntax keyword gossamerType Result RwLock Sender String Vec Weak

syntax keyword gossamerBoolean true false
syntax keyword gossamerConstant None Some Ok Err

syntax match gossamerNumber "\<0x[0-9a-fA-F_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<0b[01_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<0o[0-7_]\+\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"
syntax match gossamerNumber "\<\d\+\%(\.\d\+\)\=\%([eE][+-]\=\d\+\)\=\%([iuf]\%(8\|16\|32\|64\|128\|size\)\)\=\>"

syntax region gossamerString start=+b\=r\?#*"+ end=+"#*+ contains=gossamerEscape
syntax region gossamerString start=+b\?"+ skip=+\\\\\|\\"+ end=+"+ contains=gossamerEscape
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
syntax match gossamerOperator "\(//\|/\*\)\@!/"
syntax match gossamerOperator "->"
syntax match gossamerOperator "=>"
syntax match gossamerOperator "::"

syntax match gossamerAttribute "#!\?\[.\{-}\]"
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
highlight default link gossamerEscape SpecialChar
highlight default link gossamerChar Character
highlight default link gossamerComment Comment
highlight default link gossamerBlockComment Comment
highlight default link gossamerTodo Todo
highlight default link gossamerOperator Operator
highlight default link gossamerAttribute PreProc
highlight default link gossamerMacro Macro
highlight default link gossamerFunction Function

let b:current_syntax = "gossamer"
