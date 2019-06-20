# Code Generator

This is a simple compiler to generate Java assembly code (using **Jasmin** insturctions) with the input **μC** program.

## Prerequisites

Lexical analyzer (Flex) and syntax analyzer (Bison):

```bash
$ sudo apt-get install flex bison
```

Java Virtual Machine (JVM):

```bash
$ sudo add-apt-repository ppa:webupd8team/java
$ sudo apt-get update
$ sudo apt-get install default-jre
```

## How to compile and run

```bash
$ lex compiler_hw2.l                    # create lex.yy.c

$ yacc -d -v compiler_hw2.y             # create y.tab.[ch]

$ gcc lex.yy.c y.tab.c -o myparser

$ ./myparser < INPUT_FILE               # create compiler_hw3.j

$ java -jar jasmin.jar compiler_hw3.j   # create compiler_hw3.class

$ java compiler_hw3
```

or

```bash
$ make test
```

