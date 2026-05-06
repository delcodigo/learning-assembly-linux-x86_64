section .data
	txt_intro db "Enter how many Fibonacci numbers to show: ", 0
	str_nl db 10, 0
	str_ws db 32, 0
	error_reading_input db "Error reading input", 10, 0
	error_not_a_number db 0
	error_invalid_input db "Invalid input", 10, 0

section .bss
	readln_buffer resb 100

section .text
	global _start

_start:
	mov rdi, txt_intro
	call sys_print
	call sys_readln

	mov rdi, rax
	call atoi

	cmp byte [error_not_a_number], 1
	jz fibonacci_input_error

	cmp rax, 0
	jz fibonacci_done
	jl fibonacci_input_error

	xor r9, r9
	mov r10, 1
	mov r12, rax

	mov rdi, r9
	call sys_print_int
	mov rdi, str_ws
	call sys_print

	cmp r12, 1
	jz fibonacci_done

	mov rdi, r10
	call sys_print_int
	mov rdi, str_ws
	call sys_print

	sub r12, 2

	cmp r12, 0
	jz fibonacci_done

	fibonacci_loop:
		mov rdi, r9
		add rdi, r10
		call sys_print_int

		mov rdi, r9
		add rdi, r10
		mov r9, r10
		mov r10, rdi

		mov rdi, str_ws
		call sys_print

		dec r12
		cmp r12, 0
		jg fibonacci_loop

	fibonacci_done:
		call sys_print_nl
		call sys_exit

	fibonacci_input_error:
		mov rdi, error_invalid_input
		call sys_print
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