(lang dune 3.19)

(name dsm)

(generate_opam_files true)

(source
 (github nkxxll/dsm))

(authors "Niklas Kirschall <niklas@kirschall.com>")

(maintainers "Niklas Kirschall <niklas@kirschall.com>")

(license LICENSE)

(documentation https://github.com/nkxxll/dsm)

(package
 (name dsm)
 (synopsis "DSM Lecture code")
 (description "Domain specific languages medical lecture code with tokenizer, parser, interpreter")
 (depends ocaml angstrom ppx_expect)
 (tags
  ("dsm" "lecture")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
