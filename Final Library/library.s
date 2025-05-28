.equ DELAY_CYCLES, 10          @ Define 10 ciclos para o delay entre reset e start

.section .data
devmem_path: .asciz "/dev/mem"  @ Caminho para o dispositivo de memória física
LW_BRIDGE_BASE: .word 0xff200   @ Endereço base da ponte Lightweight
LW_BRIDGE_SPAN: .word 0x1000    @ Tamanho do espaço de endereçamento (4KB)

.global data_in_ptr             @ Ponteiro para mapeamento dos registradores de entrada (HPS->FPGA)
data_in_ptr: .word 0

.global initialize_hardware
.type initialize_hardware, %function
@ Função: Inicializa acesso ao hardware
initialize_hardware:
    PUSH {r1-r7, lr}           @ Preserva registradores
    @ --- Abre /dev/mem ---
    MOV r7, #5                  @ Código da syscall 'open'
    LDR r0, =devmem_path        @ Carrega caminho do dispositivo
    MOV r1, #2                  @ Flags: O_RDWR (leitura/escrita)
    MOV r2, #0                  @ Modo: não aplicável
    SVC 0                       @ Executa syscall

    CMP r0, #0                  @ Verifica se open() falhou (fd < 0)
    BLT fail_open               @ Se falhou, vai para tratamento de erro
    
    @ --- Armazena file descriptor ---
    LDR r1, =fd_mem             @ Carrega endereço da variável fd_mem
    STR r0, [r1]                @ Armazena file descriptor
    MOV r4, r0                  @ Preserva fd em r4

    @ --- Mapeia memória ---
    MOV r7, #192                @ Código da syscall 'mmap2'
    MOV r0, #0                  @ Endereço sugerido (NULL = kernel escolhe)
    LDR r1, =LW_BRIDGE_SPAN     @ Tamanho do mapeamento
    LDR r1, [r1]                @ Carrega valor da palavra
    MOV r2, #3                  @ Proteção: PROT_READ | PROT_WRITE
    MOV r3, #1                  @ Flags: MAP_SHARED
    LDR r5, =LW_BRIDGE_BASE     @ Endereço base físico
    LDR r5, [r5]                @ Carrega valor da palavra
    SVC 0                       @ Executa syscall

    CMP r0, #-1                 @ Verifica se mmap() falhou (retorno -1)
    BEQ fail_mmap               @ Se falhou, trata erro

    @ --- Configura ponteiros globais ---
    LDR r1, =data_in_ptr        @ Carrega endereço do ponteiro de entrada
    STR r0, [r1]                @ Armazena endereço mapeado
    ADD r1, r0, #0x10           @ Calcula endereço de saída (entrada + 16 bytes)
    LDR r2, =data_out_ptr       @ Carrega endereço do ponteiro de saída
    STR r1, [r2]                @ Armazena endereço de saída

    MOV r0, #0                  @ Retorna HW_SUCCESS (0)
    B end_init                  @ Vai para o final

fail_open:
    @ Tratamento de erro para open()
    MOV r7, #1                  @ Syscall 'exit'
    MOV r0, #1                  @ Código de erro 1 (HW_INIT_FAIL)
    SVC #0                      @ Termina programa
    B end_init                  @ Redundante (não alcançável)

fail_mmap:
    @ Tratamento de erro para mmap()
    MOV r7, #1                  @ Syscall 'exit'
    MOV r0, #2                  @ Código de erro 2 (HW_INIT_FAIL)
    SVC #0                      @ Termina programa

end_init:
    POP {r1-r7, lr}             @ Restaura registradores
    BX lr                       @ Retorna ao chamador

.global fd_mem
fd_mem: .space 4                @ Reserva 4 bytes para armazenar file descriptor

.global close_hardware
.type close_hardware, %function
@ Função: Libera recursos do hardware
close_hardware:
    PUSH {r4, lr}               @ Preserva registradores
    @ --- Desmapeia memória ---
    LDR r0, =data_in_ptr        @ Carrega ponteiro de entrada
    LDR r0, [r0]                @ Obtém endereço mapeado
    LDR r1, =LW_BRIDGE_SPAN     @ Tamanho do mapeamento
    LDR r1, [r1]                @ Carrega valor
    MOV r7, #91                 @ Syscall 'munmap'
    SVC 0                       @ Executa

    @ --- Fecha file descriptor ---
    LDR r0, =fd_mem             @ Carrega endereço do fd
    LDR r0, [r0]                @ Obtém valor do fd
    MOV r7, #6                  @ Syscall 'close'
    SVC 0                       @ Executa

    POP {r4, lr}                @ Restaura registradores
    BX lr                       @ Retorna

.global data_out_ptr            @ Ponteiro para registradores de saída (FPGA->HPS)
data_out_ptr: .word 0

.global send_matrix_data
.type send_matrix_data, %function
@ Função: Envia dados para a FPGA
@ Parâmetro: r0 = ponteiro para struct MatrixParams
send_matrix_data:
    PUSH {r4-r11, lr}           @ Preserva registradores
    @ --- Carrega parâmetros da struct ---
    LDR r4, [r0]                @ r4 = matrix_a (ponteiro)
    LDR r5, [r0, #4]            @ r5 = matrix_b (ponteiro)
    LDR r6, [r0, #8]            @ r6 = operation (opcode)
    LDR r7, [r0, #12]           @ r7 = size (tamanho matriz)
    LDR r8, [r0, #16]           @ r8 = scalar (valor escalar)

    @ --- Configura ponteiro para registradores ---
    LDR r2, =data_in_ptr        @ Carrega ponteiro global
    LDR r2, [r2]                @ Obtém endereço base

    @ --- Envia pulso de reset ---
    MOV r9, #1                  @ Bit 29 (RESET_BIT)
    LSL r9, r9, #29             @ Desloca para posição 29
    MOV r0, r9                  @ Prepara valor
    STR r0, [r2]                @ Escreve no registrador
    MOV r0, #0                  @ Valor 0
    STR r0, [r2]                @ Gera pulso (1-0)

    @ --- Delay entre reset e start ---
    MOV r11, #DELAY_CYCLES      @ Configura contador
    BL delay_loop               @ Executa delay

    @ --- Envia pulso de start ---
    MOV r9, #1                  @ Bit 30 (START_PULSE_BIT)
    LSL r9, r9, #30             @ Desloca para posição 30
    MOV r0, r9                  @ Prepara valor
    STR r0, [r2]                @ Escreve no registrador
    MOV r0, #0                  @ Valor 0
    STR r0, [r2]                @ Gera pulso (1-0)

    @ --- Loop de envio de dados ---
    MOV r9, #25                 @ Número total de elementos (5x5)
    MOV r10, #0                 @ Índice inicial (i=0)

loop_send:
    CMP r10, r9                 @ Compara índice com total
    BGE end_send                @ Se i >= 25, termina
    
    @ --- Carrega elementos das matrizes ---
    LDRSB r0, [r4, r10]         @ Carrega matrix_a[i] (com extensão de sinal)
    LDRSB r1, [r5, r10]         @ Carrega matrix_b[i] (com extensão de sinal)
    
    @ --- Empacota dados ---
    LSL r1, r1, #8              @ Desloca B para bits [15:8]
    ORR r0, r0, r1              @ Combina A(bits[7:0]) e B(bits[15:8])
    ORR r0, r0, r6, LSL #16     @ Adiciona opcode (bits[17:16])
    ORR r0, r0, r7, LSL #19     @ Adiciona size (bits[20:19])
    ORR r0, r0, r8, LSL #21     @ Adiciona scalar (bits[23:21])
    
    @ --- Envia com handshake ---
    PUSH {r0}                   @ Preserva valor
    MOV r1, #1                  @ Tipo de envio (dado normal)
    BL handshake_send           @ Chama função de handshake
    POP {r0}                    @ Restaura valor
    
    ADD r10, r10, #1            @ Incrementa índice (i++)
    B loop_send                 @ Repete loop

end_send:
    MOV r0, #0                  @ Retorna HW_SUCCESS (0)
    POP {r4-r11, lr}            @ Restaura registradores
    BX lr                       @ Retorna

@ Função: Delay loop simples
delay_loop:
    SUBS r11, r11, #1           @ Decrementa contador
    BNE delay_loop              @ Se não zero, repete
    BX lr                       @ Retorna

.global receive_matrix_results
.type receive_matrix_results, %function
@ Função: Recebe resultados da FPGA
@ Parâmetros:
@   r0 = ponteiro para matriz de resultados
@   r1 = ponteiro para flag de overflow
receive_matrix_results:
    PUSH {r4-r7, lr}            @ Preserva registradores
    MOV r4, r0                  @ r4 = resultado (ponteiro)
    MOV r5, r1                  @ r5 = overflow (ponteiro)
    MOV r6, #25                 @ Número total de elementos
    MOV r7, #0                  @ Índice inicial (i=0)

.loop_recv:
    CMP r7, r6                  @ Compara índice com total
    BGE .done                   @ Se i >= 25, termina
    
    @ --- Prepara chamada ---
    MOV r0, r4                  @ Passa ponteiro para resultado[i]
    ADD r0, r0, r7              @ Calcula endereço do elemento
    MOV r1, r5                  @ Passa ponteiro para overflow
    BL handshake_receive        @ Chama função de recebimento
    CMP r0, #0                  @ Verifica retorno (0 = sucesso)
    BNE .error                  @ Se erro, trata
    ADD r7, r7, #1              @ Incrementa índice (i++)
    B .loop_recv                @ Repete loop

.error:
    MOV r0, #1                  @ Retorna HW_READ_FAIL (1)
    B .exit                     @ Sai da função

.done:
    MOV r0, #0                  @ Retorna HW_SUCCESS (0)

.exit:
    POP {r4-r7, lr}             @ Restaura registradores
    BX lr                       @ Retorna

@ Função Auxiliar: Handshake de envio
handshake_send:
    PUSH {r1-r4, lr}            @ Preserva registradores
    @ --- Configura ponteiros ---
    LDR r1, =data_in_ptr        @ Registradores de entrada
    LDR r1, [r1]
    LDR r2, =data_out_ptr       @ Registradores de saída
    LDR r2, [r2]

    @ --- Fase 1: Envia dado com bit 31 ativo ---
    ORR r3, r0, #(1 << 31)     @ Seta HPS_CONTROL_BIT (bit 31)
    STR r3, [r1]                @ Escreve no registrador

    @ --- Fase 2: Espera FPGA_ACK = 1 ---
.wait_ack_high_send:
    LDR r4, [r2]                @ Lê registrador de saída
    TST r4, #(1 << 31)          @ Testa bit 31 (FPGA_ACK_BIT)
    BEQ .wait_ack_high_send      @ Se 0, continua esperando

    @ --- Fase 3: Confirmação - escreve 0 ---
    MOV r3, #0                  @ Valor 0
    STR r3, [r1]                @ Limpa controle

    @ --- Fase 4: Espera FPGA_ACK = 0 ---
.wait_ack_low_send:
    LDR r4, [r2]                @ Lê registrador de saída
    TST r4, #(1 << 31)          @ Testa bit 31
    BNE .wait_ack_low_send       @ Se 1, continua esperando
    POP {r1-r4, lr}             @ Restaura registradores
    BX lr                       @ Retorna

@ Função Auxiliar: Handshake de recebimento
handshake_receive:
    PUSH {r2-r5, lr}            @ Preserva registradores
    @ --- Configura ponteiros ---
    LDR r2, =data_in_ptr        @ Registradores de entrada
    LDR r2, [r2]
    LDR r3, =data_out_ptr       @ Registradores de saída
    LDR r3, [r3]
    
    @ --- Verifica ponteiros válidos ---
    CMP r2, #0                  @ data_in_ptr == NULL?
    BEQ .handshake_error        @ Se sim, erro
    CMP r3, #0                  @ data_out_ptr == NULL?
    BEQ .handshake_error        @ Se sim, erro
    
    @ --- Fase 1: Sinaliza pronto para receber ---
    MOV r4, #(1 << 31)          @ HPS_CONTROL_BIT (bit 31)
    STR r4, [r2]                @ Escreve no registrador
    
    @ --- Fase 2: Espera FPGA_ACK = 1 ---
.wait_ack_high_recei:
    LDR r5, [r3]                @ Lê registrador de saída
    TST r5, #(1 << 31)          @ Testa FPGA_ACK_BIT
    BEQ .wait_ack_high_recei     @ Se 0, continua esperando
    
    @ --- Fase 3: Extrai dados ---
    AND r4, r5, #0xFF           @ Isola bits [7:0] (valor da matriz)
    STRB r4, [r0]               @ Armazena no ponteiro de resultado
    LSR r4, r5, #30             @ Desloca bit 30 para posição 0
    AND r4, r4, #1              @ Isola bit 30 (overflow flag)
    STRB r4, [r1]               @ Armazena no ponteiro de overflow
    
    @ --- Fase 4: Confirma recebimento ---
    MOV r4, #0                  @ Valor 0
    STR r4, [r2]                @ Limpa controle
    
    @ --- Fase 5: Espera FPGA_ACK = 0 ---
.wait_ack_low_recei:
    LDR r5, [r3]                @ Lê registrador de saída
    TST r5, #(1 << 31)          @ Testa FPGA_ACK_BIT
    BNE .wait_ack_low_recei      @ Se 1, continua esperando
    MOV r0, #0                  @ Retorna HW_SUCCESS (0)
    B .handshake_exit           @ Sai com sucesso
    
.handshake_error:
    MOV r0, #1                  @ Retorna HW_READ_FAIL (1)

.handshake_exit:
    POP {r2-r5, lr}            
    BX lr                       
