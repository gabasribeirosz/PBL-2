# PBL-2: Biblioteca Assembly para Coprocessador de Multiplicação Matricial na DE1-SoC

## 1. Introdução

Com a crescente demanda por aplicações de alto desempenho computacional — como visão computacional, aprendizado profundo, criptografia e simulações científicas — torna-se imprescindível o uso de hardware especializado para acelerar operações matemáticas complexas. No contexto da plataforma DE1-SoC, que integra um processador ARM Cortex-A9 (HPS) com uma FPGA (Cyclone V), este projeto visa desenvolver uma biblioteca em linguagem Assembly ARM para interação eficiente com um coprocessador de multiplicação matricial implementado na FPGA.

---

## 2. Objetivos

### 2.1 Objetivo Geral

Desenvolver uma biblioteca em Assembly ARMv7-A compatível com o HPS da DE1-SoC que abstraia os detalhes de comunicação de baixo nível com um coprocessador de multiplicação matricial via interface de memória mapeada, fornecendo uma API de alto desempenho e baixo overhead.

### 2.2 Objetivos Específicos

- ✅ Implementar rotinas de leitura/escrita utilizando mapeamento de memória (`mmap`) em Linux embarcado  
- ✅ Desenvolver funções para controle e sincronização do coprocessador via registradores de controle  
- ✅ Criar rotinas eficientes para transferência de blocos matriciais com alinhamento em word boundaries  
- ✅ Implementar verificações de integridade baseadas em códigos de status e timeouts  
- ✅ Comparar desempenho com versão puramente em software utilizando medições de tempo (`gettimeofday`)  

---

## 3. Fundamentação Teórica

### 3.1 Arquitetura ARM e Mapeamento de Memória

| Item               | Descrição                                                                 |
|--------------------|---------------------------------------------------------------------------|
| Arquitetura        | ARMv7-A, pipeline dual-issue superscalar, conjunto de instruções Thumb-2 |
| Acesso a HW        | Via `mmap()` e ponteiros para regiões de memória física                   |
| Vantagens          | Baixo consumo, alta eficiência, acesso determinístico a periféricos       |

No Linux embarcado, o mapeamento de memória é feito através da abertura do `/dev/mem` e uso da syscall `mmap()`, o que permite acessar os registradores do coprocessador como ponteiros de memória comum.

### 3.2 Integração HPS–FPGA na DE1-SoC

| Bridge AXI                  | Largura | Latência | Utilização                          |
|----------------------------|---------|----------|-------------------------------------|
| Lightweight HPS-FPGA       | 32 bits | Baixa    | Controle, configuração, status      |
| HPS-to-FPGA (normal)       | 128 bits| Média    | Escrita de operandos                |
| FPGA-to-HPS                | 128 bits| Média    | Leitura de resultados               |

Fluxo de operação:

1. Escrita dos operandos A e B nos registradores de dados via HPS-to-FPGA  
2. Escrita de flag de controle para iniciar operação  
3. Polling no registrador de status ou uso de interrupções para sinalizar conclusão  
4. Leitura do resultado via FPGA-to-HPS  

### 3.3 Assembly ARM em Sistemas Embarcados

- Acesso direto aos registradores (ex: `LDR`, `STR`, `MOV`)  
- Controle de sincronização com `DMB`, `DSB`, `ISB`  
- Desempenho máximo sem intervenção de compilador  
- Uso de pilha (`STMFD`, `LDMFD`) e registradores dedicados (`r4-r11` callee-saved)

### 3.4 Plataforma DE1-SoC

| Componente         | Especificação                                     |
|--------------------|---------------------------------------------------|
| SoC                | Intel Cyclone V SX-5                              |
| HPS                | ARM Cortex-A9 Dual-Core, até 925MHz               |
| FPGA               | 85K LEs, 4MB RAM embutida, interfaces AXI         |
| Periféricos        | SDRAM, GPIO, LEDs, Chaves, PLLs, UART, etc.       |
| OS embarcado       | Linux 4.x baseado em Linaro ou Yocto              |

A DE1-SoC permite integração tight-coupled entre lógica reconfigurável e processador, possibilitando arquiteturas heterogêneas com aceleração dedicada.

### 3.5 Padrões de Codificação e Reusabilidade

- Modularização: separação em arquivos `.s` por função  
- Conformidade com a convenção de chamada ARM EABI  
- Uso de macros e `.equ` para endereços e constantes  
- Comentários descritivos com tags `@param`, `@return`, `@error`  
- Diretório estruturado: `asm/`, `c_src/`, `include/`, `build/`

---

## 4. Metodologia

| Etapa                          | Descrição                                                                 |
|-------------------------------|---------------------------------------------------------------------------|
| Levantamento de requisitos    | Análise dos registradores e protocolo do coprocessador                   |
| Design da API Assembly        | Definição de funções: `init`, `write_matrix`, `start`, `poll`, `read`    |
| Integração C ↔ Assembly       | Interface via `extern` e convenção de pilha                              |
| Testes funcionais             | Matrizes de teste: identidade, zeros, aleatórias                         |
| Benchmark de desempenho       | Tempo médio em microsegundos com e sem aceleração                        |

---
## 5. Desenvolvimento

A biblioteca desenvolvida em Assembly foi projetada para operar como intermediária entre o processador ARM (HPS) e o coprocessador de multiplicação matricial implementado na FPGA da plataforma DE1-SoC. Esta biblioteca foi integrada a um programa em linguagem C, que atua como interface de alto nível, permitindo a entrada de dados pelo usuário e a visualização dos resultados das operações.

### Funcionalidades Implementadas

A biblioteca Assembly foi dividida em módulos claros e bem estruturados, cada um responsável por uma etapa crítica da comunicação com o coprocessador. As principais funcionalidades incluem:

#### Inicialização do Hardware (`initialize_hardware`)
- Abre o dispositivo `/dev/mem` utilizando syscall direta (`open`);
- Realiza o mapeamento de memória física da ponte Lightweight HPS-FPGA com `mmap2`;
- Armazena os ponteiros globais (`data_in_ptr` e `data_out_ptr`) para acesso aos registradores do hardware;
- Tratamento robusto de erros para falhas na abertura ou mapeamento da memória.

#### Encerramento da Sessão (`close_hardware`)
- Desfaz o mapeamento de memória com `munmap`;
- Fecha o descritor de arquivo aberto previamente com `close`.

#### Envio dos Dados de Entrada (`send_matrix_data`)
- Realiza a configuração dos registradores com os parâmetros da operação (matrizes A e B, tipo de operação, tamanho e escalar);
- Envia pulsos de `reset` e `start` para o coprocessador;
- Empacota os dados de cada elemento das matrizes utilizando deslocamentos e operações lógicas (bitwise);
- Utiliza protocolo de handshake para envio seguro dos dados via registradores.

#### Recebimento dos Resultados (`receive_matrix_results`)
- Lê os valores dos registradores de saída;
- Desempacota os dados e extrai a flag de overflow (bit 30) e o valor resultante (bits [7:0]);
- Utiliza protocolo de handshake para garantir sincronização com o coprocessador.

#### Funções Auxiliares de Handshake
- `handshake_send`: Garante que o dado seja aceito pela FPGA antes de enviar o próximo.
- `handshake_receive`: Aguarda até que a FPGA sinalize a presença de novo dado antes de realizar a leitura.

#### Delay Controlado (`delay_loop`)
- Delay simples baseado em contagem para garantir tempo entre pulso de `reset` e `start`.

---

### Integração com C

O programa em C foi responsável por:
- Obter entrada do usuário (valores das matrizes e parâmetros);
- Invocar as funções Assembly via protótipos definidos no cabeçalho `interface.h`;
- Exibir os resultados na tela de forma legível;
- Fornecer um menu interativo com as operações disponíveis:
  - Soma
  - Subtração
  - Multiplicação
  - Transposição
  - Oposto
  - Determinante

---

### Compilação e Execução

Um `Makefile` foi desenvolvido para automatizar o processo de compilação, utilizando:

- `arm-linux-gnueabihf-gcc` para o código C;
- `arm-linux-gnueabihf-as`/`ld` para o código Assembly.

O binário gerado é executável diretamente no sistema Linux embarcado da DE1-SoC.

A execução dos testes foi realizada no ambiente embarcado, com o sistema Linux configurado conforme a documentação da Altera/Intel.  
A comunicação com a FPGA foi validada com sucesso, e os resultados obtidos foram compatíveis com os valores esperados para cada operação matricial.

## 6. Resultados
Os testes realizados incluíram operações com matrizes 2x2, 3x3, 4x4 e 5x5, com validação manual dos resultados. O sistema demonstrou correta comunicação entre HPS e FPGA, com tempos de execução significativamente menores do que a implementação puramente em software.

A biblioteca possibilitou abstrair detalhes da comunicação de baixo nível, tornando o desenvolvimento de aplicações com aceleração em hardware mais acessível.

## 7. Conclusão
A atividade proposta neste problema proporcionou uma rica experiência prática com interação hardware-software, uso de Assembly na arquitetura ARM e exploração dos recursos da plataforma DE1-SoC. A biblioteca desenvolvida cumpriu seu papel de intermediar a comunicação entre o processador e o coprocessador matricial, oferecendo uma solução eficiente e reutilizável.

A compreensão adquirida sobre mapeamento de memória, integração com Linux embarcado e uso de Assembly contribui significativamente para a formação técnica dos discentes em sistemas embarcados e computação de alto desempenho.

## 8. Referências

[1] ARM Limited. **ARM Cortex-A9 Technical Reference Manual**. ARM DDI 0388I (ID091612), 2012.

[2] Intel Corporation. **Intel SoC FPGA Embedded Development Suite User Guide**. UG-1137, Version 16.1, 2016.

[3] Altera Corporation. **Cyclone V Hard Processor System Technical Reference Manual**. CV-5V2, Version 15.1, 2015.

[4] TERASIC Inc. **DE1-SoC User Manual**. Version 1.2.4, 2014. Disponível em: https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=836

[5] ARM Limited. **ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition**. ARM DDI 0406C.d, 2018.

[6] GOLUB, Gene H.; VAN LOAN, Charles F. **Matrix Computations**. 4th ed. Baltimore: Johns Hopkins University Press, 2013.

[7] PATTERSON, David A.; HENNESSY, John L. **Computer Organization and Design: The Hardware/Software Interface**. 5th ed. Morgan Kaufmann, 2013.
