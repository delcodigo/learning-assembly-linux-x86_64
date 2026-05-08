section .data
	txt_intro db "Enter the numbers of disks [3-15]: ", 0
	txt_clear_line times 92 db ' '
	char_nl db 10, 0
	txt_input_info db "Enter your move as 'A TO B': ", 0
	error_invalid_input db "Invalid input", 10, 0
	error_reading_input db "Error reading input", 10, 0
	error_invalid_move db "Invalid move", 10, 0
	error_not_a_number db 0

section .bss
	readln_buffer resb 100
	disk_towers resb 45
	disk_towers_back resb 45
	disk_towers_line resb 94

section .text
	global _start

_start:
	mov rdi, txt_intro
	call sys_print
	
	call sys_readln
	mov rdi, rax
	call atoi
	cmp byte [error_not_a_number], 1
	jz hanoi_invalid_input

	mov r9, rax
	xor rbx, rbx
	hanoi_initialize_loop:
		mov byte [disk_towers+rbx], bl
		add byte [disk_towers+rbx], 1

		inc bl
		cmp bl, r9b
		jl hanoi_initialize_loop

	call hanoi_print_towers
	call sys_exit

	hanoi_invalid_input:
		mov rdi, error_invalid_input
		call sys_print
		call sys_exit

hanoi_print_towers:
	xor rbx, rbx

	hanoi_print_towers_loop:
		mov rsi, txt_clear_line
		mov rdi, disk_towers_line
		mov rcx, 94
		rep movsb

		mov r12b, byte [disk_towers+rbx]

		xor rdx, rdx
		mov r10, r9
		cmp r12, 0
		jz hanoi_print_towers_empty_disk

		sub r10b, r12b
		xor rcx, rcx

	hanoi_print_towers_disk:
		mov word [disk_towers_line+r10], 0x202A
		add r10, 2 

		inc rcx
		cmp cl, r12b
		jl hanoi_print_towers_disk

		inc rdx
		cmp rdx, 3
		jge hanoi_print_towers_line
	hanoi_print_towers_eod:
		lea rcx, [rdx + rdx*2]
		lea rcx, [rcx + rcx*4]
		add rcx, rbx
		mov r12b, byte [disk_towers+rcx]

		mov r10, rdx
		imul r10, r9
		add r10, r10
		add r10, r9
		sub r10, r12

		xor rcx, rcx
		cmp r12, 0
		jz hanoi_print_towers_empty_disk
		jmp hanoi_print_towers_disk

	hanoi_print_towers_line:
		mov rdi, disk_towers_line
		call sys_print

		inc rbx
		cmp rbx, r9
		jl hanoi_print_towers_loop
		jmp hanoi_print_towers_done

	hanoi_print_towers_empty_disk:
		dec r10
		mov word [disk_towers_line+r10], 0x207C

		inc rdx
		cmp rdx, 3
		jl hanoi_print_towers_eod

		jmp hanoi_print_towers_line

	hanoi_print_towers_done:
		call handle_player_movement
		ret

handle_player_movement:
	mov rdi, txt_input_info
	call sys_print
	call sys_readln

	mov rdi, disk_towers_back
	mov rsi, disk_towers
	mov rcx, 45
	rep movsb

	mov bh, byte [rax]
	mov ch, byte [rax+5]

	cmp bh, 65
	jl handle_player_movement_invalid_input
	cmp bh, 67
	jg handle_player_movement_invalid_input

	cmp ch, 65
	jl handle_player_movement_invalid_input
	cmp ch, 67
	jg handle_player_movement_invalid_input

	sub bh, 65
	sub ch, 65

	xor rdx, rdx
	add dl, bh
	imul rdx, 15

	handle_player_movement_find_disk_1:
		cmp byte [disk_towers+rdx], 0
		jg handle_player_movement_found_disk_1
		inc rdx
		jmp handle_player_movement_find_disk_1

	handle_player_movement_found_disk_1:
		mov sil, byte [disk_towers+rdx]
		mov byte [disk_towers+rdx], 0

		xor rdx, rdx
		add dl, ch
		imul rdx, 15
		add rdx, r9
		dec rdx
		mov r11, rdx

	handle_player_movement_find_disk_2:
		cmp byte [disk_towers+rdx], 0
		je handle_player_movement_verify_valid_disk_2
		dec rdx
		jmp handle_player_movement_find_disk_2

	handle_player_movement_verify_valid_disk_2:
		cmp rdx, r11
		jz handle_player_movement_found_disk_2
		mov r10, rdx
		inc r10
		mov r12b, byte [disk_towers+r10]
		cmp byte sil, r12b
		jl handle_player_movement_found_disk_2
		jmp handle_player_movement_invalid_move

	handle_player_movement_found_disk_2:
		mov byte [disk_towers+rdx], sil
		call hanoi_print_towers
		ret

	handle_player_movement_invalid_move:
		mov rdi, disk_towers
		mov rsi, disk_towers_back
		mov rcx, 45
		rep movsb

		mov rdi, error_invalid_move
		call sys_print
		call hanoi_print_towers
		ret

	handle_player_movement_invalid_input:
		mov rdi, error_invalid_input
		call sys_print
		jmp handle_player_movement

	ret

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
; sys_print_nl()
;
; Prints a new line '\n' character to the console
; -------------------------------------------------------------
sys_print_nl:
	mov rax, 1
	mov rdi, 1
	mov rsi, char_nl
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