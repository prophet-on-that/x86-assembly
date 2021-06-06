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
  */
  mov %esp, %ebp
  sub $8, %esp
  movl $0, -8(%ebp)

  ## Open file
  mov $5, %eax                  # open system call
  mov $filename, %ebx
  mov $0, %ecx                  # O_RDONLY
  int $0x80
  test %eax, %eax
  js open_error
  mov %eax, -4(%ebp)

read:
  ## Read from file into BUFFER
  mov $3, %eax                 # read system call
  mov -4(%ebp), %ebx
  mov $buffer, %ecx
  mov $512, %edx                # TODO: remove duplication of buffer size
  int $0x80
  test %eax, %eax
  js read_error
  mov %eax, %ecx
  mov %eax, %edx

read_loop:
  jecxz after_read_loop
  sub $1, %ecx
  movzb buffer(,%ecx), %eax         # Move BUFFER[ECX] to eax
  cmp $'\n, %eax
  jne read_loop
  add $1, -8(%ebp)
  jmp read_loop

after_read_loop:
  cmp $512, %edx
  je read                       # Iterate if there is more file to process

  ## TODO: print results
  pushl $buffer
  pushl -8(%ebp)
  call sprintd
  add $8, %esp

  mov %eax, %edx
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

  sub 12(%ebp), %ebx            # EBX := length of output
  mov %ebx, %ecx
  shr $1, %ecx                  # ECX := len / 2
  jz sprintd_end

sprintd_reverse:
  mov %ecx, %eax
  dec %eax
  movzb buffer(%eax), %edx        # EDX := buffer[EAX]
  push %edx
  mov %ebx, %edx
  sub %ecx, %edx
  movzb buffer(%edx), %edx        # EDX := buffer[EDX]
  movb %dl, buffer(,%eax)        # buffer[EAX] := DL
  pop %eax
  mov %ebx, %edx
  sub %ecx, %edx
  movb %al, buffer(,%edx)        # bufffer[EDX] := AL
  loop sprintd_reverse

sprintd_end:
  mov %ebx, %eax                # EAX := lengh of output
  pop %ebx
  leave
  ret

  .data
filename:
  .string "wc.s"

  .bss
buffer:
  .zero 512
