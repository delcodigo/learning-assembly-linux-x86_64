section .data
	msg db "Hello world!", 10
	len equ $ - msg

section .text
	global _start

_start:
	; syscall(write, stdout, msg, len)
	mov rax, 1
	mov rdi, 1
	mov rsi, msg
	mov rdx, len
	syscall

	; syscall(exit, 0)
	mov rax, 60
	xor rdi, rdi
	syscall
