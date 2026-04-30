section .data
	msg db "The number is: ", 0
	msgEq db "The strings are equal", 0
	msgNEq db "The strings are not equal", 0
	str_nln db 0x0A, 0

section .text
	global _start

_start:
	sub rsp, 16
	mov rdi, msg
	mov rsi, rsp
	mov rdx, 16
	call mem_copy

	mov rdi, msg
	mov rsi, rax
	call str_comp
	cmp rax, 1
	jnz _start_strings_not_equal
	mov rdi, msgEq
	jmp _start_print_strings_equality
	_start_strings_not_equal:
	mov rdi, msgNEq
	_start_print_strings_equality:
	call sys_print
	call sys_print_nl

	mov rdi, msg
	call sys_print
	mov rdi, 456
	call sys_print_int
	call sys_print_nl

	add rsp, 16

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
; str_comp(rdi: string, rsi: string)
;
; Compares two null-terminated strings byte by byte.
; Iterates until a mismatch is found or a NULL terminator is reached.
; 
; rdi: stringA pointer
; rsi: stringB pointer
;
; Registers
;   rcx: index into both strings
;   al : current byte from string A
;   bl : current byte from string B
;
; Returns
; 	rax: 1 if the strings are equal, 0 if not equals
; -------------------------------------------------------------
str_comp:
	xor rcx, rcx

	str_comp_loop:
		mov al, [rdi + rcx]
		mov bl, [rsi + rcx]

		cmp al, bl
		jnz str_comp_not_equal

		cmp al, 0
		jz str_comp_equal

		inc rcx
		jmp str_comp_loop

	str_comp_equal:
		mov rax, 1
		ret
	
	str_comp_not_equal:
		mov rax, 0
		ret

; -------------------------------------------------------------
; mem_copy(rdi_source_pointer: void*, rsi_destination_pointer: void*, rdx_length: int)
;
; Copies rdx bytes from the memory region pointed to by rdi
; (source) to the memory region pointed to by rsi (destination).
;
; rdi: source pointer
; rsi: destination pointer
; rdx: length to copy
;
; Returns
; 	rax: pointer to destination memory
; -------------------------------------------------------------
mem_copy:
	cld
	mov rcx, rdx
	mov rax, rdi
	mov rdi, rsi
	rep movsb
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
