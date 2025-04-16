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

; ; FUNCIONES auxiliares que pueden llegar a necesitar:
; extern malloc
; extern free
; extern str_concat

extern malloc
extern free
extern str_concat
extern strlen
extern strcpy

;------------------------------------------------------------------------

; Crea una nueva lista vacía (asigna memoria para `first` y `last` y los inicializa a NULL)
string_proc_list_create_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 16              ; Ajuste para mantener alineación de 16 bytes

    mov edi, 16              ; Queremos asignar 16 bytes para la lista (2 punteros)
    call malloc              ; malloc(16), devuelve puntero en RAX

    mov qword [rax], 0       ; list->first = NULL
    mov qword [rax+8], 0     ; list->last = NULL

    add rsp, 16
    pop rbp
    ret                      ; Devuelve puntero a la lista

;------------------------------------------------------------------------

; Crea un nuevo nodo con `type` y `hash`, devuelve puntero al nodo
string_proc_node_create_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 16              ; Reserva espacio para parámetros temporales

    test rsi, rsi            ; Verifica si hash es NULL
    je .return_null

    mov [rsp], rdi           ; Guarda type
    mov [rsp+8], rsi         ; Guarda hash

    mov edi, 32              ; malloc(32), espacio para el nodo
    call malloc
    test rax, rax
    je .return_null

    mov qword [rax], 0       ; new_node->next = NULL
    mov qword [rax+8], 0     ; new_node->previous = NULL

    movzx edx, byte [rsp]    ; Carga type
    mov byte [rax+16], dl    ; new_node->type = type

    mov rsi, [rsp+8]         ; Carga hash
    mov qword [rax+24], rsi  ; new_node->hash = hash

    add rsp, 16
    pop rbp
    ret

.return_null:
    xor rax, rax             ; Devuelve NULL
    add rsp, 16
    pop rbp
    ret

;------------------------------------------------------------------------

; Agrega un nuevo nodo al final de la lista si list y hash no son NULL
string_proc_list_add_node_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 32              ; Espacio para parámetros temporales

    test rdi, rdi            ; Verifica si list es NULL
    jz .end
    test rdx, rdx            ; Verifica si hash es NULL
    jz .end

    ; Guarda parámetros
    mov [rsp], rdi           ; list
    mov [rsp+8], rsi         ; type
    mov [rsp+16], rdx        ; hash

    ; Crea el nodo
    mov rdi, rsi
    mov rsi, rdx
    call string_proc_node_create_asm
    test rax, rax
    jz .end

    mov rdi, [rsp]           ; Restaura list

    mov rcx, [rdi]           ; list->first
    test rcx, rcx
    jnz .add_to_end          ; Si no es NULL, agregar al final

    ; Lista vacía: first = last = new_node
    mov [rdi], rax
    mov [rdi+8], rax
    jmp .end

.add_to_end:
    mov rcx, [rdi+8]         ; list->last
    mov [rax+8], rcx         ; new_node->previous = list->last
    mov [rcx], rax           ; list->last->next = new_node
    mov [rdi+8], rax         ; list->last = new_node

.end:
    add rsp, 32
    pop rbp
    ret

;------------------------------------------------------------------------

; Concatena los hash de nodos que coinciden con `type` en la lista
; Devuelve un nuevo string con la concatenación
string_proc_list_concat_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 48              ; Espacio para variables temporales

    test rdi, rdi            ; Verifica si list es NULL
    jz .return_null
    test rdx, rdx            ; Verifica si hash es NULL
    jz .return_null

    ; Guarda parámetros
    mov [rsp], rdi           ; list
    mov [rsp+8], rsi         ; type
    mov [rsp+16], rdx        ; hash

    ; Copia inicial de hash → hash_concat
    mov rdi, rdx
    call strlen
    lea rdi, [rax+1]
    call malloc
    test rax, rax
    jz .return_null

    mov [rsp+24], rax        ; hash_concat
    mov rdi, rax
    mov rsi, [rsp+16]
    call strcpy

    ; Iteración sobre la lista
    mov rdi, [rsp]
    mov rcx, [rdi]           ; current_node = list->first
    mov [rsp+32], rcx

.loop_nodes:
    mov rcx, [rsp+32]
    test rcx, rcx
    jz .end

    mov dl, [rcx+16]         ; current_node->type
    cmp dl, byte [rsp+8]
    jne .next_node

    ; Tipos coinciden → concatenar
    mov rdi, [rsp+24]        ; hash_concat
    mov rsi, [rcx+24]        ; current_node->hash
    call str_concat          ; devuelve nuevo string en RAX

    ; Liberar string anterior y actualizar
    mov rdi, [rsp+24]
    mov [rsp+24], rax
    call free

.next_node:
    mov rcx, [rsp+32]
    mov rcx, [rcx]           ; current_node = current_node->next
    mov [rsp+32], rcx
    jmp .loop_nodes

.end:
    mov rax, [rsp+24]        ; Devuelve hash_concat
    add rsp, 48
    pop rbp
    ret

.return_null:
    xor rax, rax
    add rsp, 48
    pop rbp
    ret
