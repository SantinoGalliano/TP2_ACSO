; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; Funciones externas utilizadas
extern malloc
extern free
extern str_concat
extern strlen
extern strcpy

; ------------------------------------------------

string_proc_list_create_asm:
    mov rdi, 16             ; Reservamos 16 bytes (first + last)
    call malloc
    test rax, rax           ; Verificamos si malloc falló
    je .devolver_null

    ; Inicializamos list->first = NULL y list->last = NULL
    mov qword [rax], 0
    mov qword [rax + 8], 0

    ret

.devolver_null:
    xor rax, rax            ; Devuelve NULL
    ret

; ------------------------------------------------

string_proc_node_create_asm:
    mov r8b, dil            ; Guardamos tipo en r8b
    mov r9, rsi             ; Guardamos hash en r9

    mov rdi, 32             ; Reservamos 32 bytes para el nodo
    call malloc
    test rax, rax
    je .devolver_null

    ; Inicializamos los campos del nodo
    mov qword [rax], 0          ; next = NULL
    mov qword [rax + 8], 0      ; prev = NULL
    mov byte [rax + 16], r8b    ; type
    mov qword [rax + 24], r9    ; hash

    ret

.devolver_null:
    xor rax, rax                ; Devuelve NULL
    ret

; ------------------------------------------------

string_proc_list_add_node_asm:
    mov rbx, rdi            ; Guardamos lista en rbx

    ; Creamos el nodo
    mov rdi, rsi            ; tipo
    mov rsi, rdx            ; hash
    call string_proc_node_create_asm
    test rax, rax
    jz .fin                 ; Si fallo, terminamos

    ; RAX = nuevo nodo, RBX = lista
    mov rcx, [rbx]          ; rcx = list->first
    test rcx, rcx
    jnz .al_final         ; Si no es NULL, lista no vacía

    ; Lista vacía: first y last apuntan al nuevo nodo
    mov [rbx], rax
    mov [rbx + 8], rax
    jmp .fin

.al_final:
    mov rcx, [rbx + 8]      ; rcx = list->last

    ; Enlazamos nodo nuevo al final
    mov [rax + 8], rcx      ; nuevo->prev = last
    mov [rcx], rax          ; last->next = nuevo
    mov [rbx + 8], rax      ; list->last = nuevo

.fin:
    ret

; ------------------------------------------------

string_proc_list_concat_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 48             ; Reservamos espacio local

    ; Guardamos parámetros en la pila
    mov [rsp], rdi          ; lista
    mov [rsp+8], rsi        ; tipo
    mov [rsp+16], rdx       ; hash original

    ; Copiamos el hash base a nueva memoria
    mov rdi, rdx
    call strlen
    lea rdi, [rax+1]
    call malloc
    test rax, rax
    jz .devolver_null

    ; Copiamos el hash base
    mov [rsp+24], rax       ; guardamos hash_concat
    mov rdi, rax
    mov rsi, [rsp+16]
    call strcpy

    ; Iteramos por la lista
    mov rdi, [rsp]          ; lista
    mov rcx, [rdi]          ; current_node = list->first
    mov [rsp+32], rcx

.ciclo:
    mov rcx, [rsp+32]       ; current_node
    test rcx, rcx
    jz .fin                 ; Si es NULL, fin del loop

    ; Verificamos si el tipo coincide
    mov dl, [rcx+16]        ; current_node->type
    cmp dl, byte [rsp+8]
    jne .nodo_siguiente

    ; Concatenamos el hash del nodo actual
    mov rdi, [rsp+24]       ; hash_concat actual
    mov rsi, [rcx+24]       ; current_node->hash
    call str_concat         ; RAX = nuevo string concatenado

    ; Liberamos la versión vieja de hash_concat
    mov rdi, [rsp+24]
    mov [rsp+24], rax       ; actualizamos puntero
    call free

.nodo_siguiente:
    mov rcx, [rsp+32]
    mov rcx, [rcx]          ; siguiente nodo
    mov [rsp+32], rcx
    jmp .ciclo

.fin:
    mov rax, [rsp+24]       ; devolvemos hash_concat
    add rsp, 48
    pop rbp
    ret

.devolver_null:
    xor rax, rax
    add rsp, 48
    pop rbp
    ret
