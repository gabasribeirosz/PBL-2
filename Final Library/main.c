#include <stdint.h>   // Tipos inteiros de tamanho fixo
#include <stdio.h>    // Funções de entrada/saída
#include <stdlib.h>   // Definições de constantes como EXIT_SUCCESS
#include "interface.h" // Definições específicas do hardware

#define MATRIX_SIZE 25 // Define o tamanho da matriz (5x5 elementos)


// Função para exibir o menu de operações para o usuário
void show_operation_menu() {
    printf("\n=== MENU ===\n");
    printf("0 - Soma\n");
    printf("1 - Subtração\n");
    printf("2 - Multiplicação escalar\n");
    printf("3 - Multiplicação matricial\n");
    printf("4 - Matriz oposta\n");
    printf("Digite a operação: ");
}

// Função para validar a operação e o tamanho da matriz escolhidos
int validate_matrix_operation(uint32_t operation_code, uint32_t matrix_size) {
    // Checa se o código da operação é válido (deve ser entre 0 e 7)
    if (operation_code > 7) {
        fprintf(stderr, "Operação inválida: %u\n", operation_code);
        return HW_SEND_FAIL;  // Retorna falha
    }

    // Checa se o tamanho da matriz é válido (deve ser entre 1 e 3)
    if (matrix_size > 3) {
        fprintf(stderr, "Tamanho de matriz inválido: %u\n", matrix_size);
        return HW_SEND_FAIL;  // Retorna falha
    }

    return HW_SUCCESS; // Tudo ok, operação e tamanho válidos
}

// Função para exibir a matriz com bordas visuais
void display_matrix(const int8_t* matrix, int size) {
    uint8_t border_size = size + 2;   // Adiciona bordas ao redor da matriz
    uint8_t total_size = border_size * border_size;  // Tamanho total incluindo as bordas
    int i;
    
    for (i = 0; i < total_size; i++) {
        // Quebra linha no início de cada linha da matriz
        if (i % border_size == 0) 
            printf("\n ");
        
        printf("%3d", matrix[i]); // Imprime valor com 3 dígitos
        
        // Coloca vírgula entre valores, exceto no último
        if (i % border_size != border_size - 1) 
            printf(", ");
        else 
            printf(" "); // Fecha a linha da matriz
    }
}

int main() {
    // Inicializa a matriz de exemplo (valores de 1 a 25)
    int8_t input_matrix_a[MATRIX_SIZE] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25};

    // Matriz B preenchida com 2s (para gerar overflow e testar multiplicação)
    int8_t input_matrix_b[MATRIX_SIZE] = {2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2};
    
    // Matriz para armazenar o resultado da operação
    int8_t result_matrix[MATRIX_SIZE] = {0}; 
    uint8_t overflow_status = 0;             // Flag para verificar estouro
    uint32_t operation_code = 0;             // Código da operação escolhida
    uint32_t selected_matrix_size = 3;       // Tamanho da matriz selecionada (3x3 padrão)
    uint32_t scalar_value = 3;               // Valor do escalar para multiplicação escalar

    // Exibe o menu de operações para o usuário
    show_operation_menu();
    scanf("%u", &operation_code); // Lê a operação escolhida pelo usuário

    // Estrutura com os parâmetros necessários para a operação
    struct MatrixParams params = {
        .matrix_a = input_matrix_a,  // Matriz A
        .matrix_b = input_matrix_b,  // Matriz B
        .operation = operation_code, // Operação escolhida
        .size = selected_matrix_size,// Tamanho da matriz
        .scalar = scalar_value       // Valor do escalar
    };
    
    // Valida os dados antes de prosseguir com a operação
    if (validate_matrix_operation(operation_code, selected_matrix_size) != HW_SUCCESS) {
        return EXIT_FAILURE; // Sai do programa se a validação falhar
    }

    // Inicia a comunicação com o hardware (FPGA)
    printf("Iniciando hardware...\n");
    if (initialize_hardware() != HW_SUCCESS) {
        fprintf(stderr, "Erro ao iniciar hardware\n");
        return EXIT_FAILURE; // Erro ao iniciar o hardware
    }

    // Envia os dados para a FPGA para processamento
    printf("Enviando dados...\n");
    if (send_matrix_data(&params) != HW_SUCCESS) {
        fprintf(stderr, "Erro no envio\n");
        close_hardware();  // Fecha a comunicação com o hardware em caso de erro
        return EXIT_FAILURE;
    }

    // Aguarda o processamento na FPGA
    printf("Processando na FPGA...\n");
    
    // Limpa a matriz de resultados
    for (int i = 0; i < MATRIX_SIZE; i++) {
        result_matrix[i] = 0;
    }
    overflow_status = 0; // Reseta o status de overflow
    
    // Recebe os resultados da FPGA
    if (receive_matrix_results(result_matrix, &overflow_status) != HW_SUCCESS) {
        fprintf(stderr, "Erro ao receber resultados\n");
        close_hardware(); // Fecha a comunicação com o hardware em caso de erro
        return EXIT_FAILURE;
    }
    
    // Exibe as matrizes de entrada A e B
    display_matrix(input_matrix_a, selected_matrix_size);
    display_matrix(input_matrix_b, selected_matrix_size);

    // Exibe o resultado da operação
    printf("\nResultado\n");
    display_matrix(result_matrix, selected_matrix_size);
    
    // Finaliza a comunicação com o hardware
    close_hardware();
    return EXIT_SUCCESS; // Finaliza com sucesso
}
