
##

# Projecto Final de Computação Gráfica 
## Simulação de Deformação de Ambientes em Unity
---

## Introdução e Objetivo

Este projeto pretende estudar e implementar um sistema de deformação do terreno
que se adapta a diferentes ambientes e interage com movimento de uma personagem/objeto 
simples, recorrendo a compute shaders, HLSL shaders e scripts no Unity. Também iremos
utilizar o processamento do GPU para atualizar dinamicamente height maps que 
representam a deformação do terreno.

Esta abordagem permite simular profundidade e relevo sem necessidade de alterar 
diretamente a geometria da mesh, tornando o sistema mais eficiente e reutílizavel.

## Autoras

- **Cátia Nascimento** – a22404090 
- **Lisa Carvalho** – a22405414

---
## Métodos que poderiam ser utilizados
- **Height Maps**: imagens em escala de cinza que representam a elevação do terreno.
- **Deformação Procedural**: algoritmos que modificam a geometria do terreno com base em regras
- **Tessellation Shader**: shader que subdivide a mesh do terreno para permitir deformações mais detalhadas.
- **Displacement Mapping**: técnica que utiliza height maps para deslocar vértices da mesh.
- **Noise Functions**: utilização de funções de ruído (noise), como Perlin e Simplex, para gerar deformações naturais.
- **Bump Mapping**: técnica que simula detalhes de superfície, sem alterar a geometria, utilizando luz.

### Principais Problemas
- Gestão de desempenho: Atualizações frequentes do height map pode ter um impacto no desempenho,
exigindo cuidado na resolução das texturas e na frequência de atualizações.
- Limitações do GPU: A implementação com compute shaders requer uma gestão rigorosa de memória 
e sincronização entre buffers e texturas.
- Precisão das deformações: Ajustar a intensidade e o raio do rasto para obter um resultado visual
coerente sem exagerar a deformação.
- Artefactos visuais: Surgimento de irregularidades visuais, como bordas duras ou padrões repetitivos,
quando o noise não era corretamente parametrizado.
- Realismo vs Performance: Encontrar um equilíbrio entre a qualidade visual das deformações e o desempenho.

---

CENAS PARA MUDAR:
## #1 Obstáculo  – 



### Problemas encontrados

- Necessidade de múltiplos ajustes na quantidade de partículas simuladas, de forma a equilibrar desempenho e estabilidade.
- A utilização do método **CreateFace**, baseado numa implementação de Sebastian Lague, foi essencial para o preenchimento das faces dos polígonos.

---

## #2 Obstáculo  – A grelha

Para permitir o movimento das partículas, foi implementada uma grelha tridimensional através do script **FluidGrid3D**, que aproxima a equação de **Navier-Stokes**. Este sistema calcula a **advecção**, bem como os campos de **densidade**, **velocidade** desta, tal como a **divergência** e **gradiente da pressão**.

A resolução da **equação de Poisson** para o cálculo da pressão foi realizada utilizando o **método iterativo de Jacobi**. Após os cálculos, recorreu-se à **interpolação trilinear** para amostrar os campos de densidade e velocidade, garantindo maior estabilidade na simulação semi-Lagrangiana.

### Problemas encontrados

- A implementação inicial da gravidade e dos limites da grelha resultava no teleporte das partículas para o interior da grelha.
- A ausência de colisões dificultou a validação da correção dos cálculos efetuados.
- Sem colisões, a advecção tendia a atrair as partículas para os cantos da grelha, causando acumulação excessiva em vez de um comportamento de fluido natural.

---

## Obstáculo 3 – Colisão

A implementação de colisões permitiu introduzir o conceito de **viscosidade**, completando, ainda que de forma simplificada, a equação de Navier-Stokes. Para este efeito, foi utilizado o método **Smoothed Particle Hydrodynamics (SPH)**, permitindo simular as interações entre partículas de forma direta, em vez de depender exclusivamente da grelha.

Para optimização do desempenho, foi implementada uma **grelha espacial**, reduzindo a complexidade do cálculo de interacções de **O(n²)** para **O(n)**.

### Problemas encontrados

- Comportamentos instáveis das partículas, tais como:
  - Escalar superfícies verticais;
  - Vibrações excessivas;
  - Projeção para fora dos limites da simulação;
  - Teleportes de volta para dentro das colisões;
  - Ignorar gravidade e colisões;
  - Agrupamento de partículas.
- Mesmo após ajustes extensivos dos parâmetros, o fluido não apresentava um estado de repouso estável, como esperado num fluido real.

---

## Obstáculo 4 – Perda de energia

Após múltiplas reimplementações do mesmo script, concluiu-se que, independentemente dos parâmetros utilizados, o fluido não atingia um estado estável. A redução da força das colisões resultava na sobreposição das partículas, enquanto forças de repulsão mais elevadas mantinham o sistema em constante movimento.

Como tentativa de estabilização, substituiu-se a integração **Euler** por **Verlet**, com o objectivo de reduzir a instabilidade numérica. Foram ainda introduzidas variáveis adicionais, como **SurfaceTension** e **energyDissipationRate**, aplicadas no método *UpdateParticleSPH*, bem como perda adicional de energia durante colisões entre partículas.

### Problemas encontrados

- O desempenho da simulação degradou-se significativamente a partir de aproximadamente duas mil partículas.
- A introdução de mecanismos de dissipação de energia não resolveu o problema de instabilidade, levando à remoção destas variáveis.

---

## Conclusão

A simulação apresenta um comportamento funcional e visualmente coerente com cerca de **duas mil partículas**. Contudo, ao aumentar este número, a densidade do sistema cresce significativamente, originando instabilidades, que, após alguma pesquisa, verifica-se ser um problema comum em implementações de **Smoothed Particle Hydrodynamics**.

Foram exploradas tentativas de limitar artificialmente a densidade máxima, sem sucesso. No entanto, ao aumentar a densidade base e reduzir o multiplicador de pressão, foi possível simular um maior número de partículas com relativa estabilidade. Ainda assim, esta abordagem teve um impacto negativo no desempenho, resultando numa diminuição considerável de FPS.

---
## Tutoriais e referências que ajudaram na implementação do projeto



## Fontes

