"""Pytest tests for the interpreter"""

import pytest
from io import StringIO
import sys
from parser import parse
from interpreter import interpret


def capture_output(ast):
    """Helper to capture stdout from interpreter"""
    old_stdout = sys.stdout
    sys.stdout = StringIO()
    try:
        interpret(ast)
        output = sys.stdout.getvalue()
    finally:
        sys.stdout = old_stdout
    return output


class TestBasicOutput:
    """Tests for basic output operations"""

    def test_simple_number_write(self):
        ast = parse("write 42;")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_simple_string_write(self):
        ast = parse('write "hello";')
        output = capture_output(ast)
        assert output.strip() == "hello"

    def test_boolean_write(self):
        ast = parse("write true; write false;")
        output = capture_output(ast)
        assert output.strip() == "true\nfalse"

    def test_null_write(self):
        ast = parse("write null;")
        output = capture_output(ast)
        assert output.strip() == "null"

    def test_float_number(self):
        ast = parse("write 3.14;")
        output = capture_output(ast)
        assert output.strip() == "3.14"


class TestArithmetic:
    """Tests for arithmetic operations"""

    def test_arithmetic_plus(self):
        ast = parse("write 5 + 3;")
        output = capture_output(ast)
        assert output.strip() == "8"

    def test_arithmetic_minus(self):
        ast = parse("write 10 - 2;")
        output = capture_output(ast)
        assert output.strip() == "8"

    def test_arithmetic_times(self):
        ast = parse("write 4 * 3;")
        output = capture_output(ast)
        assert output.strip() == "12"

    def test_arithmetic_divide(self):
        ast = parse("write 20 / 4;")
        output = capture_output(ast)
        assert output.strip() == "5"

    def test_arithmetic_power(self):
        ast = parse("write 2 ^ 3;")
        output = capture_output(ast)
        assert output.strip() == "8"

    def test_operator_precedence(self):
        # 2 + 3 * 4 should be 2 + 12 = 14
        ast = parse("write 2 + 3 * 4;")
        output = capture_output(ast)
        assert output.strip() == "14"

    def test_complex_expression(self):
        ast = parse("write (1 + 5) / 2.5 * 2.3;")
        output = capture_output(ast)
        assert output.strip() == "5.52"


class TestStringOperations:
    """Tests for string operations"""

    def test_string_concatenation(self):
        ast = parse('write "Hello " & "World";')
        output = capture_output(ast)
        assert output.strip() == "Hello World"

    def test_mixed_arithmetic_and_string(self):
        ast = parse('write "Result: " & "42";')
        output = capture_output(ast)
        assert output.strip() == "Result: 42"


class TestStatementSequences:
    """Tests for multiple statements"""

    def test_multiple_statements(self):
        ast = parse("write 1; write 2; write 3;")
        output = capture_output(ast)
        assert output.strip() == "1\n2\n3"

    def test_parentheses_precedence(self):
        ast = parse("write (2 + 3) * 4;")
        output = capture_output(ast)
        assert output.strip() == "20"


class TestAssignment:
    """Tests for variable assignment"""

    def test_assignment_with_number(self):
        ast = parse("x := 42; write x;")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_assignment_with_string(self):
        ast = parse('msg := "Hello"; write msg;')
        output = capture_output(ast)
        assert output.strip() == "Hello"

    def test_assignment_with_arithmetic(self):
        ast = parse("result := 10 + 5 * 2; write result;")
        output = capture_output(ast)
        assert output.strip() == "20"

    def test_multiple_assignments(self):
        ast = parse("x := 10; y := 20; z := x + y; write z;")
        output = capture_output(ast)
        assert output.strip() == "30"

    def test_assignment_with_concatenation(self):
        ast = parse('greeting := "Hello "; name := "World"; write greeting & name;')
        output = capture_output(ast)
        assert output.strip() == "Hello World"


class TestErrorHandling:
    """Tests for error conditions"""

    def test_division_by_zero(self):
        ast = parse("write 10 / 0;")
        with pytest.raises(ZeroDivisionError):
            interpret(ast)

    def test_undefined_variable(self):
        ast = parse("write undefined_var;")
        with pytest.raises(NameError):
            interpret(ast)

    def test_type_error_add_string_number(self):
        ast = parse('write "hello" + 5;')
        with pytest.raises(TypeError):
            interpret(ast)

    def test_concat_number_string(self):
        ast = parse('write 5 & "hello";')
        output = capture_output(ast)
        assert output.strip() == "5hello"
    
    def test_concat_string_number(self):
        ast = parse('write "hello" & 5;')
        output = capture_output(ast)
        assert output.strip() == "hello5"





class TestListOperations:
    """Tests for list operations"""

    def test_list_literal(self):
        ast = parse("write [1, 2, 3];")
        output = capture_output(ast)
        assert output.strip() == "[1, 2, 3]"

    def test_list_with_strings(self):
        ast = parse('write ["a", "b", "c"];')
        output = capture_output(ast)
        assert output.strip() == "[a, b, c]"

    def test_list_with_mixed_types(self):
        ast = parse('x := "hello"; write [1, x, true];')
        output = capture_output(ast)
        assert output.strip() == "[1, hello, true]"

    def test_empty_list(self):
        ast = parse("write [];")
        output = capture_output(ast)
        assert output.strip() == "[]"


class TestUppercase:
    """Tests for UPPERCASE function"""

    def test_uppercase_string(self):
        ast = parse('write uppercase "hello";')
        output = capture_output(ast)
        assert output.strip() == "HELLO"

    def test_uppercase_string_with_mixed_case(self):
        ast = parse('write uppercase "HeLLo WoRLD";')
        output = capture_output(ast)
        assert output.strip() == "HELLO WORLD"

    def test_uppercase_list_of_strings(self):
        ast = parse('write uppercase ["hello", "world"];')
        output = capture_output(ast)
        assert output.strip() == "[HELLO, WORLD]"

    def test_uppercase_with_variable(self):
        ast = parse('msg := "test"; write uppercase msg;')
        output = capture_output(ast)
        assert output.strip() == "TEST"

    def test_uppercase_non_string_raises_error(self):
        ast = parse("write uppercase 42;")
        with pytest.raises(TypeError):
            interpret(ast)


class TestMaximum:
    """Tests for MAXIMUM function"""

    def test_maximum_simple_list(self):
        ast = parse("write maximum [1, 5, 3];")
        output = capture_output(ast)
        assert output.strip() == "5"

    def test_maximum_with_floats(self):
        ast = parse("write maximum [1.5, 5.2, 3.8];")
        output = capture_output(ast)
        assert output.strip() == "5.2"

    def test_maximum_with_variable(self):
        ast = parse("nums := [10, 20, 15]; write maximum nums;")
        output = capture_output(ast)
        assert output.strip() == "20"

    def test_maximum_single_element(self):
        ast = parse("write maximum [42];")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_maximum_empty_list_raises_error(self):
        ast = parse("write maximum [];")
        with pytest.raises(TypeError):
            interpret(ast)

    def test_maximum_non_numeric_list_raises_error(self):
        ast = parse('write maximum ["a", "b"];')
        with pytest.raises(TypeError):
            interpret(ast)


class TestAverage:
    """Tests for AVERAGE function"""

    def test_average_simple_list(self):
        ast = parse("write average [1, 2, 3];")
        output = capture_output(ast)
        assert output.strip() == "2"

    def test_average_with_floats(self):
        ast = parse("write average [1.5, 2.5, 3.0];")
        output = capture_output(ast)
        # (1.5 + 2.5 + 3.0) / 3 = 7 / 3 = 2.333...
        result = float(output.strip())
        assert abs(result - 2.333333) < 0.001

    def test_average_with_variable(self):
        ast = parse("nums := [10, 20, 30]; write average nums;")
        output = capture_output(ast)
        assert output.strip() == "20"

    def test_average_single_element(self):
        ast = parse("write average [42];")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_average_empty_list_raises_error(self):
        ast = parse("write average [];")
        with pytest.raises(TypeError):
            interpret(ast)


class TestIncrease:
    """Tests for INCREASE function"""

    def test_increase_simple_list(self):
        ast = parse("write increase [1, 2, 3];")
        output = capture_output(ast)
        assert output.strip() == "[1, 1]"

    def test_increase_with_floats(self):
        ast = parse("write increase [1.0, 2.5, 5.5];")
        output = capture_output(ast)
        # [2.5 - 1.0, 5.5 - 2.5] = [1.5, 3.0]
        assert output.strip() == "[1.5, 3]"

    def test_increase_with_negatives(self):
        ast = parse("write increase [5, 3, 7, 2];")
        output = capture_output(ast)
        # [3-5, 7-3, 2-7] = [-2, 4, -5]
        assert output.strip() == "[-2, 4, -5]"

    def test_increase_single_element(self):
        ast = parse("write increase [42];")
        output = capture_output(ast)
        assert output.strip() == "[]"

    def test_increase_two_elements(self):
        ast = parse("write increase [10, 15];")
        output = capture_output(ast)
        assert output.strip() == "[5]"

    def test_increase_empty_list(self):
        ast = parse("write increase [];")
        output = capture_output(ast)
        assert output.strip() == "[]"


class TestIfStatement:
    """Tests for IF/THEN/ELSE statements"""

    def test_if_true(self):
        ast = parse("if true then write 42; endif;")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_if_false(self):
        ast = parse("if false then write 42; endif;")
        output = capture_output(ast)
        assert output.strip() == ""

    def test_if_true_else(self):
        ast = parse("if true then write 1; else write 2; endif;")
        output = capture_output(ast)
        assert output.strip() == "1"

    def test_if_false_else(self):
        ast = parse("if false then write 1; else write 2; endif;")
        output = capture_output(ast)
        assert output.strip() == "2"

    def test_if_with_number_condition_nonzero(self):
        ast = parse("if 42 then write 1; endif;")
        output = capture_output(ast)
        assert output.strip() == "1"

    def test_if_with_number_condition_zero(self):
        ast = parse("if 0 then write 1; endif;")
        output = capture_output(ast)
        assert output.strip() == ""

    def test_if_with_variable_condition(self):
        ast = parse("x := 10; if x then write x; endif;")
        output = capture_output(ast)
        assert output.strip() == "10"

    def test_if_nested(self):
        ast = parse("if true then if true then write 42; endif; endif;")
        output = capture_output(ast)
        assert output.strip() == "42"

    def test_if_multiple_statements(self):
        ast = parse("if true then write 1; write 2; endif;")
        output = capture_output(ast)
        assert output.strip() == "1\n2"


class TestForLoop:
    """Tests for FOR loops"""

    def test_for_loop_simple(self):
        ast = parse("for i in [1, 2, 3] do write i; enddo;")
        output = capture_output(ast)
        assert output.strip() == "1\n2\n3"

    def test_for_loop_with_strings(self):
        ast = parse('for name in ["a", "b", "c"] do write name; enddo;')
        output = capture_output(ast)
        assert output.strip() == "a\nb\nc"

    def test_for_loop_accumulation(self):
        ast = parse("sum := 0; for i in [1, 2, 3] do sum := sum + i; enddo; write sum;")
        output = capture_output(ast)
        assert output.strip() == "6"

    def test_for_loop_empty_list(self):
        ast = parse("for i in [] do write i; enddo;")
        output = capture_output(ast)
        assert output.strip() == ""

    def test_for_loop_with_variable(self):
        ast = parse("nums := [10, 20, 30]; for x in nums do write x; enddo;")
        output = capture_output(ast)
        assert output.strip() == "10\n20\n30"

    def test_for_loop_nested(self):
        ast = parse(
            "for i in [1, 2] do for j in [10, 20] do write i & j; enddo; enddo;"
        )
        output = capture_output(ast)
        assert output.strip() == "110\n120\n210\n220"


class TestTraceStatement:
    """Tests for TRACE statement"""

    def test_trace_simple_number(self):
        ast = parse("trace 42;")
        output = capture_output(ast)
        # Line number is extracted from TRACE token position (line 1)
        assert output.strip() == "Line 1: 42"

    def test_trace_string(self):
        ast = parse('trace "hello";')
        output = capture_output(ast)
        assert output.strip() == "Line 1: hello"

    def test_trace_expression(self):
        ast = parse("trace 5 + 3;")
        output = capture_output(ast)
        assert output.strip() == "Line 1: 8"

    def test_trace_with_variable(self):
        ast = parse("x := 42; trace x;")
        output = capture_output(ast)
        # trace is on line 1
        assert output.strip() == "Line 1: 42"

    def test_trace_concatenation(self):
        ast = parse('trace "Result: " & "42";')
        output = capture_output(ast)
        assert output.strip() == "Line 1: Result: 42"

    def test_trace_list(self):
        ast = parse("trace [1, 2, 3];")
        output = capture_output(ast)
        assert output.strip() == "Line 1: [1, 2, 3]"

    def test_multiple_trace_statements_on_different_lines(self):
        ast = parse("trace 10;\ntrace 20;\ntrace 30;")
        output = capture_output(ast)
        lines = output.strip().split("\n")
        assert len(lines) == 3
        assert lines[0] == "Line 1: 10"
        assert lines[1] == "Line 2: 20"
        assert lines[2] == "Line 3: 30"


class TestTimeOperations:
    """Tests for time operations"""

    def test_time_string_to_float_hh_mm(self):
        """Test conversion of HH:MM format to float"""
        from interpreter import time_string_to_float
        timestamp = time_string_to_float("14:30")
        # Should return a valid timestamp for today at 14:30
        assert isinstance(timestamp, float)
        # Check that it's roughly today's timestamp
        import time as time_module
        now_timestamp = time_module.time()
        # Timestamp should be within 24 hours of now
        assert abs(now_timestamp - timestamp) < 86400

    def test_time_string_to_float_hh_mm_ss(self):
        """Test conversion of HH:MM:SS format to float"""
        from interpreter import time_string_to_float
        timestamp = time_string_to_float("14:30:45")
        # Should return a valid timestamp for today at 14:30:45
        assert isinstance(timestamp, float)

    def test_timestamp_to_iso_string(self):
        """Test conversion of timestamp to ISO string"""
        from interpreter import timestamp_to_iso_string
        import time as time_module
        # Use current time to avoid timezone issues
        now_timestamp = time_module.time()
        iso_string = timestamp_to_iso_string(now_timestamp)
        # Check format is ISO 8601: YYYY-MM-DDTHH:MM:SSZ
        assert isinstance(iso_string, str)
        assert "T" in iso_string
        assert iso_string.endswith("Z")
        assert len(iso_string) == 20  # YYYY-MM-DDTHH:MM:SSZ is 20 chars

    def test_timestamp_to_iso_string_with_seconds(self):
        """Test conversion of timestamp to ISO string with seconds"""
        from interpreter import timestamp_to_iso_string
        import time as time_module
        # Use current time
        now_timestamp = time_module.time()
        iso_string = timestamp_to_iso_string(now_timestamp)
        # Verify it contains date and time components
        parts = iso_string.split("T")
        assert len(parts) == 2
        assert len(parts[0]) == 10  # YYYY-MM-DD
        assert parts[1].endswith("Z")
        time_part = parts[1][:-1]  # Remove the Z
        assert len(time_part) == 8  # HH:MM:SS

    def test_time_string_invalid_format_raises_error(self):
        """Test that invalid time format raises ValueError"""
        from interpreter import time_string_to_float
        with pytest.raises(ValueError):
            time_string_to_float("25:00")

    def test_time_string_invalid_format_too_many_parts(self):
        """Test that time with too many parts raises error"""
        from interpreter import time_string_to_float
        with pytest.raises(ValueError):
            time_string_to_float("10:20:30:45")

    def test_time_string_invalid_minutes(self):
        """Test that invalid minutes raise error"""
        from interpreter import time_string_to_float
        with pytest.raises(ValueError):
            time_string_to_float("10:70")

    def test_time_string_invalid_seconds(self):
        """Test that invalid seconds raise error"""
        from interpreter import time_string_to_float
        with pytest.raises(ValueError):
            time_string_to_float("10:20:75")
