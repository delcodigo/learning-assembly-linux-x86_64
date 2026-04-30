section .data
	msg db "The number is: ", 0
	str_nln db 0x0A, 0

section .text
	global _start

_start:
	mov rdi, msg
	call sys_print
	mov rdi, 456
	call sys_print_int
	call sys_print_nl

	mov rdi, 0
	call sys_exit

; -------------------------------------------------------------
; str_len(rdi_str_pointer: string)
;
; Walks through a NULL terminated string counting the number of 
; characters and returns the count. It doesn't includes the NULL
; terminator as part of the count
;
; assumes input is a NULL terminated string
;
; rdi: pointer to string
;
; returns:
;	rax = rcx pointer - rdi pointer
;
; registers:
;	rcx = local pointer to string
; -------------------------------------------------------------
str_len:
	mov rcx, rdi

	str_len_loop:
		cmp byte [rcx], 0
		jz str_len_return
		inc rcx
		jmp str_len_loop

	str_len_return:
		mov rax, rcx
		sub rax, rdi
		ret

; -------------------------------------------------------------
; str_reverse(rdi_str_pointer: string, rsi_length: int)
;
; Reverses a string in place by swapping characters from both ends,
; moving inward until the left index is no longer less than the right.
;
; rdi: pointer to string
; rsi: length of string
;
; registers:
;   rcx = left index (starts at 0)
;   rdx = right index (starts at length - 1)
; -------------------------------------------------------------
str_reverse:
	mov rcx, 0
	mov rdx, rsi
		
	str_reverse_loop:
		sub rdx, 1
		mov r10b, [rdi+rcx]
		mov r9b, r10b
		mov r10b, [rdi+rdx]
		mov byte [rdi+rcx], r10b
		mov byte [rdi+rdx], r9b
		add rcx, 1
		cmp rdx, rcx
		jg str_reverse_loop
	
		mov rax, rdi
		ret

; -------------------------------------------------------------
; itoa(rdi: number, rsi: string)
;
; Takes an integer number and returns its ASCII representation
; it divides the number, takes the remainder and converts it to
; ASCII, repeat until the coeficient is 0. The number is reversed
; so the final string is reversed through str_reverse.
;
; assumes input != INT64_MIN
;
; rdi: number to convert
; rsi: output string
;
; registers:
;	rcx = string index
;	rax = absolute value of input number
;	r8 = we divide by 10 to obtain each digit
; -------------------------------------------------------------
itoa:
	mov rcx, 0
	mov rax, rdi
	mov r8, 10

	cmp rax, 0
	jge itoa_not_negative
	neg rax

	itoa_not_negative:
		cmp rax, 0
		jz itoa_value_0

	itoa_for:
		cmp rax, 0
		jz itoa_null_terminator
		xor rdx, rdx
		div r8
		add dl, 48
		mov byte [rsi+rcx], dl
		add rcx, 1
		jmp itoa_for

	itoa_value_0:
		mov byte [rsi+rcx], 48
		add rcx, 1

	itoa_null_terminator:
		cmp rdi, 0
		jl itoa_negative
	itoa_null_terminator_negative:
		mov byte [rsi+rcx], 0
		mov rdi, rsi
		mov rsi, rcx
		call str_reverse
		mov rax, rdi
		ret
	
	itoa_negative:
		mov byte [rsi+rcx], 45
		add rcx, 1
		jmp itoa_null_terminator_negative


; -------------------------------------------------------------
; exit(rdi: number)
;
; Terminates the program with the status code passed
; 
; rdi: exit status code
; -------------------------------------------------------------
sys_exit:
	mov rax, 60
	syscall
	ret

; -------------------------------------------------------------
; sys_print(rdi: string)
;
; Prints a string to the console
;
; rdi: message to print
; -------------------------------------------------------------
sys_print:
	call str_len

	mov rsi, rdi
	mov rdx, rax
	mov rax, 1
	mov rdi, 1
	syscall	
	ret

; -------------------------------------------------------------
; sys_print_int(rdi: int)
;
; Converts an integer number to string and prints it to the
; console
;
; rdi: number to print
; -------------------------------------------------------------
sys_print_int:
	sub rsp, 32
	mov rsi, rsp
	call itoa
	mov rdi, rax
	call sys_print
	add rsp, 32
	ret

; -------------------------------------------------------------
; sys_print_nl()
;
; Prints a new line '\n' character to the console
; -------------------------------------------------------------
sys_print_nl:
	mov rdi, str_nln
	call sys_print
	ret