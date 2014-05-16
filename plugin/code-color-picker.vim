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

    class CodeColorPicker

      # match rgb(255, 255, 255) and rgba(24, 24, 24, 0.5) and #555 and #555555
      COLOR_REGEXP = %r{
                       (?<=rgb\()\s?(\d+,\s?){2}\d+\s?(?!=\))|
                       (?<=rgba\()\s?(\d+,\s?){3}[0-9]?(\.[0-9]{1,2})?\s?(?!=\))|
                       (?<=\#)[0-9a-f]{3,6}(?!=(\D|\W|\n|;))+
                     }xi

      COLOR_DECLARATION_REGEXP = Regexp.new(/rgb\(\s?(\d+,\s?){2}\d+\s?\)|rgba\(\s?(\d+,\s?){3}[0-9]?(\.[0-9]{1,2})?\s?\)|#[0-9a-f]+/i)

      RGB_MAX = 65535

      def initialize(selection_is_line=false)
        @is_line = selection_is_line
        get_selection
        if parse_selection
          trigger_chooser
          insert_sampled_color_text
        end
      end

      private

      def get_selection
        if @is_line
          @selection = VIM::Buffer.current.line
        else
          VIM::command 'normal gv"xy'
          VIM::command 'let cursor_pos = getpos(".")'
          VIM::command 'let cursor_pos[2] = cursor_pos[2] - 1'
          @selection = VIM::evaluate '@x'
        end
      end

      def parse_selection
        values = @selection[COLOR_REGEXP]
        @string_values = @selection[COLOR_DECLARATION_REGEXP]
        if values
          values = sanitize_values(values)
          @values = convert_8bit_to_16bit(values)
          true
        else
          VIM::command "call s:ColorPickerError('No suitable color codes found.')"
          false
        end
      end

      def sanitize_values(values)
        # reduce 4 and 5 digit hex values to 3
        values = values[0..2] if (values.length > 3 && values.length < 6 && values[','].nil?)
        if values[','].nil?
          # hex
          values = convert_hex_str_to_8bit(values)
        else
          # rgb|a
          values = convert_rgb_to_8bit(values)
        end
        values
      end

      def convert_hex_str_to_8bit(values)
        rgb = []
        if values.length == 3
          values.each_char do |c|
            rgb << (c.to_i(16) << 4 | c.to_i(16)) + 1
          end
        else
          rgb << (values[0..1].to_i(16)) + 1
          rgb << (values[2..3].to_i(16)) + 1
          rgb << (values[4..5].to_i(16)) + 1
        end
        rgba_dict(rgb)
      end

      def convert_rgb_to_8bit(values)
        rgba = []
        values.split(",").each_with_index do |v, i|
          if i < 3
            rgba << v.to_i(10) + 0
          else
            rgba << v.to_f
          end
        end
        rgba_dict(rgba)
      end

      def rgba_dict(rgb)
        (rgb.length == 3) ? Hash[[:r,:g,:b].zip(rgb)] : Hash[[:r,:g,:b,:a].zip(rgb)]
      end

      def convert_8bit_to_16bit(values)
        values.each do |k, v|
          unless k == :a
            _16bit = (v << 8) + 0
            values[k] = (_16bit > RGB_MAX) ? RGB_MAX : _16bit
          end
        end
      end

      def trigger_chooser
        `osascript -e 'tell app "Finder" to activate'`
        `osascript -e 'tell app "System Events" to keystroke "m" using {command down, option down}'`
        @sampled_colors = `osascript<<EOD
        tell app "Finder" to activate
        try
          tell app "Finder" to set testcolor to choose color default color {#{@values[:r]}, #{@values[:g]}, #{@values[:b]}}
        on error errMsg
          return "#{@values[:r]}, #{@values[:g]}, #{@values[:b]}"
        end try
    EOD`.chomp!
        #`osascript -e 'tell app "Finder" to set collapsed of windows to false'`
        `osascript -e 'tell app "System Events" to keystroke "h" using command down'`
      end

      def insert_sampled_color_text
        new_colors = map_sampled_color_format
        if @is_line
          @selection.sub! @string_values, new_colors
          #puts "HEY THERE"
          #puts @string_values
          #exit
          VIM::Buffer.current.line = @selection
        else
          VIM::command "let @x = '#{new_colors}'"
          VIM::command 'normal gvd'
          VIM::command 'call setpos(".", cursor_pos)'
          VIM::command 'normal "xp'
        end
      end

      def map_sampled_color_format
        #if @selection["#"]
        if @selection[/#[0-9a-fA-F]+/]
          convert_16bit_to_hex
        else
          convert_16bit_to_rgb
        end
      end

      def convert_16bit_to_hex
        values = @sampled_colors.split(",")
        hex_str = ""
        #TODO works in IRB not here
        #values.each { |v| hex_str << (("%02c" % (v.to_i >> 8).to_s(16)).gsub! " ", "0") }
        values.each do |v|
          _8bit = (v.to_i >> 8).to_s(16)
          _8bit = (_8bit.length == 1) ? "0#{_8bit}" : _8bit
          hex_str << _8bit
        end
        hex_str = reduce_hex(hex_str)
        "##{hex_str}"
      end

      def reduce_hex(hex_str)
        new_hex_str = ""
        hex_str.split('').each_with_index do |c, i|
          if i % 2 == 0 && hex_str[i + 1] == c
            new_hex_str << c
          end
        end
        (new_hex_str.length == 3) ? new_hex_str : hex_str
      end

      def convert_16bit_to_rgb
        values = @sampled_colors.split(",").map { |v| v.to_i >> 8 }
        if @values[:a]
          sprintf("rgba(%d, %d, %d, %1.1f)", values[0], values[1], values[2], @values[:a])
        else
          sprintf("rgb(%d, %d, %d)", values[0], values[1], values[2])
        end
      end

    end

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
