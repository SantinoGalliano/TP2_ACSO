; -----------------------------------------
; DEFINES
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

extern malloc
extern free
extern str_concat
extern strlen
extern strcpy

; ------------------------------------------------
; string_proc_list_create_asm
; ------------------------------------------------
string_proc_list_create_asm:
    mov rdi, 16             ; Reservamos 16 bytes para list (first + last)
    call malloc
    test rax, rax
    je .return_null

    ; Inicializamos list->first = NULL y list->last = NULL
    mov qword [rax], 0
    mov qword [rax + 8], 0
    ret

.return_null:
    xor rax, rax
    ret

; ------------------------------------------------
; string_proc_node_create_asm
; uint8_t type (en RDI), char* hash (en RSI)
; Devuelve puntero a nodo o NULL
; ------------------------------------------------
string_proc_node_create_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 16             ; Alineamos stack para malloc

    ; Verificamos si el hash es NULL
    test rsi, rsi
    je .return_null

    ; Guardamos valores de entrada
    movzx r8d, dil          ; r8d ← tipo
    mov r9, rsi             ; r9 ← hash

    ; malloc(32)
    mov edi, 32
    call malloc
    test rax, rax
    je .return_null

    ; rax tiene puntero al nuevo nodo
    mov qword [rax], 0          ; next = NULL
    mov qword [rax + 8], 0      ; prev = NULL
    mov byte [rax + 16], r8b    ; type
    mov qword [rax + 24], r9    ; hash

    add rsp, 16
    pop rbp
    ret

.return_null:
    xor rax, rax
    add rsp, 16
    pop rbp
    ret

; ------------------------------------------------
; string_proc_list_add_node_asm
; rdi = lista, rsi = tipo, rdx = hash
; ------------------------------------------------
string_proc_list_add_node_asm:
    push rbx
    mov rbx, rdi

    ; Crear nodo
    mov rdi, rsi            ; tipo
    mov rsi, rdx            ; hash
    call string_proc_node_create_asm
    test rax, rax
    jz .done

    ; RAX = nuevo nodo, RBX = lista
    mov rcx, [rbx]          ; rcx = list->first
    test rcx, rcx
    jnz .append

    ; Lista vacía
    mov [rbx], rax          ; list->first = nuevo
    mov [rbx + 8], rax      ; list->last = nuevo
    jmp .done

.append:
    mov rcx, [rbx + 8]      ; rcx = list->last
    mov [rax + 8], rcx      ; nuevo->prev = last
    mov [rcx], rax          ; last->next = nuevo
    mov [rbx + 8], rax      ; list->last = nuevo

.done:
    pop rbx
    ret

; ------------------------------------------------
; string_proc_list_concat_asm
; rdi = lista, rsi = tipo, rdx = hash base
; Devuelve nuevo string concatenado
; ------------------------------------------------
string_proc_list_concat_asm:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32             ; espacio para variables locales y stack alignment

    ; Guardar parámetros
    mov [rsp], rdi          ; lista
    mov [rsp + 8], sil      ; tipo (guardado como byte)
    mov [rsp + 16], rdx     ; hash base

    ; strlen(hash base)
    mov rdi, rdx
    call strlen
    add rax, 1              ; +1 para '\0'
    mov rdi, rax
    call malloc
    test rax, rax
    jz .return_null

    mov [rsp + 24], rax     ; guardar puntero hash_concat

    ; strcpy(hash_concat, hash base)
    mov rdi, rax
    mov rsi, [rsp + 16]
    call strcpy

    ; Iterar sobre la lista
    mov rdi, [rsp]          ; lista
    mov rbx, [rdi]          ; current = list->first

.loop:
    test rbx, rbx
    jz .end

    mov al, [rsp + 8]       ; tipo a buscar
    cmp al, [rbx + 16]      ; compara con current->type
    jne .next

    ; Concatenar hash_concat + current->hash
    mov rdi, [rsp + 24]     ; actual
    mov rsi, [rbx + 24]     ; current->hash
    call str_concat         ; rax = nuevo string

    ; Liberar viejo string
    mov rdi, [rsp + 24]
    call free
    mov [rsp + 24], rax     ; actualizar nuevo string

.next:
    mov rbx, [rbx]          ; siguiente nodo
    jmp .loop

.end:
    mov rax, [rsp + 24]     ; retornar nuevo string
    add rsp, 32
    pop rbx
    pop rbp
    ret

.return_null:
    xor rax, rax
    add rsp, 32
    pop rbx
    pop rbp
    ret
