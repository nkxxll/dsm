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

    def test_type_error_concat_number_string(self):
        ast = parse('write 5 & "hello";')
        with pytest.raises(TypeError):
            interpret(ast)


class TestLists:
    """Tests for list operations"""

    def test_list_of_numbers(self):
        ast = parse("write [1, 2, 3];")
        output = capture_output(ast)
        assert output.strip() == "[1, 2, 3]"

    def test_list_of_strings(self):
        ast = parse('write ["a", "b"];')
        output = capture_output(ast)
        assert output.strip() == "[a, b]"

    def test_empty_list(self):
        ast = parse("write [];")
        output = capture_output(ast)
        assert output.strip() == "[]"

    def test_list_with_mixed_types(self):
        ast = parse('x := "hello"; write [1, 2, 3, x];')
        output = capture_output(ast)
        assert output.strip() == "[1, 2, 3, hello]"

    def test_list_with_expressions(self):
        ast = parse("write [1 + 1, 2 * 3];")
        output = capture_output(ast)
        assert output.strip() == "[2, 6]"
