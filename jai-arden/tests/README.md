# DSM Test Suite

A comprehensive automated test suite for the DSM (Data Stream Manipulation) language interpreter, written in Jai.

## Quick Start

```bash
cd /home/nkxxll/git/dsm/jai-arden/tests

# Run all tests
bash run_tests.sh

# Run tests matching a pattern
bash run_tests.sh for_loop
bash run_tests.sh where

# Update expected outputs (after code changes)
bash run_tests.sh --update
```

## Test Structure

```
tests/
├── run_tests.sh          # Test runner script
├── inputs/               # Input .arden files
│   ├── simple_write.arden
│   ├── for_loop_simple.arden
│   └── ...
├── expected/             # Expected output files
│   ├── simple_write.expected
│   ├── for_loop_simple.expected
│   └── ...
├── README.md             # This file
└── TEST_SUMMARY.md       # Detailed test list
```

## How It Works

1. **Input Files** (`tests/inputs/*.arden`)
   - Each `.arden` file contains DSM language code
   - Files are named descriptively (e.g., `for_loop_simple.arden`)

2. **Test Execution** (`run_tests.sh`)
   - Runs the DSM interpreter on each input file
   - Captures output to temporary file
   - Compares against expected output

3. **Expected Output** (`tests/expected/*.expected`)
   - Pre-computed correct output for each test
   - Automatically generated or manually updated
   - Updated with `--update` flag

## Command Examples

### Run All Tests
```bash
bash run_tests.sh
```
Output:
```
✓ PASS simple_write
✓ PASS for_loop_simple
✗ FAIL some_broken_test
...
Results: 32 passed, 1 failed
```

### Run Specific Tests
```bash
# Run tests matching "for_loop"
bash run_tests.sh for_loop

# Run tests matching "where"
bash run_tests.sh where

# Run tests matching exact name
bash run_tests.sh simple_write
```

### Update Expected Outputs
After making interpreter changes:
```bash
bash run_tests.sh --update
```

This regenerates all `.expected` files with current output.

## Adding New Tests

1. Create input file:
   ```bash
   echo 'WRITE "test";' > tests/inputs/my_test.arden
   ```

2. Generate expected output:
   ```bash
   bash run_tests.sh --update
   ```

3. Run the test:
   ```bash
   bash run_tests.sh my_test
   ```

## Test Coverage

34 comprehensive tests covering:
- ✓ Basic I/O and arithmetic
- ✓ Variables and assignments
- ✓ Lists and aggregations
- ✓ Conditionals (IF/ELSE)
- ✓ Loops (FOR)
- ✓ String operations
- ✓ WHERE filtering
- ✓ Type checking
- ✓ Time/Date operations
- ✓ Range operations
- ✓ Operator precedence

See `TEST_SUMMARY.md` for complete list.

## Test Output Format

Each test produces:
```
JSON: [tokens...]
AST: {parsed abstract syntax tree}
{interpreter output}
```

Only the interpreter output is compared in tests.

## Exit Codes

```
0 - All tests passed
1 - One or more tests failed / No tests found
```

## Debugging Failed Tests

When a test fails, the diff output shows:
```
--- Expected:
  line 1
  line 2
  
--- Got:
  different output
  ...
```

Compare the test input with the diff to identify the issue.
