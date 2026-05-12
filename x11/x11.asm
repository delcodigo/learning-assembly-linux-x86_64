section .rodata
    x11_socket_path db "/tmp/.X11-unix/X0", 0
    
    error_socket db "Failed to create a Unix Socket", 10, 0
    error_server_connect db "Failed to connect to the server", 10, 0
    error_handshake db "Failed to do the handshake", 10, 0
    error_open_font db "Failed to open the font", 10, 0
    error_create_gc db "Failed to create a graphical context", 10, 0
    error_create_window db "Failed to create an x11 window", 10, 0
    error_map_window db "Failed mapping the window", 10, 0

section .data
    id dd 0
    id_base dd 0
    id_mask dd 0
    root_visual_id dd 0 

section .text
    global _start

%define SYSCALL_READ 0
%define SYSCALL_WRITE 1
%define SYSCALL_CLOSE 3
%define SYSCALL_SOCKET 41
%define SYSCALL_CONNECT 42
%define SYSCALL_EXIT 60

_start:
    call x11_connect
    mov r15, rax

    mov rdi, r15
    call x11_send_handshake
    mov r12d, eax

    call x11_next_id
    mov r13d, eax

    call x11_next_id
    mov ebx, eax

    mov rdi, r15
    mov esi, eax
    mov edx, r12d
    mov ecx, [root_visual_id]
    mov r8d, 200 | (200 << 16)
    mov r9d, 800 | (600 << 16)
    call x11_create_window

    mov rdi, r15
    mov esi, ebx
    call x11_map_window

    .wait_for_expose:
        sub rsp, 32
        mov rax, SYSCALL_READ
        mov rdi, r15
        lea rsi, [rsp]
        mov rdx, 32
        syscall
        add rsp, 32

        jmp .wait_for_expose

; -------------------------------------------------------------
; x11_connect()
;
; Connects to the X11 server
;
; returns 
;   rax = Unix socket file descriptor
; -------------------------------------------------------------
x11_connect:
    ; Creates an AF_UNIX stream socket : socket(AF_UNIX, SOCK_STREAM, 0)
    ; Used for local inter-process communication (IPC)
    mov rax, SYSCALL_SOCKET
    mov rdi, 1
    mov rsi, 1
    xor rdx, rdx
    syscall

    test rax, rax
    js x11_connect_error_socket

    mov r12, rax

    ; Builds sockaddr_un object
    sub rsp, 112
    mov word [rsp], 1
    lea rdi, [rsp + 2]
    mov rsi, x11_socket_path
    mov ecx, 19
    cld
    rep movsb

    ; Connects to the X11 server: connect(unix_socket_fd, &sockaddr_un, 110)
    mov rax, SYSCALL_CONNECT
    mov rdi, r12
    mov rsi, rsp
    mov rdx, 110
    syscall

    test rax, rax
    js x11_connect_error_server_connect

    add rsp, 112

    ; Returns the socket file descriptor
    mov rax, r12
    ret

    x11_connect_error_socket:
        mov rdi, error_socket
        call sys_print
        call sys_exit

    x11_connect_error_server_connect:
        add rsp, 112

        ; Close the socket we opened
        mov rax, SYSCALL_CLOSE
        mov rdi, r12
        syscall

        mov rdi, error_server_connect
        call sys_print
        call sys_exit

; -------------------------------------------------------------
; x11_send_handshake(rdi_socket_file_descriptor: number)
; 
; rdi: The socket file descriptor
;
; Returns 
;   rax = Window root id
; -------------------------------------------------------------
x11_send_handshake:
    sub rsp, 1<<12
    mov byte [rsp + 0], 'l' ; little endian
    mov byte [rsp + 1], 0   ; padding
    mov word [rsp + 2], 11  ; X11 major version: 11
    mov word [rsp + 4], 0   ; X11 minor version: 0
    mov word [rsp + 6], 0   ; auth name length
    mov word [rsp + 8], 0   ; auth data length
    mov word [rsp + 10], 0

    ; Send data for the handshake
    mov rax, SYSCALL_WRITE
    mov rsi, rsp
    mov rdx, 12
    syscall

    test rax, rax
    js x11_send_handshake_error

    cmp rax, 12
    jnz x11_send_handshake_error

    ; Read the first 8 bytes for the header of the response
    ; To calculate the rest of the body
    mov rax, SYSCALL_READ
    mov rsi, rsp
    mov rdx, 8
    syscall

    cmp rax, 8
    jnz x11_send_handshake_error

    ; Check that the response was successful
    cmp byte [rsp], 1
    jnz x11_send_handshake_error

    ; Calculate the size of the body response
    movzx ecx, word [rsp+6]
    shl ecx, 2

    ; Read the rest of the response
    mov rax, SYSCALL_READ
    lea rsi, [rsp]
    mov rdx, rcx
    syscall

    cmp rax, 0
    jle x11_send_handshake_error

    mov edx, dword [rsp + 4]
    mov dword [id_base], edx

    mov edx, dword [rsp + 8]
    mov dword [id_mask], edx

    mov cx, word [rsp + 16] ; Vendor length
    movzx rcx, cx

    mov al, byte [rsp + 21] ; Number of formats
    movzx rax, al
    imul rax, 8             ; Multiply by sizeof(format) = 8

    lea rdi, [rsp + 32]
    add rdi, rcx            ; Skip over vendors
    
    ; Skip over padding
    add rdi, 3
    and rdi, -4

    add rdi, rax            ; Skip over the format information

    mov eax, dword [rdi]    ; Store and return the window root id

    mov edx, dword [rdi + 32]
    mov dword [root_visual_id], edx
    
    add rsp, 1<<12
    ret

    x11_send_handshake_error:
        mov rdi, error_handshake
        call sys_print
        call sys_exit

; -------------------------------------------------------------
; x11_next_id()
;
; Increments the global id
;
; Return 
;   rax = The new id
; -------------------------------------------------------------
x11_next_id:
    mov eax, dword [id]
    mov edi, dword [id_base]
    mov edx, dword [id_mask]
    
    and eax, edx
    or eax, edi

    add dword [id], 1

    ret

; -------------------------------------------------------------
; x11_create_window(rdi, esi, edx, ecx, r8d, r9d)
;
; Params
;   rdi: Socket file descriptor
;   esi: The new window id
;   edx: Window root id
;   ecx: Root visual id
;   r8d: Packed with x and y
;   r9d: Packed with w and h
; -------------------------------------------------------------
x11_create_window:
    sub rsp, 64

    mov dword [rsp+0], 1 | (10 << 16)           ; 1: Create window, 10<<16: packet size in 4 bytes chunks
    mov dword [rsp+4], esi                      ; window id
    mov dword [rsp+8], edx                      ; window root id
    mov dword [rsp+12], r8d                     ; x and y position of the window
    mov dword [rsp+16], r9d                     ; w and h size of the window
    mov dword [rsp+20], 1 | (1 << 16)           ; 1: window class, 1<<16: border width
    mov dword [rsp+24], ecx                     ; root visual id
    mov dword [rsp+28], 0x00000802              ; Flags for background and event mask provided
    mov dword [rsp+32], 0                       ; Background color
    mov dword [rsp+36], 0x8002                  ; Subscribing to key release and expose/redraw

    mov rax, SYSCALL_WRITE
    lea rsi, [rsp]
    mov rdx, 40
    syscall

    cmp rax, 40
    jnz x11_create_window_error

    add rsp, 64
    ret

    x11_create_window_error:
        mov rdi, error_create_window
        call sys_print
        call sys_exit

; -------------------------------------------------------------
; x11_map_window(rdi, esi)
;
; param 
;   rdi: The socket file descriptor
;   esi: The window id
; -------------------------------------------------------------
x11_map_window:
    sub rsp, 16

    mov dword [rsp+0], 0x08 | (2<<16)
    mov dword [rsp+4], esi

    mov rax, SYSCALL_WRITE
    lea rsi, [rsp]
    mov rdx, 8
    syscall

    cmp rax, 8
    jnz x11_map_window_error

    add rsp, 16
    ret

    x11_map_window_error:
        mov rdi, error_map_window
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
	mov rax, SYSCALL_WRITE
	mov rdi, 1
	syscall	
	ret

; -------------------------------------------------------------
; Terminates the program with status 0
; 
; rdi: exit status code
; -------------------------------------------------------------
sys_exit:
	mov rax, SYSCALL_EXIT
    mov rdi, 0
	syscall
	ret