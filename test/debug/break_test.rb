# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Tests adding breakpoints to methods
  #
  class BreakAtMethodsTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def self.a
         4|       "hello"
         5|     end
         6|
         7|     def b(n)
         8|       2.times do
         9|         n
        10|       end
        11|     end
        12|   end
        13|   module Baz
        14|     def self.c
        15|       1
        16|     end
        17|   end
        18|   Bar.a
        19|   bar = Bar.new
        20|   bar.b(1)
        21|   Baz.c
        22| end
      RUBY
    end

    def test_break_with_namespaced_instance_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar#b'
        assert_line_text(/#0  BP - Method \(pending\)  Foo::Bar#b/)
        type 'continue'
        assert_line_num 8
        type 'quit!'
      end
    end

    def test_break_with_namespaced_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.a'
        type 'continue'
        assert_line_num 4
        type 'quit!'
      end
    end

    def test_break_with_namespaced_module_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'continue'
        assert_line_num 15
        type 'quit!'
      end
    end

    def test_break_with_a_method_does_not_stop_at_blocks_in_the_method
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 8
        type 'break 9'
        type 'continue'
        assert_line_num 9
        type 'quit!'
      end
    end

    def test_debugger_rejects_duplicated_method_breakpoints
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'break Foo::Baz.c'
        assert_line_text(/duplicated breakpoint/)
        type 'continue'
        assert_line_num 15
        type 'continue'
      end
    end

    def test_break_command_isnt_repeatable
      debug_code(program) do
        type 'break Foo::Baz.c'
        type ''
        assert_no_line_text(/duplicated breakpoint/)
        type 'quit!'
      end
    end
  end

  class BreakAtClassMethodsTest < TestCase
    def program
      <<~RUBY
     1| class A
     2|   def self.bar
     3|   end
     4| end
     5|
     6| class B < A
     7| end
     8|
     9| class C < A
    10| end
    11|
    12| binding.b
    13|
    14| B.bar
    15| binding.b
      RUBY
    end

    def test_debugger_stops_when_target_class_calls_the_parent_method
      debug_code(program) do
        type "c"
        type "b B.bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  B.bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_class_calls_the_parent_method
      debug_code(program) do
        type "c"
        type "b C.bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  C.bar/)
        type "c"
      end
    end
  end

  class BreakAtInstanceMethodsTest < TestCase
    def program
      <<~RUBY
     1|  class A
     2|    def bar
     3|    end
     4|  end
     5|
     6|  class B < A
     7|  end
     8|
     9|  class C < A
    10| end
    11|
    12| b = B.new
    13| c = C.new
    14|
    15| binding.b
    16|
    17| b.bar
    18| binding.b
      RUBY
    end

    def test_debugger_stops_when_target_class_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b B#bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  B#bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_class_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b C#bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  C#bar/)
        type "c"
      end
    end

    def test_debugger_stops_when_target_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b b.bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  b.bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b c.bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  b.bar/)
        type "c"
      end
    end
  end

  class BreakAtCMethodsTest < TestCase
    def program
      <<~RUBY
     1| a = 1
     2|
     3| a.abs
     4| a.div(1)
     5| a.times { false }
      RUBY
    end

    def test_debugger_stops_when_the_c_method_is_called
      debug_code(program) do
        type 'b Integer#abs'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#abs at <internal:')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end

    def test_debugger_passes_required_argument_correctly
      debug_code(program) do
        type 'b Integer#div'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#div at')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end

    def test_debugger_passes_block_argument_correctly
      debug_code(program) do
        type 'b Integer#times'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#times at')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end
  end

  class BreakWithCommandTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2|   "foo"
     3| end
     4|
     5| s = "a"
     6|
     7| foo
     8|
     9| "for another bp to stop"
    10| __END__
      RUBY
    end

    def test_break_command_executes_pre_option_and_stops_with_line_bp
      debug_code(program) do
        type 'break 6 pre: p s*10'
        type 'c'
        assert_line_text(/aaaaaaaaaa/)
        type 'c'
      end
    end

    def test_break_command_executes_pre_option_and_stops_with_method_bp
      debug_code(program) do
        type 'break Object#foo pre: p "foobar"'
        type 'c'
        assert_line_text(/foobar/)
        type 'c'
      end
    end

    def test_break_command_executes_do_option_and_continues_with_line_bp
      debug_code(program) do
        type 'break 6 do: p s*10'
        type 'break 9'
        type 'c'
        assert_line_text(/aaaaaaaaaa/)
        type 'c'
      end
    end

    def test_break_command_executes_do_option_and_continues_with_method_bp
      debug_code(program) do
        type 'break Object#foo do: p "foobar"'
        type 'break 9'
        type 'c'
        assert_line_text(/foobar/)
        type 'c'
      end
    end
  end

  #
  # Tests adding breakpoints to empty methods
  #
  class BreakAtEmptyMethodsTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def a
         4|     end
         5|
         6|     def b(n)
         7|
         8|     end
         9|     def self.c; end
        10|   end
        11|   bar = Bar.new
        12|   bar.a
        13|   bar.b(1)
        14|   Bar.c
        15| end
      RUBY
    end

    def test_break_with_instance_method_stops_at_correct_place_a
      debug_code(program) do
        type 'break Foo::Bar#a'
        type 'continue'
        assert_line_num 3
        type 'quit!'
      end
    end

    def test_break_with_instance_method_stops_at_correct_place_b
      # instance method #b has extra empty line intentionally
      # to test lineno 8 is not displayed.
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 6
        type 'quit!'
      end
    end

    def test_break_with_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.c'
        type 'continue'
        assert_line_num 9
        type 'quit!'
      end
    end
  end

  #
  # Tests adding breakpoints to lines
  #
  class BreakAtLinesTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def self.a
         4|       "hello"
         5|     end
         6|
         7|     def b(n)
         8|       2.times do
         9|         n
        10|       end
        11|     end
        12|   end
        13|   module Baz
        14|     def self.c
        15|       d = 1
        16|     end
        17|   end
        18|   Bar.a
        19|   bar = Bar.new
        20|   bar.b(1)
        21|   Baz.c
        22| end
      RUBY
    end

    def test_break_stops_at_correct_place_when_breakpoint_set_in_a_regular_line
      debug_code(program) do
        type 'break 4'
        assert_line_text(/#0  BP - Line  .*\.rb:4 \(call\)/)
        type 'continue'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end

    def test_break_stops_at_correct_place_when_breakpoint_set_in_empty_line
      debug_code(program) do
        type 'break 6'
        type 'continue'
        assert_line_num 7
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_for_repeated_iterations
      debug_code(program) do
        type 'break 9'
        type 'continue'
        assert_line_num 9
        type 'continue'
        assert_line_num 9
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_if_condition_is_true
      debug_code(program) do
        type 'break if: n == 1'
        assert_line_text(/#0  BP - Check  n == 1/)
        type 'continue'
        assert_line_num 8
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_at_specified_location_if_condition_is_true
      debug_code(program) do
        type 'break 16 if: d == 1'
        assert_line_text(/#0  BP - Line  .*\.rb:16 \(return\) if: d == 1/)
        type 'continue'
        assert_line_num 16
        type 'quit'
        type 'y'
      end
    end

    def test_debugger_rejects_duplicated_line_breakpoints
      debug_code(program) do
        type 'break 19'
        type 'break 18'
        type 'break 18'
        assert_line_text(/duplicated breakpoint:/)
        type 'continue'
        assert_line_num 18
        type 'continue'
        assert_line_num 19
        type 'quit!'
      end
    end

    def test_break_with_colon_between_file_and_line_stops_at_correct_place
      debug_code(program) do
        type "b #{temp_file_path}:4"
        assert_line_text(/\#0  BP \- Line  .*/)
        type 'c'
        assert_line_num 4
        type 'q!'
      end
    end

    def test_break_with_space_between_file_and_line_stops_at_correct_place
      debug_code(program) do
        type "b #{temp_file_path} 9"
        assert_line_text(/\#0  BP \- Line  .*/)
        type 'c'
        assert_line_num 9
        type 'q!'
      end
    end
  end
end
