  .text

  /*
  See package 'linux-headers' for syscall numbers. See
	'asm-generic/fcntl.h' in this package for flags to pass to open().
  */

  .globl _start
_start:
  /*
  Local variables:
    - -4(%ebp): file descriptor
    - -8(%ebp): count of newlines
    - -12(%ebp): count of words
  */
  mov %esp, %ebp
  sub $12, %esp
  movl $0, -8(%ebp)
  movl $0, -12(%ebp)

  ## Check operating mode (file or stdin)
  mov (%ebp), %eax              # EAX := ARGC
  cmp $1, %eax
  jle read_stdin

  ## Open file
  mov $5, %eax                  # open system call
  mov (%ebp), %ebx
  mov 8(%ebp), %ebx             # EBX := ARGV[1]
  mov $0, %ecx                  # O_RDONLY
  int $0x80
  test %eax, %eax
  js open_error
  mov %eax, -4(%ebp)
  mov $0, %esi                  # ESI holds whether we're currently processing a word
  jmp read

read_stdin:
  movl $0, -4(%ebp)

read:
  ## Read from file into BUFFER
  mov $3, %eax                 # read system call
  mov -4(%ebp), %ebx
  mov $buffer, %ecx
  mov $512, %edx                # TODO: remove duplication of buffer size
  int $0x80
  test %eax, %eax
  jz after_read
  ## TODO: test for response error (< 0)
  mov %eax, %ecx
  mov %eax, %edx

read_loop:
  jecxz read
  sub $1, %ecx
  movzb buffer(,%ecx), %eax         # Move BUFFER[ECX] to eax
  cmp $'\n, %eax
  je read_loop_newline
  cmp $' ', %eax
  je read_loop_whitespace
  cmp $'\t', %eax
  je read_loop_whitespace
  cmp $10, %eax                 # Line feed
  je read_loop_whitespace
  cmp $11, %eax                 # Line tabulation
  je read_loop_whitespace
  cmp $12, %eax                 # Form feed
  je read_loop_whitespace
  ## Non-whitespace character
  test %esi, %esi
  jne read_loop
  mov $1, %esi                  # We're now processing a word
  add $1, -12(%ebp)
  jmp read_loop

read_loop_newline:
  add $1, -8(%ebp)

read_loop_whitespace:
  mov $0, %esi
  jmp read_loop

after_read:
  ## Write line count to buffer
  pushl $buffer
  pushl -8(%ebp)
  call sprintd
  add $8, %esp
  mov %eax, %edx                # EDX := length of output

  ## Write tab to buffer
  movb $'\t', buffer(%edx)
  inc %edx

  ## Write word count to buffer
  push %edx
  lea buffer(%edx), %eax
  push %eax
  push -12(%ebp)
  call sprintd
  add $8, %esp
  pop %edx
  add %eax, %edx

  ## Write output
  mov $4, %eax                  # write system call
  mov $1, %ebx                  # stdout
  mov $buffer, %ecx
  int $0x80

  mov $0, %ebx
  jmp exit

open_error:
  mov $1, %ebx
  jmp exit

read_error:
  mov $2, %ebx
  jmp exit

exit:
  mov $1, %eax                  # exit system call
  int $0x80

sprintd:
  /*
  Write decimal representation of non-negative integer to buffer. No
	overflow checking implemented.
  Args 0 - unsigned integer to print
  Arg 1  - buffer to fill
  Ret    - buffer pointer after written string
  */

  push %ebp
  mov %esp, %ebp
  push %ebx
  push %esi
  mov 12(%ebp), %ebx            # EBX holds pointer to next entry of buffer
  mov 8(%ebp), %eax

sprintd_loop:
  cdq                           # Sign-extend eax into edx:eax
  mov $10, %ecx
  div %ecx
  add $48, %edx                 # Convert remainder to ascii
  mov %dl, (%ebx)              # Copy remainder to buffer
  inc %ebx
  test %eax, %eax
  jnz sprintd_loop

  mov 12(%ebp), %eax            # EBX := buffer
  sub 12(%ebp), %ebx            # EBX := length of output
  mov %ebx, %ecx
  shr $1, %ecx                  # ECX := len / 2
  jz sprintd_end

sprintd_reverse:
  movzb -1(%eax, %ecx), %edx      # EDX := buffer[ECX - 1]
  mov %ebx, %esi
  sub %ecx, %esi
  xchg (%eax, %esi), %dl      # Exchange DL with buffer[EBX - ECX]
  movb %dl, -1(%eax, %ecx)     # buffer[ECX - 1] := DL
  loop sprintd_reverse

sprintd_end:
  mov %ebx, %eax                # EAX := length of output
  pop %esi
  pop %ebx
  leave
  ret

  .bss
buffer:
  .zero 512
