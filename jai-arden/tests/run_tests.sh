#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUTS_DIR="$TESTS_DIR/inputs"
EXPECTED_DIR="$TESTS_DIR/expected"
MAIN="$TESTS_DIR/../main"

# Check if main binary exists
if [ ! -f "$MAIN" ]; then
    echo -e "${RED}Error: ./main binary not found at $MAIN${NC}"
    exit 1
fi

# Track results
passed=0
failed=0
failed_tests=()

# Get test pattern from arguments
pattern="${1:-}"
update_mode=false

if [ "$pattern" = "--update" ]; then
    update_mode=true
    pattern=""
fi

# Process all matching test files
shopt -s nullglob
if [ -z "$pattern" ]; then
    input_files=("$INPUTS_DIR"/*.arden)
else
    input_files=("$INPUTS_DIR"/*"$pattern"*.arden)
fi

for input_file in "${input_files[@]}"; do
    if [ ! -f "$input_file" ]; then
        continue
    fi

    test_name=$(basename "$input_file" .arden)
    expected_file="$EXPECTED_DIR/$test_name.expected"

    if [ "$update_mode" = true ]; then
        # Save current output
        echo -n "Updating $test_name... "
        temp_output=$(mktemp)
        "$MAIN" "$input_file" > "$temp_output" 2>&1
        sed '/^JSON:/d; /^AST:/,/^}$/d' "$temp_output" > "$expected_file"
        rm "$temp_output"
        echo -e "${GREEN}saved${NC}"
        continue
    fi

    # Run test
    temp_output=$(mktemp)
    "$MAIN" "$input_file" > "$temp_output" 2>&1
    exit_code=$?

    # Extract only interpreter output (skip JSON and AST)
    temp_filtered=$(mktemp)
    sed -n '/^JSON:/d; /^AST:/,/^}$/d; p' "$temp_output" > "$temp_filtered"

    # Check if expected file exists
    if [ ! -f "$expected_file" ]; then
        echo -e "${RED}✗ FAIL${NC} $test_name (expected file not found)"
        failed=$((failed + 1))
        failed_tests+=("$test_name")
        rm "$temp_output" "$temp_filtered"
        continue
    fi

    # Compare outputs
    if diff -q "$expected_file" "$temp_filtered" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} $test_name"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ FAIL${NC} $test_name"
        failed=$((failed + 1))
        failed_tests+=("$test_name")
        # Show diff
        echo "--- Expected:"
        head -5 "$expected_file" | sed 's/^/  /'
        echo "--- Got:"
        head -5 "$temp_filtered" | sed 's/^/  /'
        echo ""
    fi

    rm "$temp_output" "$temp_filtered"
done

# Check if any tests were run (skip in update mode)
if [ "$update_mode" = false ] && [ $((passed + failed)) -eq 0 ]; then
echo -e "${YELLOW}No test files matching pattern: $pattern${NC}"
exit 1
fi

if [ "$update_mode" = true ]; then
echo "Update complete!"
exit 0
fi

# Summary
echo ""
echo "========================================"
echo -n "Results: "
if [ $passed -gt 0 ]; then
    echo -n -e "${GREEN}$passed passed${NC}"
fi
if [ $failed -gt 0 ]; then
    [ $passed -gt 0 ] && echo -n ", "
    echo -n -e "${RED}$failed failed${NC}"
fi
echo ""
echo "========================================"

# Print failed test names
if [ $failed -gt 0 ]; then
    echo "Failed tests:"
    for test in "${failed_tests[@]}"; do
        echo "  - $test"
    done
fi

# Exit code
[ $failed -eq 0 ] && exit 0 || exit 1
