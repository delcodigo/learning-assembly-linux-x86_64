section .data
	intro_line_1 db "Welcome to this awesome assembly calculator.", 10, 0
	intro_line_2 db "Introduce the operation you want to do.", 10, 0
	intro_line_3 db "sum", 0
	intro_line_4 db "sub", 0
	intro_line_5 db "mult", 0
	intro_line_6 db "COMMAND: ", 0
	intro_line_7 db "Nothing", 10, 0
	sum_line_1 db "Insert first number: ", 0
	sum_line_2 db "Insert second number: ", 0
	sum_line_3 db "Result: ", 0
	sum_line_4 db " + ", 0
	sum_line_5 db " = ", 0
	str_nl db 10, 0
	error_reading_input db "Error reading input", 10, 0
	error_not_a_number db 0
	error_invalid_input db "Invalid input", 10, 0

section .bss
	readln_buffer resb 100

section .text
	global _start

_start:
	mov rdi, intro_line_1
	call sys_print
	mov rdi, intro_line_2
	call sys_print
	call sys_print_nl
	mov rdi, intro_line_3
	call sys_print
	call sys_print_nl
	mov rdi, intro_line_4
	call sys_print
	call sys_print_nl
	mov rdi, intro_line_5
	call sys_print
	call sys_print_nl
	call sys_print_nl
	mov rdi, intro_line_6
	call sys_print

	call sys_readln

	mov rdi, readln_buffer
	mov rsi, intro_line_3
	call str_comp
	cmp rax, 1
	jz sum_numbers

	mov rdi, intro_line_7
	call sys_print

	xor rdi, rdi
	call sys_exit

sum_numbers:
	call sys_print_nl

	mov rdi, sum_line_1
	call sys_print
	
	call sys_readln

	mov rdi, rax
	call atoi
	cmp byte [error_not_a_number], 1
	jz sum_numbers_nan
	mov r9, rax

	mov rdi, sum_line_2
	call sys_print
	
	call sys_readln

	mov rdi, rax
	call atoi
	cmp byte [error_not_a_number], 1
	jz sum_numbers_nan
	mov r10, rax
	
	mov rdi, sum_line_3
	call sys_print
	mov rdi, r9
	call sys_print_int
	mov rdi, sum_line_4
	call sys_print
	mov rdi, r10
	call sys_print_int

	mov rax, r9
	add r10, rax
	
	mov rdi, sum_line_5
	call sys_print
	mov rdi, r10
	call sys_print_int
	call sys_print_nl

	jmp sum_numbers_done

	sum_numbers_nan:
		mov rdi, error_invalid_input
		call sys_print

	sum_numbers_done:
		xor rdi, rdi
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
; Registers:
;   rcx = left index (starts at 0)
;   rsi = right index (starts at length - 1)
;	al  = left byte to move to the right
;   dl  = right byte to move to the left
;
; Returns:
; 	rax = same pointer to the string as rdi
; -------------------------------------------------------------
str_reverse:
	mov rcx, 0
		
	str_reverse_loop:
		sub rsi, 1
		mov dl, [rdi+rcx]
		mov al, [rdi+rsi]
		mov byte [rdi+rcx], al
		mov byte [rdi+rsi], dl
		add rcx, 1
		cmp rsi, rcx
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
; atoi(rdi: string pointer)
;
; Converts a null-terminated string into a signed integer.
;
; The function accepts an optional leading '-' to indicate a
; negative number. All other characters must be digits ('0'-'9').
; Leading or trailing whitespace is not allowed.
;
; If there are not digits, then the error_not_a_number flag gets set
;
; rdi: pointer to input string
;
; Registers used:
;   rsi: index/counter for traversing the string
;   rdx: accumulator for the resulting number
;   rcx: sign multiplier (1 for positive, -1 for negative)
;
; Returns:
;   rax: converted integer value
;        (or 0 if the input is invalid)
; -------------------------------------------------------------
atoi:
	xor rsi, rsi
	xor rax, rax
	mov byte [error_not_a_number], 0

	mov rcx, 1
	cmp byte [rdi], 45
	jne atoi_loop
	mov rcx, -1
	inc rsi

	atoi_loop:
		xor dl, dl

		mov dl, byte [rdi+rsi]
		
		cmp dl, 0
		jz atoi_done
		
		cmp dl, 48
		jl atoi_not_number
		cmp dl, 57
		jg atoi_not_number

		sub dl, 48

		imul rax, rax, 10
		add rax, rdx

		inc rsi
		jmp atoi_loop
	
	atoi_done:
		imul rax, rcx
		ret
	
	atoi_not_number:
		mov byte [error_not_a_number], 1
		xor rax, rax
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
		inc rcx
		jmp itoa_for

	itoa_value_0:
		mov byte [rsi+rcx], 48
		inc rcx

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
	sub rsp, 16
	mov rsi, rsp
	call itoa
	mov rdi, rax
	call sys_print
	add rsp, 16
	ret

; -------------------------------------------------------------
; sys_print_nl()
;
; Prints a new line '\n' character to the console
; -------------------------------------------------------------
sys_print_nl:
	mov rax, 1
	mov rdi, 1
	mov rsi, str_nl
	mov rdx, 1
	syscall
	ret

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
; sys_readln()
;
; Reads a line from standard input into a read line buffer.
; If the input ends with a newline ('\n'), it is removed.
; The resulting string is always NULL-terminated.
;
; Returns:
;   rax: pointer to the buffer containing the read string
;        (on success)
; -------------------------------------------------------------
sys_readln:
	mov rax, 0
	mov rdi, 0
	mov rsi, readln_buffer
	mov rdx, 100
	syscall

	test rax, rax
	js sys_readln_error

	mov cl, byte[rsi+rax-1]
	cmp cl, 10
	jnz sys_readln_not_nl
	dec rax

	sys_readln_not_nl:
		xor rcx, rcx
		mov byte [rsi+rax], cl
		mov rax, rsi
		ret

	sys_readln_error:
		mov rdi, error_reading_input
		call sys_print
		call sys_exit
		ret