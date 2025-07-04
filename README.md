# PBL-2: Biblioteca Assembly para Coprocessador de Multiplicação Matricial na DE1-SoC

<div align="center">
  Doscente: Wild Freitas
</div>

<div align="center">
  Discentes: Gabriel Ribeiro Souza & Lyrton Marcell & Israel Oliveira
</div>

<div align="center">
  Universidade Estadual de Feira de Santana (UEFS) - Bahia
</div>

<div align="center">
  Endereço: Av. Transnordestina, S/N - Bairro: Novo Horizonte - CEP: 44036-900
</div>

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

A biblioteca desenvolvida em Assembly foi projetada para operar como intermediária entre o processador ARM (HPS) e o coprocessador de multiplicação matricial implementado na FPGA da plataforma DE1-SoC. Esta biblioteca foi integrada a um programa em linguagem C, que atua como interface de alto nível, permitindo a entrada de dados pelo usuário e a visualização dos resultados das operações. Foi utilizado um cooprocessador disponibilizado por um dos colegas em sessão, foi o cooprocessador do grupo de Cleidson Ramos.

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

### Mapeamento dos Registradores (Interface HPS–FPGA)

A comunicação entre o processador ARM (HPS) e o coprocessador implementado na FPGA é realizada por meio de dois registradores de 32 bits, denominados `Data_In` e `Data_Out`. Esses registradores são acessados via ponte Lightweight AXI utilizando memória mapeada (`/dev/mem`).

### Registrador de Entrada: Data_In (32 bits)

O registrador `Data_In` é utilizado para enviar comandos e dados da aplicação em C (executando no HPS) para o coprocessador na FPGA. Cada campo desse registrador possui uma função específica:

- **Bit 31 (`hps_ready`)**: Sinaliza para a FPGA que os dados enviados pelo HPS estão prontos para serem lidos.
- **Bit 30 (`start`)**: Indica o início de uma operação.
- **Bit 29 (`reset`)**: Solicita a reinicialização do coprocessador.
- **Bits de 28 a 21 (`scalar`)**: Contêm um valor escalar utilizado em operações específicas, como multiplicação por escalar.
- **Bits de 20 a 19 (`size`)**: Representam o tamanho da matriz envolvida na operação (por exemplo, 2x2, 3x3, etc.).
- **Bits de 18 a 16 (`opcode`)**: Definem qual operação deve ser executada pelo coprocessador. Os códigos válidos são:
  - `0x0`: Soma (A + B)
  - `0x1`: Subtração (A - B)
  - `0x2`: Multiplicação Escalar 
  - `0x3`: Multiplicação Matricial (A × B)
- **Bits de 15 a 8 (`data_b`)**: Contêm o valor de um elemento da matriz B.
- **Bits de 7 a 0 (`data_a`)**: Contêm o valor de um elemento da matriz A.

### Registrador de Saída: Data_Out (32 bits)

O registrador `Data_Out` é utilizado pela FPGA para retornar os resultados das operações ao HPS. Sua estrutura é definida da seguinte forma:

- **Bit 31 (`fpga_wait`)**: Indica se a FPGA ainda está processando a operação (sinal de espera ativo).
- **Bit 30 (`overflow`)**: Sinaliza que ocorreu um overflow durante o processamento da operação.
- **Bits de 29 a 8 (reservado)**: Região atualmente não utilizada. Reservada para uso futuro.
- **Bits de 7 a 0 (`matrix_result`)**: Contêm o resultado de um elemento da matriz processada pela FPGA.

Esses registradores constituem a interface de comunicação essencial entre software e hardware no sistema embarcado da DE1-SoC, sendo fundamental configurar corretamente cada campo para garantir o funcionamento adequado do coprocessador matricial.

---

### Integração com C

O programa em C foi responsável por:
- Obter entrada do usuário (valores das matrizes e parâmetros);
- Invocar as funções Assembly via protótipos definidos no cabeçalho `interface.h`;
- Exibir os resultados na tela de forma legível;
- Fornecer um menu interativo com as operações disponíveis:
  - Soma
  - Subtração
  - Multiplicação por Escalar
  - Multiplicação Matricial

## Operações Disponíveis

O sistema desenvolvido permite ao usuário executar as seguintes operações matriciais para o coprocessador implementado na FPGA:

| Código | Operação                  | Descrição Técnica                                                                |
|--------|---------------------------|----------------------------------------------------------------------------------|
| 0x0    | Soma                      | Soma elemento a elemento entre matrizes A e B.                                   |
| 0x1    | Subtração                 | Subtrai matriz B da matriz A, elemento a elemento.                               |
| 0x2    | Multiplicação Escalar     | Multiplica as matrizes A e B conforme a álgebra linear.                          |
| 0x3    | Multiplicação Matricial   | Transpõe a matriz A (resultado: Aᵗ).                                             |
---

### Compilação e Execução

Um `Makefile` foi desenvolvido para automatizar o processo de compilação, utilizando:

- `arm-linux-gnueabihf-gcc` para o código C;
- `arm-linux-gnueabihf-as`/`ld` para o código Assembly.

O binário gerado é executável diretamente no sistema Linux embarcado da DE1-SoC.

A execução dos testes foi realizada no ambiente embarcado, com o sistema Linux configurado conforme a documentação da Altera/Intel.  
A comunicação com a FPGA foi validada com sucesso, e os resultados obtidos foram compatíveis com os valores esperados para cada operação matricial.

## 6. Resultados

Durante a fase de testes, foram realizadas extensas verificações funcionais e de desempenho utilizando matrizes de dimensões **2x2, 3x3, 4x4 e 5x5**, cobrindo todas as operações suportadas pelo coprocessador (soma, subtração, multiplicação, transposição, oposto e determinante). Os resultados de cada operação foram **validados manualmente** por meio de cálculos independentes realizados em software, assegurando a precisão dos dados retornados pela FPGA.

A **comunicação entre o processador ARM (HPS) e o coprocessador** implementado na FPGA se mostrou robusta, com todas as transações de leitura e escrita ocorrendo de forma sincronizada graças à implementação correta do **protocolo de handshake** via registradores. O uso de **pulsos de controle** (reset e start) e sinalização de busy garantiu o comportamento determinístico do sistema mesmo sob múltiplas execuções sequenciais.

Em termos de desempenho, observou-se uma **redução expressiva no tempo de execução** das operações em comparação com uma implementação equivalente feita exclusivamente em software. Especialmente nas multiplicações de matrizes 4x4 e 5x5, o ganho de tempo foi significativo, evidenciando os benefícios da **offload de operações intensivas** para lógica programável.

A biblioteca Assembly **abstraiu com sucesso os detalhes do mapeamento de memória e da configuração dos registradores**, oferecendo uma interface estável e reutilizável para desenvolvimento de aplicações aceleradas por hardware. Isso permitiu que o código em C permanecesse **simples e focado na lógica de aplicação**, sem a necessidade de interagir diretamente com os recursos de baixo nível do sistema.

---

## 7. Conclusão

A resolução deste problema representou uma oportunidade valiosa de **integração prática entre software e hardware** na plataforma DE1-SoC. O projeto exigiu a construção de uma biblioteca em Assembly capaz de **intermediar a comunicação entre o processador ARM Cortex-A9 (HPS) e um coprocessador de multiplicação matricial** implementado na FPGA.

### Essa integração envolveu:

- A **manipulação direta de periféricos via *memory-mapped I/O***, utilizando *syscalls* do Linux para abrir e mapear `/dev/mem`;
- A **escrita de código Assembly otimizado** para a arquitetura ARMv7-A, respeitando convenções de chamada (ABI) e utilizando instruções específicas para controle de fluxo, manipulação de bits e chamadas de sistema;
- A **configuração de uma interface binária limpa entre Assembly e C**, via `interface.h`, permitindo chamadas diretas a partir de programas de alto nível;
- A **construção de um ambiente de compilação cruzada** com uso das ferramentas `arm-linux-gnueabihf-*` para geração de binários compatíveis com o sistema Linux embarcado na DE1-SoC.

Além disso, o uso do coprocessador possibilitou **acelerar significativamente o tempo de resposta** das operações matriciais, demonstrando na prática o poder da **computação heterogênea** em sistemas embarcados.

### A atividade consolidou conhecimentos fundamentais sobre:

- Comunicação HPS-FPGA via **ponte Lightweight AXI**;
- Programação de **baixo nível em Assembly** em contexto real;
- Técnicas de **abstração para hardware em ambientes Linux embarcado**;
- Organização **modular de bibliotecas de acesso a hardware personalizado**.

Como resultado, a biblioteca desenvolvida tornou-se uma **base sólida para futuros projetos** que envolvam aceleração por hardware na DE1-SoC, **incentivando o uso de FPGAs como extensores computacionais** em aplicações de alto desempenho.

## 8. Referências

[1] ARM Limited. **ARM Cortex-A9 Technical Reference Manual**. ARM DDI 0388I (ID091612), 2012.

[2] Intel Corporation. **Intel SoC FPGA Embedded Development Suite User Guide**. UG-1137, Version 16.1, 2016.

[3] Altera Corporation. **Cyclone V Hard Processor System Technical Reference Manual**. CV-5V2, Version 15.1, 2015.

[4] TERASIC Inc. **DE1-SoC User Manual**. Version 1.2.4, 2014. Disponível em: https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=836

[5] ARM Limited. **ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition**. ARM DDI 0406C.d, 2018.

[6] GOLUB, Gene H.; VAN LOAN, Charles F. **Matrix Computations**. 4th ed. Baltimore: Johns Hopkins University Press, 2013.

[7] PATTERSON, David A.; HENNESSY, John L. **Computer Organization and Design: The Hardware/Software Interface**. 5th ed. Morgan Kaufmann, 2013.
