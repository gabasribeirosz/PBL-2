# PBL-2: Biblioteca Assembly para Coprocessador de Matricial na DE1-SoC

## 1. Introdução

Com a crescente demanda por aplicações que exigem alto desempenho computacional, como visão computacional, aprendizado de máquina e criptografia, o uso de hardware especializado para acelerar operações matemáticas torna-se essencial. No contexto da plataforma DE1-SoC, que combina um processador ARM (HPS) com uma FPGA, este trabalho tem como objetivo desenvolver uma biblioteca em linguagem Assembly para facilitar o uso de um coprocessador dedicado à multiplicação matricial, previamente implementado em hardware.

---

## 2. Objetivos

### 2.1 Objetivo Geral

Desenvolver uma biblioteca em Assembly ARM que abstraia as operações de baixo nível necessárias para comunicação com o coprocessador de multiplicação matricial implementado na FPGA, proporcionando uma interface eficiente e de fácil utilização.

### 2.2 Objetivos Específicos

- Implementar rotinas de comunicação entre HPS e FPGA através de interfaces de memória mapeada  
- Desenvolver funções de controle e sincronização para o coprocessador  
- Criar rotinas otimizadas para transferência de dados matriciais  
- Implementar mecanismos de verificação de integridade e tratamento de erros  
- Validar o desempenho da biblioteca através de testes comparativos  

---

## 3. Fundamentação Teórica

### 3.1 Arquitetura ARM e Mapeamento de Memória

A arquitetura ARM é uma arquitetura RISC (Reduced Instruction Set Computing), caracterizada por um conjunto de instruções simplificado que proporciona alta eficiência energética e desempenho. 

Na DE1-SoC, o processador ARM Cortex-A9 atua como unidade principal do HPS, comunicando-se com a FPGA via barramentos específicos.

O mapeamento de memória permite que o software acesse dispositivos de hardware como se fossem regiões da memória RAM, por meio de endereços físicos definidos. No Linux embarcado, isso é feito utilizando chamadas como `mmap()`, permitindo o acesso direto aos registradores de controle e dados do coprocessador.

---

### 3.2 Integração HPS–FPGA na DE1-SoC

A comunicação entre o HPS (Linux) e a FPGA ocorre por meio de bridges AXI, principalmente:

- **Lightweight HPS-to-FPGA Bridge**: acesso a registradores de controle e status  
- **HPS-to-FPGA Bridge**: transferência de dados de alta largura de banda  
- **FPGA-to-HPS Bridge**: acesso direto à memória pelo coprocessador  

O processo básico de comunicação envolve:

1. Inicialização do sistema (mapeamento de registradores)  
2. Escrita dos operandos nos endereços designados  
3. Sinalização de início da operação  
4. Aguardar conclusão (polling ou interrupção)  
5. Leitura dos resultados  

---

### 3.3 Linguagem Assembly e sua Utilização em Sistemas Embarcados

Assembly oferece controle direto sobre registradores e instruções da CPU, essencial para:

- Acesso direto a registradores mapeados  
- Controle preciso do fluxo de execução  
- Minimização do overhead de compiladores  
- Rotinas de baixo nível para acesso a hardware  

Neste projeto, a biblioteca Assembly funciona como uma camada de abstração para uso do coprocessador matricial, organizando dados e gerenciando sincronização da operação.

---

### 3.4 Plataforma DE1-SoC

A DE1-SoC é uma plataforma baseada no SoC FPGA Cyclone V da Intel, que combina:

- Subsystem HPS com processador dual-core ARM Cortex-A9  
- Blocos programáveis (FPGA) para implementação de hardware customizado  
- Interfaces integradas: SDRAM, GPIO, LEDs, switches, bridges para FPGA  

Essa arquitetura possibilita sistemas heterogêneos, onde o processamento é dividido entre software flexível (HPS) e hardware acelerado (FPGA).

O coprocessador matricial foi implementado na FPGA e a biblioteca Assembly desenvolvida no HPS permite a interação eficiente entre software e hardware.

---

### 3.5 Padrões de Codificação e Reusabilidade

Seguindo boas práticas recomendadas, o projeto busca garantir:

- Clareza e organização nos arquivos  
- Consistência na nomenclatura de variáveis e funções  
- Documentação clara e comentários no código  
- Facilidade para manutenção e evolução  
- Integração simples com outros projetos futuros

## 4. Metodologia
O desenvolvimento da solução foi dividido nas seguintes etapas:
1. Análise do problema e levantamento de requisitos: Entendimento do funcionamento do coprocessador existente e definição das funções necessárias para interagir com ele.
2. Definição da arquitetura da biblioteca: Organização das funções Assembly que irão lidar com o envio de dados e leitura de resultados.
3. Integração com linguagem C: Criação de um programa em C que usa a biblioteca Assembly, sendo responsável por preparar os dados e interpretar os resultados.
4. Criação de Makefile: Automatização da compilação dos códigos com uso de scripts Makefile.
5. Documentação técnica: Produção do README.md com instruções de compilação, instalação e uso da biblioteca.

## 5. Desenvolvimento
A biblioteca Assembly foi implementada com as seguintes funcionalidades básicas:

1. Escrita dos operandos nas regiões mapeadas da memória;
2. Sinalização de início da operação ao coprocessador;
3. Leitura do resultado após a conclusão da operação.

O código foi estruturado em conformidade com os padrões estabelecidos, contendo comentários explicativos e modularização adequada. O programa em C foi utilizado como interface de alto nível para interação com o usuário, fornecendo os dados de entrada (matrizes) e exibindo os resultados.

Um Makefile foi desenvolvido para compilar tanto os códigos Assembly quanto os arquivos C, gerando um binário executável diretamente na DE1-SoC. Todos os testes foram executados no Linux embarcado, configurado conforme a documentação.

## 6. Resultados
Os testes realizados incluíram operações com matrizes 2x2, 3x3, 4x4 e 5x5, com validação manual dos resultados. O sistema demonstrou correta comunicação entre HPS e FPGA, com tempos de execução significativamente menores do que a implementação puramente em software.

A biblioteca possibilitou abstrair detalhes da comunicação de baixo nível, tornando o desenvolvimento de aplicações com aceleração em hardware mais acessível.

## 7. Conclusão
A atividade proposta neste problema proporcionou uma rica experiência prática com interação hardware-software, uso de Assembly na arquitetura ARM e exploração dos recursos da plataforma DE1-SoC. A biblioteca desenvolvida cumpriu seu papel de intermediar a comunicação entre o processador e o coprocessador matricial, oferecendo uma solução eficiente e reutilizável.

A compreensão adquirida sobre mapeamento de memória, integração com Linux embarcado e uso de Assembly contribui significativamente para a formação técnica dos discentes em sistemas embarcados e computação de alto desempenho.
