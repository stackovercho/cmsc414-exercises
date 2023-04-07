# Preparing Shellcode

As attackers exploiting a buffer overflow vulnerability, one of our
main ways to inject our code is via the `strcpy()` function. There are
two often-conflicting facts that complicate the process for us:

 1. Shellcode is a sequence of bytes, some of which might be null.
 2. `strcpy()` (and similar string processing functions) treat a null
    byte as the end of a string.

The practical effect of this is that we need to take our injected
code, and figure out how to remove all of the null bytes from it.

**All of the instructions here are intended to be run in an interactive
`baseline` container. It may work just fine on your host, but you might
have to account for different instructions and byte-ordering.**
```
docker run --rm -ti -v "$(pwd):/opt" baseline
```

## The Approach

We're going to start with a program ([foo.c](foo.c)) that has the code we
want to include in the attack.

From that, we're going to generate both assembly and bytecode. In the
bytecode, we're going to look for null bytes (0's), and then modify
the assembly so that it does the *same thing* as the original program,
but with no nulls in the bytecode.

## The Attack

Our example is given in `foo.c`. The goal of our attack is to multiply
`eax` by 260, because our target is going to use this in a way that
benefits us. How doesn't matter, only that we want to multiply `eax`
by 260, which is what our code does.

The function we're using to produce the shellcode is:

```
void foobar() {
  volatile register int a;
  a *= 260;
}
```

`register` means our local variable will use a register, rather than
the stack, and `volatile` prevents the compiler from optimizing this
entire function away.

## Examining Execution

We can execute our program in `gdb`, and observe its behavior.

 * `break foobar` followed by `run` will get us into our function.
 * `print $rax` or `info reg rax` will tell us the current value (`rax`
   is the 64-bit version of `eax`).
 * `si` will step a single instruction, after which we can examine our
   registers again.
 * `set $rax = 10` will explicitly set the register value, so we can look
   for a more predictable change.

## Generating Shellcode

We provide a [Makefile](Makefile), which compiles and assembles the
code.  When we run `make`, it produces `foo.s` with assembly code in
AT&T syntax, and an executable binary `foo`. As we modify `foo.s`, we
can regenerate the executable with `make foo`.

### The Full Function Bytecode

There are a few ways to see the actual bytecode, but we'll just focus
on using `gdb`.  We can disassemble `foobar` with the command:

```
disassemble/r foobar
```
The `/r` option includes the actual bytecode, not just the
assembly. What we'll see (if we do all of this in the `baseline`) is
something like:
```
(gdb) disassemble/r foobar
Dump of assembler code for function foobar:
   0x00000000000005fa <+0>:	55	push   %rbp
   0x00000000000005fb <+1>:	48 89 e5	mov    %rsp,%rbp
   0x00000000000005fe <+4>:	8b 45 fc	mov    -0x4(%rbp),%eax
   0x0000000000000601 <+7>:	69 c0 04 01 00 00	imul   $0x104,%eax,%eax
   0x0000000000000607 <+13>:	89 45 fc	mov    %eax,-0x4(%rbp)
   0x000000000000060a <+16>:	90	nop
   0x000000000000060b <+17>:	5d	pop    %rbp
   0x000000000000060c <+18>:	c3	retq   
End of assembler dump.
```
The formatting leaves something to be desired, but you should be able
to recognize where the bytecode ends and the assembly begins.

We can run `gdb` in "batch" (non-interactive) mode, which we've
illustrated in the script [get_foobar](get_foobar).


### Extracting the Good Stuff

What we really want here is the following instruction:
```
   0x0000000000000601 <+7>:	69 c0 04 01 00 00	imul   $0x104,%eax,%eax
```
since everything else is stack bookkeeping and register
initialization.

The shellcode we're starting with is
```
69 c0 04 01 00 00
```
Note the two null bytes, because 260 as a 32-bit integer is `00000104`,
and we're on a little-endian system, so the bytes are reversed in
memory.

## Removing NULLs

This is where things get somewhat complicated, starting with the fact
that `gdb` displays assembly with the Intel formatting, and `gcc`
produces assembly with the AT&T formatting. The names of the
instructions will be similar but not identical, and source and
destination are *sometimes* reversed for the arguments. This is
despite them both being GNU projects.

If we look in `foo.s`, we'll see the line
```
        imull   $260, %eax, %eax
```
This is what we need to modify. It's the AT&T equivalent of
```
imul   $0x104,%eax,%eax
```
in `gdb`.

### Hint: Using Additional Registers

In `foo.s`, you can add more registers, such as `ebx`, `ecx`, or `edx`.
These should be initialized somehow, such as with
```
movl %eax,%edx
```
to copy the contents of `eax` into `edx`. In `gdb`, this will become
```
mov %edx,%eax
```

If you want to preserve the original value of an extra register after
you shellcode, you can add
```
pushq %rdx
```
before you first use `edx` or `rdx`, and
```
popq %rdx
```
after you are done with it. Both of these are single-byte
instructions. **Note that we're using the 64-bit version of the
register!**

### Hint: Shifting

If we want to multiply `eax` by 256 instead of 260, we could write
```
sall $8, %eax
```
which left-shifts `eax` by 8. That is, it multiplies it by $`2^8=256`$.

In `gdb`, this is
```
shl $0x8,%eax
```

### Hint: Adding

If we want to add two registers, we can write
```
addl %edx, %eax
```
which will add `eax` and `edx`, storing the result in `eax`.

In `gdb`, this is
```
add %edx,%eax
```

### Hint: Set a starting value

Before our first shellcode instruction, we can ensure that our target
register has a particular value, and we can then look for the final
result to exhibit our desired change.  We can do this by adding
```
movl $10, %eax
```
before our shellcode instructions.

Here's an example session:
```
(gdb) break foobar 
Breakpoint 1 at 0x5fe
(gdb) r
Starting program: /opt/foo 
warning: Error disabling address space randomization: Operation not permitted

Breakpoint 1, 0x00005602c7c005fe in foobar ()
(gdb) info reg rax
rax            0x0	0
(gdb) si
0x00005602c7c00601 in foobar ()
(gdb) disass/r foobar
Dump of assembler code for function foobar:
   0x00005602c7c005fa <+0>:	55	push   %rbp
   0x00005602c7c005fb <+1>:	48 89 e5	mov    %rsp,%rbp
   0x00005602c7c005fe <+4>:	8b 45 fc	mov    -0x4(%rbp),%eax
=> 0x00005602c7c00601 <+7>:	b8 0a 00 00 00	mov    $0xa,%eax
   0x00005602c7c00606 <+12>:	69 c0 04 01 00 00	imul   $0x104,%eax,%eax
   0x00005602c7c0060c <+18>:	89 45 fc	mov    %eax,-0x4(%rbp)
   0x00005602c7c0060f <+21>:	90	nop
   0x00005602c7c00610 <+22>:	5d	pop    %rbp
   0x00005602c7c00611 <+23>:	c3	retq   
End of assembler dump.
(gdb) si
0x00005602c7c00606 in foobar ()
(gdb) info reg rax
rax            0xa	10
(gdb) si
0x00005602c7c0060c in foobar ()
(gdb) info reg rax
rax            0xbb8	2600
(gdb) 
```
Note the instruction pointer for the next operation after each step.
