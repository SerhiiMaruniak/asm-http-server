.intel_syntax noprefix
.global _start

.section .text
_start:
# create the listening socket
define_socket:
        mov rax, 41
        mov rdi, 2
        mov rsi, 1
        mov rdx, 0
        syscall

        mov r12, rax

# definee the sockaddr struct and bind it to a port
bind_socket:
        sub rsp, 16
        mov word ptr [rsp], 2
        mov word ptr [rsp + 2], 0x5000
        mov dword ptr [rsp + 4], 0
        mov dword ptr [rsp + 8], 0

        mov rax, 49
        mov rdi, r12
        mov rsi, rsp
        mov rdx, 16
        syscall

        add rsp, 16

listen_socket:
        mov rax, 50
        mov rdi, r12
        mov rsi, 0
        syscall

parent_socket_loop:
accept_socket:
        mov rax, 43
        mov rdi, r12
        mov rsi, 0
        mov rdx, 0
        syscall

        mov r13, rax

        mov rax, 57
        syscall

        cmp rax, 0
        je child_socket

        mov rax, 3
        mov rdi, r13
        syscall

        jmp parent_socket_loop

child_socket:
        lea rdi, [rip + buf]
        mov rcx, 1024 + 512 + 1024
        xor al, al
        rep stosb

        mov rax, 3
        mov rdi, r12
        syscall

# read the incoming HTTP request
read_socket:
        mov rax, 0
        mov rdi, r13
        lea rsi, [rip + buf]
        mov rdx, 1024
        syscall

        cmp rax, 0
        jle close_socket_err

        lea rsi, [rip + buf]
        cmp dword ptr [rsi], 0x20544547
        je method_get

        cmp dword ptr [rsi], 0x54534f50
        je method_post

        jmp close_socket_err

# handlle a GET request by reading the path and file
method_get:
        xor rcx, rcx
        mov rcx, 4
        xor rdx, rdx
        lea rsi, [rip + buf]
        lea rdi, [rip + file_path]

        mov al, [rsi + rcx]
        cmp al, 0x2f
        jne extract_path_get
        inc rcx

extract_path_get:
        mov al, [rsi + rcx]
        cmp al, 0x20
        je exit_ep_get
        mov [rdi + rdx], al
        inc rcx
        inc rdx
        jmp extract_path_get

exit_ep_get:
        mov byte ptr [rdi + rdx], 0

open_file_get:
        mov rax, 2
        lea rdi, [rip + file_path]
        mov rsi, 0
        syscall
        cmp rax, 0
        jl close_socket_err
        mov r15, rax

read_file_get:
        mov rdi, rax
        mov rax, 0
        lea rsi, [rip + file_content]
        mov rdx, 1024
        syscall
        push rax

close_file_get:
        mov rax, 3
        mov rdi, r15
        syscall

write_ok_socket_get:
        mov rax, 1
        mov rdi, r13
        lea rsi, [rip + get_response_ok]
        mov rdx, 19
        syscall

write_fc_socket_get:
        mov rax, 1
        mov rdi, r13
        lea rsi, [rip + file_content]
        pop rdx
        syscall

        jmp close_socket_ok

# handle a POST request by parsing the body and saveing it
method_post:
        xor rcx, rcx
        mov rcx, 6
        xor rdx, rdx
        lea rsi, [rip + buf]
        lea rdi, [rip + file_path]

        mov al, [rsi + rcx]
        cmp al, 0x2f
        jne extract_path_post
        inc rcx

extract_path_post:
        mov al, [rsi + rcx]
        cmp al, 0x20
        je exit_ep_post
        mov [rdi + rdx], al
        inc rcx
        inc rdx
        jmp extract_path_post

exit_ep_post:
        mov byte ptr [rdi + rdx], 0
        xor rcx, rcx
        lea rsi, [rip + buf]

extract_length:
        mov al, [rsi + rcx]
        cmp al, 0x43
        jne iter_el

        mov rax, qword ptr [rsi + rcx]
        mov rbx, 0x2d746e65746e6f43
        cmp rax, rbx
        jne iter_el

        add rcx, 8

find_semicol_el:
        mov al, [rsi + rcx]
        cmp al, 0x3a
        je skip_space_el
        inc rcx
        jmp find_semicol_el

skip_space_el:
        inc rcx
skip_loop_spaces:
        mov al, [rsi + rcx]
        cmp al, 0x20
        jne start_atoi
        inc rcx
        jmp skip_loop_spaces

start_atoi:
        xor rbx, rbx
        xor rdx, rdx
atoi_len:
        mov al, [rsi + rcx]
        cmp al, 0x0d
        je end_atoi_len
        movzx rbx, al
        sub rbx, 0x30
        imul rdx, rdx, 10
        add rdx, rbx
        inc rcx
        jmp atoi_len

end_atoi_len:
        push rdx

find_body_start:
        cmp byte ptr [rsi + rcx], 0x0d
        jne next_char
        cmp byte ptr [rsi + rcx + 1], 0x0a
        jne next_char
        cmp byte ptr [rsi + rcx + 2], 0x0d
        jne next_char
        cmp byte ptr [rsi + rcx + 3], 0x0a
        je found_body

next_char:
        inc rcx
        cmp rcx, 1020
        jg no_body_found
        jmp find_body_start

found_body:
        add rcx, 4
        xor rbx, rbx
        pop rdx
        push rdx
        lea rdi, [rip + file_content]

read_body:
        cmp rbx, rdx
        jge open_file_post
        mov al, [rsi + rcx]
        mov [rdi + rbx], al
        inc rcx
        inc rbx
        jmp read_body

no_body_found:
        pop rdx
        jmp close_socket_err

iter_el:
        inc rcx
        cmp rcx, 1000
        jg close_socket_err
        jmp extract_length

open_file_post:
        mov rax, 2
        lea rdi, [rip + file_path]
        mov rsi, 0x41
        mov rdx, 0x1ff
        syscall
        cmp rax, 0
        jl close_socket_err_pop
        mov r15, rax

write_file_post:
        mov rax, 1
        mov rdi, r15
        lea rsi, [rip + file_content]
        pop rdx
        syscall

close_file_post:
        mov rax, 3
        mov rdi, r15
        syscall

write_ok_socket_post:
        mov rax, 1
        mov rdi, r13
        lea rsi, [rip + get_response_ok]
        mov rdx, 19
        syscall

close_socket_ok:
        mov rax, 3
        mov rdi, r13
        syscall

        mov rax, 60
        mov rdi, 0
        syscall

close_socket_err_pop:
        pop rdx
close_socket_err:
        mov rax, 3
        mov rdi, r13
        syscall

        mov rax, 60
        mov rdi, 1
        syscall

exit:
        mov rax, 60
        mov rdi, 0
        syscall

.section .data
get_response_ok: .ascii "HTTP/1.0 200 OK\r\n\r\n"

.section .bss
buf: .skip 1024
file_path: .skip 512
file_content: .skip 1024
