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


string_proc_list_create_asm:
    push rbp                ; Save the old base pointer.
    mov  rbp, rsp           ; Set the base pointer to the current stack pointer.
    ; The caller gives us a 16-byte aligned stack pointer.
    ; However, after the call instruction, the stack pointer (RSP) becomes 8-byte aligned.
    ; To meet the 16-byte alignment requirement for calling functions like malloc,
    ; we subtract 8 bytes from RSP.
    sub  rsp, 16            ; Adjust stack to maintain 16-byte alignment.

    ; -- Call to malloc --
    mov  edi, 16           ; Move the value 16 into EDI: we want to allocate 16 bytes
                           ; (for two 8-byte pointers in our list structure).
    call malloc            ; Call malloc. The result (pointer) is returned in RAX.

    ; -- Initialization of the list structure --
    ; At this point, RAX points to our allocated memory.
    mov  qword [rax], 0    ; Set the first pointer (list->first) to 0 (NULL).
    mov  qword [rax+8], 0  ; Set the last pointer (list->last) to 0 (NULL).

    ; -- Function Epilogue --
    add  rsp, 16            ; Restore the stack pointer (undo the earlier subtraction).
    pop  rbp               ; Restore the old base pointer.
    ret                    ; Return to the caller, the pointer is still in RAX.


string_proc_node_create_asm:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16              ; reservar 16 bytes para guardar parámetros y alinear

    ; si hash (RSI) es NULL, devolvemos NULL
    test    rsi, rsi
    je      .return_null

    ; guardo type y hash en la pila
    mov     [rsp    ], rdi       ; offset 0: type (uint8_t)
    mov     [rsp + 8], rsi       ; offset 8: hash pointer

    ; llamo a malloc(32)
    mov     edi, 32
    call    malloc
    test    rax, rax
    je      .return_null

    ; inicializo new_node->next = NULL, new_node->previous = NULL
    mov     qword [rax    ], 0
    mov     qword [rax +  8], 0

    ; cargo type desde la pila y lo pongo en new_node->type
    movzx   edx, byte [rsp]      ; edx = (uint32_t) type
    mov     byte [rax + 16], dl

    ; cargo hash desde la pila y lo pongo en new_node->hash
    mov     rsi, [rsp + 8]
    mov     qword [rax + 24], rsi

    ; resto epílogo
    add     rsp, 16
    pop     rbp
    ret

.return_null:
    xor     rax, rax             ; retornar NULL
    add     rsp, 16
    pop     rbp
    ret

string_proc_list_add_node_asm:
    ; -- Function Prologue --
    push rbp
    mov rbp, rsp
    sub rsp, 32              ; Allocate stack space & maintain alignment

    ; Parameters:
    ;   - RDI: list (string_proc_list*)
    ;   - RSI: type (uint8_t)
    ;   - RDX: hash (char*)

    ; Check if list is NULL
    test rdi, rdi
    jz .end                  ; If list is NULL, return

    ; Check if hash is NULL
    test rdx, rdx
    jz .end                  ; If hash is NULL, return

    ; Save parameters to stack for later use
    mov [rsp], rdi           ; Save list pointer
    mov [rsp+8], rsi         ; Save type
    mov [rsp+16], rdx        ; Save hash pointer

    ; Call string_proc_node_create_asm(type, hash)
    mov rdi, rsi             ; First parameter: type
    mov rsi, rdx             ; Second parameter: hash
    call string_proc_node_create_asm

    ; Check if node creation failed (RAX is NULL)
    test rax, rax
    jz .end                  ; If node is NULL, return

    ; New node is in RAX
    ; Load list pointer back from stack
    mov rdi, [rsp]           ; Get list pointer

    ; Check if list->first is NULL (empty list)
    mov rcx, [rdi]           ; Load list->first into RCX
    test rcx, rcx
    jnz .add_to_end          ; If not NULL, jump to add_to_end

    ; Add as first node (list->first = list->last = new_node)
    mov [rdi], rax           ; list->first = new_node
    mov [rdi+8], rax         ; list->last = new_node
    jmp .end

.add_to_end:
    ; Get list->last
    mov rcx, [rdi+8]         ; RCX = list->last
    
    ; Set new_node->previous = list->last
    mov [rax+8], rcx         ; new_node->previous = list->last
    
    ; Set list->last->next = new_node
    mov [rcx], rax           ; list->last->next = new_node
    
    ; Set list->last = new_node
    mov [rdi+8], rax         ; list->last = new_node

.end:
    add rsp, 32              ; Restore stack
    pop rbp
    ret

string_proc_list_concat_asm:
    ; -- Function Prologue --
    push rbp
    mov rbp, rsp
    sub rsp, 48              ; Reserve stack space & maintain alignment

    ; Parameters:
    ;   - RDI: list (string_proc_list*)
    ;   - RSI: type (uint8_t) 
    ;   - RDX: hash (char*)

    ; Check if list is NULL
    test rdi, rdi
    jz .return_null          ; If list is NULL, return NULL

    ; Check if hash is NULL
    test rdx, rdx
    jz .return_null          ; If hash is NULL, return NULL

    ; Save parameters to stack
    mov [rsp], rdi           ; Save list
    mov [rsp+8], rsi         ; Save type
    mov [rsp+16], rdx        ; Save hash

    ; Get length of hash string for malloc
    mov rdi, rdx             ; Parameter for strlen: hash
    call strlen              ; Get length of hash string
    
    ; Allocate memory for initial hash_concat (length + 1 for null terminator)
    lea rdi, [rax+1]         ; Parameter for malloc: size = length + 1
    call malloc
    
    ; Check if malloc failed
    test rax, rax
    jz .return_null          ; If allocation failed, return NULL
    
    ; Save hash_concat pointer to stack
    mov [rsp+24], rax        ; Save hash_concat
    
    ; Copy hash to hash_concat (strcpy)
    mov rdi, rax             ; First parameter: destination
    mov rsi, [rsp+16]        ; Second parameter: source (hash)
    call strcpy
    
    ; Start iterating through list
    mov rdi, [rsp]           ; Get list pointer
    mov rcx, [rdi]           ; RCX = list->first (current_node)
    mov [rsp+32], rcx        ; Save current_node to stack

.loop_nodes:
    ; Check if we reached the end of the list
    mov rcx, [rsp+32]        ; Get current_node
    test rcx, rcx
    jz .end                  ; If current_node is NULL, we're done
    
    ; Check if node type matches
    mov dl, [rcx+16]         ; DL = current_node->type
    cmp dl, byte [rsp+8]     ; Compare with type parameter
    jne .next_node           ; If not equal, check next node
    
    ; Types match, so concatenate
    mov rdi, [rsp+24]        ; First parameter: hash_concat
    mov rsi, [rcx+24]        ; Second parameter: current_node->hash
    call str_concat          ; Result: new concatenated string in RAX
    
    ; Free the old hash_concat
    mov rdi, [rsp+24]        ; Parameter: old hash_concat
    mov [rsp+24], rax        ; Save new hash_concat
    call free                ; Free old hash_concat

.next_node:
    ; Move to next node
    mov rcx, [rsp+32]        ; Get current_node
    mov rcx, [rcx]           ; RCX = current_node->next
    mov [rsp+32], rcx        ; Save updated current_node
    jmp .loop_nodes          ; Continue loop

.end:
    ; Return hash_concat (already in RAX)
    mov rax, [rsp+24]        ; Result: hash_concat
    add rsp, 48              ; Restore stack
    pop rbp
    ret

.return_null:
    xor rax, rax             ; Set RAX to 0 (NULL)
    add rsp, 48              ; Restore stack
    pop rbp
    ret
