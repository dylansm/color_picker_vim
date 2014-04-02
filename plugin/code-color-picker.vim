"map function to a key sequence in visual mode
vmap <C-H> :call ColorPicker()<CR><CR>
nnoremap <C-H> :call LineColorPicker()<CR><CR>

function s:ColorPickerRubyWarning()
  echohl WarningMsg
  echo "Vim color-picker requires Vim to be compiled with Ruby support!"
  echohl none
endfunction

function s:ColorPickerError(msg)
  echohl WarningMsg
  let msg = a:msg
  echo msg
  echohl none
endfunction

function! LineColorPicker()
  if has('ruby')
    ruby <<EOF
    #require 'code_color_picker'
    require File.expand_path('../CodeColorPicker/ruby/code_color_picker', __FILE__)
    color_chooser = CodeColorPicker.new(true)
EOF
  else
    call s:ColorPickerRubyWarning()
  end

endfunction

function! ColorPicker()
  if has('ruby')
    ruby <<EOF
    require 'code_color_picker'
    color_chooser = CodeColorPicker.new()
EOF
  else
    call s:ColorPickerRubyWarning()
  end
endfunction
