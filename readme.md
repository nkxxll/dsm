# DSM: Domain Specific Languages for Medical Lecture Code

## Overview

DSM (Domain Specific Languages for Medical Lecture Code) is an educational project designed to explore the concepts of Domain Specific Languages (DSLs) through the lens of medical applications, specifically inspired by formalisms like Arden Syntax. This project provides multiple implementations of tokenizers, parsers, and interpreters across different programming languages, demonstrating various approaches to DSL development.

The primary goal is to offer a comprehensive understanding of how DSLs are constructed and processed, from lexical analysis to semantic interpretation, with a focus on robust error handling and practical application in a medical context.

## Features

-   **Multi-language Implementations:** Provides complete tokenizer, parser, and interpreter implementations in:
    *   **OCaml:** A robust, functional approach focusing on clear data structures and compilation-friendly design. Features graceful error handling that returns `unit` for invalid inputs, ensuring interpreter continuation rather than crashes.
    *   **Python (Lark Parser):** Utilizes the Lark parsing library to demonstrate rapid DSL prototyping and parsing in Python, possibly for an "ICE" language.
    *   **Zig:** Offers a low-level, high-performance perspective on building DSL components.
-   **Educational Focus:** Designed as lecture code to illustrate fundamental computer science concepts in DSL design.
-   **Medical Context:** Examples and design considerations are rooted in medical lecture scenarios, potentially leveraging concepts from Arden Syntax for clinical decision support.
-   **Modular Design:** Components for tokenizing, parsing, and interpreting are separated for clarity and reusability.

## Technologies Used

-   **OCaml:**
    -   Dune (build system)
    -   Angstrom (parsing combinators)
    -   `ppx_expect` (testing)
-   **Python:**
    -   Lark (parsing library)
    -   pytest (testing)
-   **Zig:**
    -   Zig build system

## Project Structure

The project is organized into several key directories:

-   `bin/`: Executable OCaml code.
-   `lib/`: Core OCaml library code, including the tokenizer, parser, and interpreter for the primary DSL.
-   `lemon/`: Contains a Lemon parser generator setup, likely another parsing experiment.
-   `lark_parser/`: Python implementation using the Lark parsing library.
-   `zig_tokenizer/`: Zig implementation of tokenizer, parser, and interpreter components.
-   `llm/`: Contains documentation and notes, potentially generated or refined using LLMs, detailing specific development tasks (e.g., error handling refinements).
-   `test/`: Unit tests for various components.

## Installation

### OCaml Component

1.  **Install OCaml and Dune:**
    If you don't have OCaml and Dune installed, you can set them up using `opam`:
    ```bash
    sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)
    opam init
    opam install dune
    ```
2.  **Build the Project:**
    Navigate to the project root and run:
    ```bash
    dune build
    ```

### Python Component

1.  **Install `uv` (recommended) or `pip`:**
    ```bash
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```
2.  **Install Dependencies:**
    Navigate to `lark_parser/` and install required Python packages:
    ```bash
    cd lark_parser
    uv sync
    # or using pip
    # pip install -r requirements.txt
    ```

### Zig Component

1.  **Install Zig:**
    Follow the instructions on the [official Zig website](https://ziglang.org/download/).
2.  **Build the Project:**
    Navigate to `zig_tokenizer/` and run:
    ```bash
    cd zig_tokenizer
    zig build
    ```

## Usage

### OCaml Interpreter

After building the OCaml component, you can run the interpreter from the project root:

```bash
dune exec bin/main.exe -- <your-dsl-file.dsm>
```
*(Replace `<your-dsl-file.dsm>` with your DSL input file.)*

### Python Interpreter

To run the Python-based interpreter:

```bash
cd lark_parser
python main.py <your-ice-file.ice>
```
*(Replace `<your-ice-file.ice>` with your ICE language input file.)*

### Zig Interpreter

To run the Zig-based interpreter:

```bash
cd zig_tokenizer
zig run src/main.zig -- <your-zig-dsl-file.zds>
```
*(Replace `<your-zig-dsl-file.zds>` with your Zig DSL input file.)*

## Contributing

Contributions are welcome! Please refer to `CONTRIBUTING.md` (if available) or open an issue for discussion.

## License

This project is licensed under the [LICENSE](LICENSE) file.
